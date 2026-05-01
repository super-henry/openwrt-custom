#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _device/HC5661.sh
# Description: 极路由 HC5661 设备定义 (LEDE only)
#

#=========================================
# Target System
#=========================================
target_inf() {
    cat << 'EOF'
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7620=y
CONFIG_TARGET_ramips_mt7620_DEVICE_hiwifi_hc5661=y
EOF
}

#=========================================
# 默认配置修改
#=========================================
mod_default_config() {
    _set_ip
    _set_hostname "Gee_1s"
    _set_theme
}

#=========================================
# 设备专属补丁（无）
#=========================================
target_patch() { :; }
