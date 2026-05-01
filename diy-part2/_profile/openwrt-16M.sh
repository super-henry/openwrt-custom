#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _profile/openwrt-16M.sh
# Description: OpenWrt 16M 闪存设备的配置 tier 函数
#              原位于 Configurator-OpenWrt-16M.sh
#

config_clean() {
    #=========================================
    # Stripping options
    #=========================================
    cat << EOF
CONFIG_STRIP_KERNEL_EXPORTS=y
# CONFIG_USE_MKLIBS is not set
EOF
    #=========================================
    # Luci
    #=========================================
    cat << EOF
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-compat=y
EOF
    #=========================================
    # unset some default to avoid duplication
    #=========================================
    cat << EOF
EOF
}

config_basic() {
    config_clean
    #=========================================
    # 基础包和应用
    #=========================================
    cat << EOF
# ----------Basic_external_drive
CONFIG_PACKAGE_automount=y
CONFIG_PACKAGE_luci-app-hd-idle=m
CONFIG_PACKAGE_usbutils=y
# ----------Basic_luci-app-ddns
CONFIG_PACKAGE_ddns-scripts-cloudflare=y
CONFIG_PACKAGE_luci-app-ddns=y
# ----------Basic_luci-cmd
CONFIG_PACKAGE_luci-app-commands=y
CONFIG_PACKAGE_luci-app-ttyd=y
# ----------Basic_network
# CONFIG_PACKAGE_wpad-basic-mbedtls is not set
CONFIG_PACKAGE_wpad-mbedtls=y
# ----------Basic_small_paks
CONFIG_BUSYBOX_CONFIG_BASE64=y
CONFIG_BUSYBOX_CONFIG_SENDMAIL=y
CONFIG_BUSYBOX_CUSTOM=y
CONFIG_LIBCURL_SMTP=y
CONFIG_PACKAGE_fping=y
CONFIG_PACKAGE_jq=m
CONFIG_PACKAGE_luci-app-advanced-reboot=y
CONFIG_PACKAGE_luci-app-advanced=y
CONFIG_PACKAGE_luci-app-uhttpd=y
CONFIG_PACKAGE_luci-app-watchcat=y
CONFIG_PACKAGE_luci-app-wifischedule=y
CONFIG_PACKAGE_luci-app-wol=y
# ----------Driver_USB2TTL
CONFIG_PACKAGE_kmod-usb-serial=m
CONFIG_PACKAGE_kmod-usb-serial-pl2303=m
CONFIG_PACKAGE_kmod-usb-serial-ch341=m
# ----------Func_upnp
CONFIG_PACKAGE_luci-app-upnp=y
# ----------STAT_luci-app-statistics
CONFIG_PACKAGE_luci-app-statistics=y
# ----------Utilities_knot
CONFIG_PACKAGE_knot-dig=m
CONFIG_PACKAGE_knot-host=m
# ----------Utilities_e2fsprogs
CONFIG_PACKAGE_e2fsprogs=y
# ----------Utilities_fdisk
CONFIG_PACKAGE_fdisk=y
# ----------Utilities_nettool
CONFIG_PACKAGE_ca-certificates=m
CONFIG_PACKAGE_ethtool=y
CONFIG_PACKAGE_luci-app-iperf3-server=y
CONFIG_PACKAGE_socat=y
# ----------Utilities_parted
CONFIG_PACKAGE_parted=m
# ----------Basic_paks_openwrt
CONFIG_PACKAGE_collectd-mod-disk=y
CONFIG_PACKAGE_collectd-mod-dns=y
CONFIG_PACKAGE_collectd-mod-ping=y
CONFIG_PACKAGE_collectd-mod-processes=y
CONFIG_PACKAGE_collectd-mod-sensors=y
CONFIG_PACKAGE_collectd-mod-tcpconns=y
CONFIG_PACKAGE_luci-app-acl=y
CONFIG_PACKAGE_luci-app-ledtrig-rssi=y
CONFIG_PACKAGE_luci-app-ledtrig-switch=y
CONFIG_PACKAGE_luci-app-ledtrig-usbport=y
CONFIG_PACKAGE_luci-proto-wireguard=y
# ----------NAS_luci-app-ksmbd
# CONFIG_PACKAGE_luci-app-samba4 is not set
CONFIG_PACKAGE_luci-app-ksmbd=y
# ----------Theme_argon
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_PACKAGE_luci-theme-argon=y
EOF
}

config_func() {
    config_basic
    #=========================================
    # 功能包
    #=========================================
    cat << EOF
# ----------NAS_luci-app-aria2
CONFIG_PACKAGE_luci-app-aria2=m
# ----------NAS_luci-vsftpd
CONFIG_PACKAGE_luci-app-vsftpd=y
# ----------NET_PACKAGE_kcptun-client
CONFIG_PACKAGE_kcptun-client=m
# ----------PAK_tcpdump-mini
CONFIG_PACKAGE_tcpdump-mini=y
# ----------QOS_luci-app-nft-qos
CONFIG_PACKAGE_luci-app-nft-qos=m
# ----------QOS_luci-sqm
CONFIG_PACKAGE_luci-app-sqm=y
# ----------RPX_n2n
CONFIG_PACKAGE_luci-app-n2n=y
# ----------STAT_luci-app-nlbwmon
CONFIG_PACKAGE_luci-app-nlbwmon=m
# ----------Utilities_cfdisk
CONFIG_PACKAGE_cfdisk=y
# ----------STAT_luci-app-vnstat2
CONFIG_PACKAGE_luci-app-vnstat2=m
# ----------Test_NATMap
CONFIG_PACKAGE_luci-app-natmap=y
# ----------Test_wangyu_UDPspeeder
CONFIG_PACKAGE_UDPspeeder=y
CONFIG_PACKAGE_luci-app-speederv2=y
# ----------Test_wangyu_tinyfecVPN
CONFIG_PACKAGE_luci-app-tinyfecvpn=y
CONFIG_PACKAGE_tinyfecvpn=y
# ----------Test_wangyu_udp2raw
CONFIG_PACKAGE_luci-app-udp2raw=y
CONFIG_PACKAGE_udp2raw=y

EOF
}

config_test() {
    config_func
    #=========================================
    # 测试域
    #=========================================
    cat << EOF
# ----------RPX_nps
CONFIG_PACKAGE_luci-app-npc=m
CONFIG_PACKAGE_luci-app-nps=m
CONFIG_PACKAGE_npc=m
# ----------Test_ddns-go
CONFIG_PACKAGE_luci-app-ddns-go=m
# ----------Test_lucky
CONFIG_PACKAGE_luci-app-lucky=m
# ----------rmAD_luci-app-adguardhome
CONFIG_PACKAGE_luci-app-adguardhome=m
# CONFIG_PACKAGE_luci-app-adguardhome_INCLUDE_binary is not set
# ----------Func_luci-app-tinyproxy
CONFIG_PACKAGE_luci-app-tinyproxy=y
# ----------Func_luci-app-wechatpush
CONFIG_PACKAGE_luci-app-wechatpush=y
# ----------Func_unblockmusic_Go
CONFIG_PACKAGE_luci-app-unblockmusic=y
CONFIG_PACKAGE_luci-app-unblockmusic_INCLUDE_UnblockNeteaseMusic_Go=y
# ----------Test_luci-app-store
CONFIG_PACKAGE_luci-app-store=y

EOF
}
