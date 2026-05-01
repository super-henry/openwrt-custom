#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _lib/_mod-lede.sh
# Description: LEDE 通用修改与 feeds 更新逻辑
#              原位于 Configurator-LEDE-32M.sh
#

modification() {
    # 一些可能必要的修改
    echo '[MOD]除去 luci-app-dockerman 的架构限制'
    find -type f -path '*/luci-lib-docker/Makefile' -print -exec sed -i 's#@(aarch64||arm||x86_64)##w /dev/stdout' {} \;

    # 删除冲突的插件，解决Lean源码编译出错
    rm -rf feeds/kenzo/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
}

add_packages() {
    [ -e is_add_packages ] && echo "已进行过加包操作，不再执行" && return 0
    
    # 修正依赖，调整菜单
    modification
    echo '=====================修改结束======================='
    echo '[强制] 更新索引并装载软件包'
    ./scripts/feeds update -ifa
    ./scripts/feeds install -a
    echo '=====================重载结束======================='

    # 已修改标志（其实也就DEBUG的时候有用）
    touch is_add_packages
}
