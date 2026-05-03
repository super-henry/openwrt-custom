#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: scripts/preview-config.sh
# Description: 本地预览指定设备的 .config 生成结果
#              不执行实际修改/拉包/编译，仅输出配置内容
#
# 用法：
#   scripts/preview-config.sh <device_choice> [config_tag]
#
#   device_choice : 编号，对应 device-env.sh 中的 case 分支
#   config_tag    : clean | basic | func | test，默认 func
#
# 示例：
#   scripts/preview-config.sh 5 func    # 预览 RE-SP-01B OpenWrt 全功能配置
#   scripts/preview-config.sh 2 basic   # 预览 Newifi3D2 LEDE 基础配置
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

#=========================================
# 动态解析 device-env.sh 获取设备列表
#=========================================
parse_device_env() {
    local env_file="$1"
    local choice="$2"

    # 提取指定 case 分支的内容
    awk -v n="$choice" '
        $0 ~ "^\\s*" n "\\)" { found=1; next }
        found && /^\s*;;/      { exit }
        found                    { print }
    ' "$env_file"
}

# 从 case 分支内容中提取变量值
extract_var() {
    local block="$1"
    local var="$2"
    echo "$block" | grep "${var}=\"" | head -1 | sed 's/.*="\([^"]*\)".*/\1/'
}

# 列出所有可用设备
list_devices() {
    echo "可用设备列表："
    echo ""
    local num=1
    while true; do
        local block
        block=$(parse_device_env "$REPO_ROOT/device-env.sh" "$num" 2>/dev/null)
        [ -z "$block" ] && break
        local tag
        tag=$(extract_var "$block" "DEVICE_TAG")
        [ -z "$tag" ] && break
        echo "  $num  - $tag"
        num=$((num + 1))
    done
    echo ""
    echo "配置档位：clean | basic | func | test"
}

#=========================================
# 参数解析
#=========================================
DEVICE_CHOICE="${1:-}"
CONFIG_TAG="${2:-func}"

if [ -z "$DEVICE_CHOICE" ]; then
    echo "用法: $0 <device_choice> [config_tag]"
    echo ""
    list_devices
    exit 1
fi

# 验证设备编号有效
DEVICE_BLOCK=$(parse_device_env "$REPO_ROOT/device-env.sh" "$DEVICE_CHOICE" 2>/dev/null)
if [ -z "$DEVICE_BLOCK" ]; then
    echo "[ERROR] 无效的设备编号: $DEVICE_CHOICE"
    echo ""
    list_devices
    exit 1
fi

# 提取设备参数
DEVICE_TAG=$(extract_var "$DEVICE_BLOCK" "DEVICE_TAG")
DEVICE_NAME=$(extract_var "$DEVICE_BLOCK" "DEVICE_NAME")
SYSTEM_NAME=$(extract_var "$DEVICE_BLOCK" "SYSTEM_NAME")
FLASH_SIZE=$(extract_var "$DEVICE_BLOCK" "FLASH_SIZE")

if [ -z "$DEVICE_NAME" ] || [ -z "$SYSTEM_NAME" ] || [ -z "$FLASH_SIZE" ]; then
    echo "[ERROR] device-env.sh 中编号 $DEVICE_CHOICE 缺少 DEVICE_NAME/SYSTEM_NAME/FLASH_SIZE"
    exit 1
fi

echo "===== 加载设备环境 (device-env.sh $DEVICE_CHOICE) ====="
echo "DEVICE_TAG : $DEVICE_TAG"
echo "DEVICE_NAME: $DEVICE_NAME"
echo "SYSTEM_NAME: $SYSTEM_NAME"
echo "FLASH_SIZE : $FLASH_SIZE"
echo "CONFIG_TAG : $CONFIG_TAG"
echo ""

# 设置 SH_DIR 并加载框架组件
SH_DIR="$REPO_ROOT/diy-part2"

#=========================================
# 1. 载入共享 helper
#=========================================
. "$SH_DIR/_lib/_set-defaults.sh"

#=========================================
# 2. 载入设备定义
#=========================================
DEVICE_SCRIPT="$SH_DIR/_device/${DEVICE_NAME}.sh"
if [ ! -f "$DEVICE_SCRIPT" ]; then
    echo "[ERROR] 设备定义文件不存在: $DEVICE_SCRIPT"
    exit 1
fi
. "$DEVICE_SCRIPT"

#=========================================
# 3. 载入配置档
#=========================================
PROFILE_SCRIPT="$SH_DIR/config-profiles/${SYSTEM_NAME}-${FLASH_SIZE}.sh"
if [ ! -f "$PROFILE_SCRIPT" ]; then
    echo "[ERROR] 配置档不存在: $PROFILE_SCRIPT"
    exit 1
fi
. "$PROFILE_SCRIPT"

#=========================================
# 4. 生成 .config 预览（不执行 add_packages/modification/target_patch）
#=========================================
echo "===== 生成的 .config 内容预览 ====="
echo ""

# target_inf 输出
echo "# ---------- Target Information ----------"
target_inf
echo ""

# config tier 输出
case "$CONFIG_TAG" in
    clean)
        echo "# ---------- [clean] 洁净配置 ----------"
        config_clean
        ;;
    basic)
        echo "# ---------- [basic] 基础配置 ----------"
        config_basic
        ;;
    test)
        echo "# ---------- [test] 测试配置 ----------"
        config_test
        ;;
    *)
        echo "# ---------- [func] 全功能配置 ----------"
        config_func
        ;;
esac

echo ""
echo "===== 预览结束 ====="
echo ""
echo "说明："
echo "  - 此输出仅包含 target_inf + config tier 的内容"
echo "  - 实际编译时还会执行 add_packages、modification、target_patch"
echo "  - 最终 .config 还会经过 sed 's/^[ \t]*//g' 清理行首空白"
echo "  - 以及 make defconfig 补全默认值"
