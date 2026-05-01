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
#   device_choice : 1-6，对应 device-env.sh 中的编号
#   config_tag    : clean | basic | func | test，默认 func
#
# 示例：
#   scripts/preview-config.sh 5 func    # 预览 RE-SP-01B OpenWrt 全功能配置
#   scripts/preview-config.sh 2 basic   # 预览 Newifi3D2 LEDE 基础配置
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 参数解析
DEVICE_CHOICE="${1:-}"
CONFIG_TAG="${2:-func}"

if [ -z "$DEVICE_CHOICE" ]; then
    echo "用法: $0 <device_choice> [config_tag]"
    echo ""
    echo "设备列表："
    echo "  1  - Lean's LEDE - HC5661"
    echo "  2  - Lean's LEDE - Newifi3_D2"
    echo "  3  - Lean's LEDE - RE-SP-01B"
    echo "  4  - OpenWrt - Newifi3_D2"
    echo "  5  - OpenWrt - RE-SP-01B"
    echo "  6  - OpenWrt - RE-CP-02"
    echo ""
    echo "配置档位：clean | basic | func | test"
    exit 1
fi

# 加载 device-env.sh 获取环境变量
# 在本地运行时没有 $GITHUB_ENV，所以用临时文件中转
echo "===== 加载设备环境 (device-env.sh $DEVICE_CHOICE) ====="
ENV_TMP=$(mktemp)
$REPO_ROOT/device-env.sh $DEVICE_CHOICE >/dev/null 2>&1 || true
# device-env.sh 会输出到 GITHUB_ENV，本地没有，直接解析它的赋值语句
# 改用 source 方式加载（在子 shell 中执行，提取变量）
(
    # 模拟 GITHUB_ENV 输出
    GITHUB_ENV="$ENV_TMP"
    source "$REPO_ROOT/device-env.sh" "$DEVICE_CHOICE" >/dev/null 2>&1
)
# 从 device-env.sh 的输出中提取变量（它用 cat << EOF 输出）
# 更直接的方式：直接解析 case 语句... 不，太复杂
# 改用：直接设置已知的映射关系（与 device-env.sh 保持一致）

case "$DEVICE_CHOICE" in
    1) DEVICE_NAME="HC5661"; SYSTEM_NAME="lede"; FLASH_SIZE="32M"; DEVICE_TAG="Lean's LEDE - HC5661" ;;
    2) DEVICE_NAME="Newifi3D2"; SYSTEM_NAME="lede"; FLASH_SIZE="32M"; DEVICE_TAG="Lean's LEDE - Newifi3_D2" ;;
    3) DEVICE_NAME="RE-SP-01B"; SYSTEM_NAME="lede"; FLASH_SIZE="32M"; DEVICE_TAG="Lean's LEDE - RE-SP-01B" ;;
    4) DEVICE_NAME="Newifi3D2"; SYSTEM_NAME="openwrt"; FLASH_SIZE="32M"; DEVICE_TAG="OpenWrt - Newifi3_D2" ;;
    5) DEVICE_NAME="RE-SP-01B"; SYSTEM_NAME="openwrt"; FLASH_SIZE="32M"; DEVICE_TAG="OpenWrt - RE-SP-01B" ;;
    6) DEVICE_NAME="RE-CP-02"; SYSTEM_NAME="openwrt"; FLASH_SIZE="16M"; DEVICE_TAG="OpenWrt - RE-CP-02" ;;
    *) echo "无效的设备编号: $DEVICE_CHOICE"; rm -f "$ENV_TMP"; exit 1 ;;
esac

rm -f "$ENV_TMP"

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
. "$SH_DIR/_device/${DEVICE_NAME}.sh"

#=========================================
# 3. 载入配置档
#=========================================
. "$SH_DIR/_profile/${SYSTEM_NAME}-${FLASH_SIZE}.sh"

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
echo "  - 最终 .config 还会经过 sed 's/^[ \\t]*//g' 清理行首空白"
echo "  - 以及 make defconfig 补全默认值"
