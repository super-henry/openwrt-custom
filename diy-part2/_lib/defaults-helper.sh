#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _lib/defaults-helper.sh
# Description: 设备默认配置的共享 helper 函数
#              原分散在各个设备脚本的 mod_default_config() 中
#

# 修改后台地址（所有设备统一）
_set_ip() {
    sed -i 's/192.168.1.1/192.168.199.1/g' package/base-files/files/bin/config_generate
}

# 修改时区为东八区（OpenWrt 版本使用）
_set_timezone() {
    sed -i "s/'UTC'/'CST-8'\n        set system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate
}

# 修改主机名
_set_hostname() {
    local hostname="$1"
    sed -i "s/OpenWrt/${hostname}/g" package/base-files/files/bin/config_generate
}

# 修改默认主题为 argon（所有设备统一）
_set_theme() {
    sed -i 's/bootstrap/argon/g' feeds/luci/modules/luci-base/root/etc/config/luci
}

# OpenWrt 版本特有的：添加 uci-defaults 默认设置文件
_set_custom_defaults() {
    local sh_dir="$1"
    mkdir -p files/etc/uci-defaults
    cp -v "$sh_dir/uci-defaults.sh" files/etc/uci-defaults/99-Custom-Default
}

# 修改 luci 应用菜单入口，支持 new style（JS/JSON）和 old style（Lua）两种包结构
change_entry() {
    [ "$#" -lt 3 ] && echo "[ch_entry_error] 用法: change_entry <旧入口> <新入口> <包目录>" && return 1
    [ ! -d "$3" ] && echo "目录不存在：$3" && return 1

    local old_entry="$1"
    local new_entry="$2"
    local pkg_dir="$3"
    local pkg_name
    pkg_name=$(basename "$pkg_dir")

    echo -e "\n[MOD] 将 $pkg_name 从 <$old_entry> 移动到 <$new_entry> [$pkg_dir]"

    # ---------- 包类型识别 ----------
    local menu_json_dir="$pkg_dir/root/usr/share/luci/menu.d"
    local controller_dir="$pkg_dir/luasrc/controller"

    if [ -d "$menu_json_dir" ] && ls "$menu_json_dir"/*.json >/dev/null 2>&1; then
        # ========== 新式包（JS/JSON）==========
        echo "  → 检测为 new style (JS/JSON) 包"
        for jsonfile in "$menu_json_dir"/*.json; do
            sed -i 's|"admin/'"$old_entry"'\([/"]\)|"admin/'"$new_entry"'\1|w /dev/stderr' "$jsonfile" 2>&1
            echo "  [menu.d] 已处理: $jsonfile"
        done

        local acl_dir="$pkg_dir/root/usr/share/rpcd/acl.d"
        if [ -d "$acl_dir" ] && ls "$acl_dir"/*.json >/dev/null 2>&1; then
            for aclfile in "$acl_dir"/*.json; do
                if grep -q "admin/$old_entry" "$aclfile"; then
                    sed -i 's|admin/'"$old_entry"'|admin/'"$new_entry"'|w /dev/stderr' "$aclfile" 2>&1
                    echo "  [acl.d] 已修改: $aclfile"
                fi
            done
        fi
        return 0
    fi

    if [ -d "$controller_dir" ] && ls "$controller_dir"/*.lua >/dev/null 2>&1; then
        # ========== 旧式包（Lua/HTML）==========
        echo "  → 检测为 old style (Lua) 包，按后缀处理 .lua 与 .htm"

        # ---- 1. 处理所有 .lua 文件 ----
        while IFS= read -r lua_file; do
            echo "  [.lua] $lua_file"
            # 1a. entry() 菜单声明
            sed -i 's/\("admin"\s*,\s*\)"'"$old_entry"'"/\1"'"$new_entry"'"/w /dev/stderr' "$lua_file" 2>&1
            # 1b. 硬编码路径 admin/old_entry → admin/new_entry
            sed -i 's|admin/'"$old_entry"'|admin/'"$new_entry"'|w /dev/stderr' "$lua_file" 2>&1
        done < <(find "$pkg_dir" -type f -name "*.lua" ! -path "*/po/*")

        # ---- 2. 处理所有 .htm 文件 ----
        while IFS= read -r htm_file; do
            echo "  [.htm] $htm_file"
            sed -i 's/\(url(\[\[admin\]\]\s*,\s*\[\[\)'"$old_entry"'\(\]\]\)/\1'"$new_entry"'\2/w /dev/stderr' "$htm_file" 2>&1
        done < <(find "$pkg_dir" -type f -name "*.htm")

        # ---- 3. 全目录扫描残留旧入口（独立单词），输出提醒 ----
        local residue
        residue=$(grep -r -w -n --include="*.lua" --include="*.htm" --include="*.json" \
                  --exclude-dir="po" "$old_entry" "$pkg_dir" 2>/dev/null)
        if [ -n "$residue" ]; then
            echo -e "\n  ⚠️  以下位置仍包含旧入口 \"$old_entry\"，可能需要手动检查："
            echo "$residue"
        fi
        return 0
    fi

    # ---------- 兜底：未识别类型，全局简单替换 ----------
    echo "  → 未识别包类型，回退全局字符串替换（可能误改）..."
    find "$pkg_dir" ! -path "*.svn*" -type f \
        -exec grep -q "$old_entry" {} \; -exec \
            sh -c 'sed -i "s/$1/$2/w /dev/stderr" "$0" 2>&1; echo "  [fallback] 修改: $0"' \
                {} "$old_entry" "$new_entry" \;
}
