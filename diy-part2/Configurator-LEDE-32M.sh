#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: Configurator-LEDE-32M.sh
# Description: LEDE .config maker script (for addon&paks) for 32MB(256Mb) flash device
#

cat << EOF
=======Configurator-LEDE-32M.sh=======
    functions loaded:
        1. add_packages, modification  (from _lib/_mod-lede.sh)
        2. config_func                 (from _profile/lede-32M.sh)
        3. config_basic
        4. config_clean
        5. config_test
=========================================
EOF

sh_dir=$(dirname "$0")

# 载入 LEDE 通用修改与拉包逻辑
. "$sh_dir/_lib/_mod-lede.sh"

# 载入 LEDE 32M 配置档（config_clean/basic/func/test）
. "$sh_dir/_profile/lede-32M.sh"
