#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _device/Newifi3D2.sh
# Description: Newifi3 D2 (Newifi3) 设备定义
#              支持 LEDE 和 OpenWrt 双系统
#

#=========================================
# Target System
#=========================================
target_inf() {
    cat << 'EOF'
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7621=y
CONFIG_TARGET_ramips_mt7621_DEVICE_d-team_newifi-d2=y
CONFIG_PACKAGE_kmod-usb3=y
EOF
}

#=========================================
# 默认配置修改
#=========================================
mod_default_config() {
    local system="$1"

    _set_ip

    # OpenWrt 版本额外设置时区
    if [ "$system" = "openwrt" ]; then
        _set_timezone
    fi

    _set_hostname "N3D2"
    _set_theme

    # OpenWrt 版本额外添加 uci-defaults
    if [ "$system" = "openwrt" ]; then
        _set_custom_defaults "$SH_DIR"
    fi
}

#=========================================
# 设备专属补丁（无）
#=========================================
target_patch() { :; }
