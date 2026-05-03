#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
# Licensed under MIT License.
#
# File name: scripts/preview-config.sh
# Description: 本地预览指定设备的 .config 生成结果，或生成 HTML 对比页面
#
# 用法：
#   scripts/preview-config.sh <device_choice> [config_tag]
#   scripts/preview-config.sh --html [选项]
#   scripts/preview-config.sh --help
#
# 参数：
#   device_choice : 设备编号（参见 --help 输出）
#   config_tag    : clean | basic | func | test，默认 func
#
# HTML 模式选项（将委托给 generate-html.sh）：
#   -d "编号列表"  设备编号，如 "1 2 3"（默认全部）
#   -c "档位列表"  配置档位，如 "basic func"（默认全部）
#   -o 文件名      输出 HTML 文件名（默认 comparison.html）
#

set -e

# ---------- 路径初始化 ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------- 辅助函数 ----------
parse_device_env() {
    local env_file="$1"
    local choice="$2"
    awk -v n="$choice" '
        $0 ~ "^\\s*" n "\\)" { found=1; next }
        found && /^\s*;;/      { exit }
        found                    { print }
    ' "$env_file"
}

extract_var() {
    local block="$1"
    local var="$2"
    echo "$block" | grep "${var}=\"" | head -1 | sed 's/.*="\([^"]*\)".*/\1/'
}

# ---------- 列出可用设备（供用户参考） ----------
list_devices() {
    echo "可用设备列表："
    echo ""
    local num=1
    while true; do
        local block
        block=$(parse_device_env "$REPO_ROOT/device-env.sh" "$num" 2>/dev/null) || break
        [ -z "$block" ] && break
        local tag
        tag=$(extract_var "$block" "DEVICE_TAG")
        [ -z "$tag" ] && break
        printf "  %-3s - %s\n" "$num" "$tag"
        num=$((num + 1))
    done
    echo ""
    echo "配置档位：clean | basic | func | test"
}

# ---------- 输出纯设备编号和标签（供其他脚本调用） ----------
list_device_ids() {
    local num=1
    while true; do
        local block
        block=$(parse_device_env "$REPO_ROOT/device-env.sh" "$num" 2>/dev/null) || break
        [ -z "$block" ] && break
        local tag
        tag=$(extract_var "$block" "DEVICE_TAG")
        [ -z "$tag" ] && break
        printf '%s\t%s\n' "$num" "$tag"
        num=$((num + 1))
    done
}

# ---------- 帮助信息 ----------
show_help() {
    cat <<EOF
用法: $0 <device_choice> [config_tag]

  本地预览指定设备的 .config 生成结果（命令行输出）。

  device_choice : 设备编号，对应 device-env.sh 中的 case 分支
  config_tag    : clean | basic | func | test，默认 func

  示例：
    $0 5 func         预览设备 5 的全功能配置
    $0 2 basic        预览设备 2 的基础配置

特殊模式:
  $0 --list-devices  输出纯设备编号列表（供脚本使用）
  $0 --html [选项]   生成交互式 HTML 对比页面（委托 generate-html.sh）

HTML 模式选项:
  -d "编号列表"      设备编号，例如 "1 2 3"（默认全部）
  -c "档位列表"      配置档位，例如 "basic func"（默认全部）
  -o 文件名          输出 HTML 文件（默认 comparison.html）

  $0 --help          显示本帮助
EOF
    echo ""
    list_devices
}

# ---------- 路由：特殊开关 ----------
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --list-devices)
        list_device_ids
        exit 0
        ;;
    --html)
        shift
        if [ ! -x "$SCRIPT_DIR/generate-html.sh" ]; then
            echo "[ERROR] 未找到可执行的 generate-html.sh，请确保该脚本存在于 $SCRIPT_DIR 且具备执行权限。" >&2
            exit 1
        fi
        exec "$SCRIPT_DIR/generate-html.sh" "$@"
        ;;
esac

# ---------- 模式一：命令行预览 ----------
DEVICE_CHOICE="${1:-}"
CONFIG_TAG="${2:-func}"

if [ -z "$DEVICE_CHOICE" ]; then
    echo "[提示] 未提供设备编号。使用 --help 查看用法。" >&2
    exit 1
fi

# 验证设备编号有效性
DEVICE_BLOCK=$(parse_device_env "$REPO_ROOT/device-env.sh" "$DEVICE_CHOICE" 2>/dev/null) || true
if [ -z "$DEVICE_BLOCK" ]; then
    echo "[ERROR] 无效的设备编号: $DEVICE_CHOICE" >&2
    list_devices >&2
    exit 1
fi

DEVICE_TAG=$(extract_var "$DEVICE_BLOCK" "DEVICE_TAG")
DEVICE_NAME=$(extract_var "$DEVICE_BLOCK" "DEVICE_NAME")
SYSTEM_NAME=$(extract_var "$DEVICE_BLOCK" "SYSTEM_NAME")
FLASH_SIZE=$(extract_var "$DEVICE_BLOCK" "FLASH_SIZE")

if [ -z "$DEVICE_NAME" ] || [ -z "$SYSTEM_NAME" ] || [ -z "$FLASH_SIZE" ]; then
    echo "[ERROR] device-env.sh 中编号 $DEVICE_CHOICE 缺少 DEVICE_NAME/SYSTEM_NAME/FLASH_SIZE 定义。" >&2
    exit 1
fi

echo "===== 加载设备环境 (device-env.sh $DEVICE_CHOICE) ====="
echo "DEVICE_TAG : $DEVICE_TAG"
echo "DEVICE_NAME: $DEVICE_NAME"
echo "SYSTEM_NAME: $SYSTEM_NAME"
echo "FLASH_SIZE : $FLASH_SIZE"
echo "CONFIG_TAG : $CONFIG_TAG"
echo ""

SH_DIR="$REPO_ROOT/diy-part2"

# 检查必要文件是否存在
DEVICE_SCRIPT="$SH_DIR/_device/${DEVICE_NAME}.sh"
if [ ! -f "$DEVICE_SCRIPT" ]; then
    echo "[ERROR] 设备定义文件不存在: $DEVICE_SCRIPT" >&2
    exit 1
fi

PROFILE_SCRIPT="$SH_DIR/config-profiles/${SYSTEM_NAME}-${FLASH_SIZE}.sh"
if [ ! -f "$PROFILE_SCRIPT" ]; then
    echo "[ERROR] 配置档文件不存在: $PROFILE_SCRIPT" >&2
    exit 1
fi

. "$SH_DIR/_lib/defaults-helper.sh"
. "$DEVICE_SCRIPT"
. "$PROFILE_SCRIPT"

echo "===== 生成的 .config 内容预览 ====="
echo ""

echo "# ---------- Target Information ----------"
target_inf
echo ""

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
    func|*)
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
