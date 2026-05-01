#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _lib/_set-defaults.sh
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
    cp -v "$sh_dir/[OpenWrt]CustomDefault.sh" files/etc/uci-defaults/99-Custom-Default
}
