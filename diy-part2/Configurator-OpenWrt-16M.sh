#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: Configurator-OpenWrt-16M.sh
# Description: OpenWrt .config maker script (for addon&paks) for 16MB(128Mb) flash device
#

cat << EOF
=======Configurator-OpenWrt-16M.sh=======
    functions loaded:
        1. add_packages, modification  (from _lib/_mod-openwrt.sh)
        2. config_func                 (from _profile/openwrt-16M.sh)
        3. config_basic
        4. config_clean
        5. config_test
=========================================
EOF

sh_dir=$(dirname "$0")

# 载入共享的 OpenWrt 通用修改与拉包逻辑
. "$sh_dir/_lib/_mod-openwrt.sh"

# 载入 OpenWrt 16M 配置档（config_clean/basic/func/test）
. "$sh_dir/_profile/openwrt-16M.sh"
