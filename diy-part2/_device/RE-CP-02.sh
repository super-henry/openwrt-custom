#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _device/RE-CP-02.sh
# Description: 京东云 RE-CP-02 (鲁班) 设备定义 (OpenWrt only)
#

#=========================================
# Target System
#=========================================
target_inf() {
    cat << 'EOF'
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7621=y
CONFIG_TARGET_ramips_mt7621_DEVICE_jdcloud_re-cp-02=y
EOF
}

#=========================================
# 默认配置修改
#=========================================
mod_default_config() {
    _set_ip
    _set_timezone
    _set_hostname "JDC_Mark3"
    _set_theme
    _set_custom_defaults "$SH_DIR"
}

#=========================================
# 设备专属补丁 (DTS + network + mk)
# 原位于 [OpenWrt]RE-CP-02-part2.sh
#=========================================
target_patch() {
    local PATCH_DIR="$GITHUB_WORKSPACE/patches"

    # dts补丁，使用自定义分区，更新数据偏移位置
    echo '[+TARGET] 应用 mt7621_jdcloud_re-cp-02.dts.patch'
    patch target/linux/ramips/dts/mt7621_jdcloud_re-cp-02.dts "${PATCH_DIR}/mt7621_jdcloud_re-cp-02.dts.patch"

    # IMAGE_SIZE(16000K->16192K)
    echo '[+TARGET] 应用 mt7621.mk.re-cp-02.patch'
    patch target/linux/ramips/image/mt7621.mk "${PATCH_DIR}/mt7621.mk.re-cp-02.patch"

    # network中增加MAC地址读取逻辑
    echo '[+TARGET] 应用 02_network.re-cp-02.patch'
    patch target/linux/ramips/mt7621/base-files/etc/board.d/02_network "${PATCH_DIR}/02_network.re-cp-02.patch"
}
