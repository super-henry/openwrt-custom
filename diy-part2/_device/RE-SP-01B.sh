#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _device/RE-SP-01B.sh
# Description: 京东云 RE-SP-01B (Mark1) 设备定义
#              支持 LEDE 和 OpenWrt 双系统
#

#=========================================
# Target System
#=========================================
target_inf() {
    cat << 'EOF'
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7621=y
CONFIG_TARGET_ramips_mt7621_DEVICE_jdcloud_re-sp-01b=y
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

    _set_hostname "JDC_Mark1"
    _set_theme

    # OpenWrt 版本额外添加 uci-defaults
    if [ "$system" = "openwrt" ]; then
        _set_custom_defaults "$SH_DIR"
    fi
}

#=========================================
# 设备专属补丁 (DTS + network + system)
# 原分散在 [LEDE]RE-SP-01B-part2.sh 和 [OpenWrt]RE-SP-01B-part2.sh 中
#=========================================
target_patch() {
    local PATCH_DIR="$GITHUB_WORKSPACE/patches"

    # dts补丁，去除mini/oem分区
    echo '[+TARGET] 应用 mt7621_jdcloud_re-sp-01b.dts.patch'
    patch target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts "${PATCH_DIR}/mt7621_jdcloud_re-sp-01b.dts.patch"

    # IMAGE_SIZE(27328k->32448k)
    echo '[+TARGET] 应用 mt7621.mk.re-sp-01b.patch'
    patch target/linux/ramips/image/mt7621.mk "${PATCH_DIR}/mt7621.mk.re-sp-01b.patch"
    
    # network中增加MAC地址计算逻辑
    echo '[+TARGET] 应用 02_network.re-sp-01b.patch'
    patch target/linux/ramips/mt7621/base-files/etc/board.d/02_network "${PATCH_DIR}/02_network.re-sp-01b.patch"
}
