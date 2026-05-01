#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _framework.sh
# Description: diy-part2 统一入口脚本
#              根据环境变量组合设备定义、系统修改、配置档，生成 .config
#
# 环境变量（由 device-env.sh 或调用方设置）：
#   DEVICE_NAME   - 设备标识 (HC5661, Newifi3D2, RE-SP-01B, RE-CP-02)
#   SYSTEM_NAME   - 固件系统 (lede, openwrt)
#   FLASH_SIZE    - 闪存容量 (16M, 32M)
#   CONFIG_TAG    - 配置档位，通过 $1 传入 (clean, basic, func, test)
#

SH_DIR="${SH_DIR:-$(dirname "$0")}"
CONFIG_TAG="${1:-func}"

cat << EOF
=======diy-part2 _framework.sh=======
    DEVICE : ${DEVICE_NAME}
    SYSTEM : ${SYSTEM_NAME}
    FLASH  : ${FLASH_SIZE}
    CONFIG : ${CONFIG_TAG}
======================================
EOF

#=========================================
# 1. 载入共享 helper
#=========================================
. "$SH_DIR/_lib/_set-defaults.sh"

#=========================================
# 2. 载入设备定义 (target_inf, mod_default_config, target_patch)
#=========================================
DEVICE_SCRIPT="$SH_DIR/_device/${DEVICE_NAME}.sh"
if [ ! -f "$DEVICE_SCRIPT" ]; then
    echo "[ERROR] 设备定义文件不存在: $DEVICE_SCRIPT"
    exit 1
fi
. "$DEVICE_SCRIPT"

#=========================================
# 3. 载入系统特定的 modification + add_packages
#=========================================
MOD_SCRIPT="$SH_DIR/_lib/_mod-${SYSTEM_NAME}.sh"
if [ ! -f "$MOD_SCRIPT" ]; then
    echo "[ERROR] 系统修改脚本不存在: $MOD_SCRIPT"
    exit 1
fi
. "$MOD_SCRIPT"

#=========================================
# 4. 载入配置档 (config_clean/basic/func/test)
#=========================================
PROFILE_SCRIPT="$SH_DIR/_profile/${SYSTEM_NAME}-${FLASH_SIZE}.sh"
if [ ! -f "$PROFILE_SCRIPT" ]; then
    echo "[ERROR] 配置档不存在: $PROFILE_SCRIPT"
    exit 1
fi
. "$PROFILE_SCRIPT"

#=========================================
# 5. 执行客制化流程
#=========================================
add_packages
mod_default_config "$SYSTEM_NAME"
target_patch

#=========================================
# 6. 生成 .config 文件
#=========================================
echo -e '\n=====================路径检查======================='
echo -n '[diy-part2.sh]当前表显路径：' && pwd
echo -n '[diy-part2.sh]当前物理路径：' && pwd -P
rm -fv ./.config*

target_inf >> .config

case "$CONFIG_TAG" in
    clean*) echo "[洁净配置] 仅该型号的默认功能"     ; config_clean >> .config ;;
    basic*) echo "[基本配置] 包含一些基础增强"       ; config_basic >> .config ;;
    test*)  echo "[测试配置] 包含所有功能，外加测试包" ; config_test  >> .config ;;
    *)      echo "[全功能配置] 包含常用的所有功能、插件" ; config_func  >> .config ;;
esac

# 移除行首的空格和制表符
sed -i 's/^[ \t]*//g' .config

# make defconfig
# diff .config default.config --color
# diff的返回值1会导致github actions出错，用这个来盖过去
echo "=====================已生成 .config 文件，diy-part2.sh 结束====================="
