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
    local gist_base='https://gist.githubusercontent.com/1-1-2/335dbc8e138f39fb8fe6243d424fe476/raw'

    # load dts
    echo '[+TARGET] 应用 mt7621_jdcloud_re-cp-02.dts.target_patch'
    curl --retry 3 -s "${gist_base}/mt7621_jdcloud_re-cp-02.dts.patch" | patch target/linux/ramips/dts/mt7621_jdcloud_re-cp-02.dts

    # fix2 + fix4.2
    echo '[+TARGET] 应用 mt7621.mk.re-cp-02.patch'
    curl --retry 3 -s "${gist_base}/mt7621.mk.re-cp-02.patch" | patch target/linux/ramips/image/mt7621.mk
    
    # fix3 + fix5.2
    echo '[+TARGET] 应用 02_network.re-cp-02.patch'
    curl --retry 3 -s "${gist_base}/02_network.re-cp-02.patch" | patch target/linux/ramips/mt7621/base-files/etc/board.d/02_network
}
