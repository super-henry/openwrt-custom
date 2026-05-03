#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: _lib/sys-openwrt.sh
# Description: OpenWrt 通用修改与外部包拉取逻辑
#              原分散在 Configurator-OpenWrt-16M.sh 和 Configurator-OpenWrt-32M.sh 中
#

modification() {
    # 一些可能必要的修改
    echo '[MOD] 把家目录也添加到备份路径'
    echo '/root' > package/base-files/files/lib/upgrade/keep.d/home
    echo
    echo '[FIX] 开机创建 /dev/fd --> /proc/self/fd'
    sed -i '\#exit#iln -nsf /proc/self/fd /dev/fd' package/base-files/files/etc/rc.local
    cat package/base-files/files/etc/rc.local
    echo
    echo '[FIX] 创建硬链接，解决无法正确识别出简体中文语言包的问题'
    # ref: https://github.com/ysc3839/luci-proto-minieap/pull/2
    find -type d -path '*/po/zh-cn' | xargs dirname | xargs -I'{}' ln -srvn {}/zh-cn {}/zh_Hans

    echo
    echo '[MOD] 更换 luci-app-clash 的依赖 openssl 为 mbedtls'
    find -type f -path '*/luci-app-clash/Makefile' -print -exec sed -i 's/openssl/mbedtls/w /dev/stdout' {} \;

    echo
    echo '[MOD] 移除 luci-theme-argon 对 wget 的依赖'
    find -type f -path '*/luci-theme-argon/Makefile' -print -exec sed -i 's/+wget\b/+wget-any/w /dev/stdout' {} \;

    echo
    echo '[MOD] 更换 luci-app-easymesh 的依赖 openssl 为 mbedtls'
    find -type f -path '*/luci-app-easymesh/Makefile' -print -exec sed -i 's/openssl/mbedtls/w /dev/stdout' {} \;

    echo
    echo '[MOD] 更换 ttyd 的依赖 openssl 为 mbedtls'
    find -type f -path '*/ttyd/Makefile' -print -exec sed -i -e 's/+libopenssl \+//' -e 's/libwebsockets-full/libwebsockets-mbedtls/g' -e 'w /dev/stdout' {} \;

    echo
    echo '[MOD] 为 libwebsockets-mbedtls 增加 libuv 支持'
    find -type f -path '*/libwebsockets/Makefile' -print -exec sed -i \
        -e '/^[[:space:]]*DEPENDS.*+libmbedtls/ s/$/ +libuv/' \
        -e '/    CMAKE_OPTIONS += -DLWS_WITH_MBEDTLS=1$/a\' \
        -e '    CMAKE_OPTIONS += -DLWS_WITH_LIBUV=ON' \
        -e 'w /dev/stdout' {} \;

    echo
    echo '[MOD] 除去 luci-app-dockerman 的架构限制'
    find -type f -path '*/luci-app-dockerman/Makefile' -print -exec sed -i 's#@(aarch64||arm||x86_64)##w /dev/stdout' {} \;
    find -type f -path '*/luci-lib-docker/Makefile' -print -exec sed -i 's#@(aarch64||arm||x86_64)##w /dev/stdout' {} \;

    if [ -e feeds/packages/lang/node/Makefile ]; then
        echo
        echo '[MOD] 使能 SOFT_FLOAT 环境下的 node'
        cd feeds/packages/lang/node && pwd -P
        sed -e 's/HAS_FPU/(HAS_FPU||SOFT_FLOAT)/' \
            -e '\#^CONFIGURE_ARGS:= \\#a\\t$(if $(findstring mips,$(NODEJS_CPU)), $(if $(CONFIG_SOFT_FLOAT),--with-mips-float-abi=soft)) \\' \
            Makefile > Makefile.mod
        diff -u2 Makefile Makefile.mod
        echo "=====================EoDIFF======================="
        mv -f Makefile.mod Makefile
        cd -
    fi
    # echo '[MOD] 把 node 替换成 lean 的'
    # rm -rf feeds/packages/lang/node
    [ -d feeds/kenzo/upx ] && echo '[RM] 删除 kenzo 引用的 coolsnowwolf 源的 upx' && rm -vrf feeds/kenzo/upx*

    echo
    echo '[FIX] PKG_USE_MIPS16已被openwrt主线弃用，修改外部包的 PKG_USE_MIPS16:=0 为 PKG_BUILD_FLAGS:=no-mips16'
    find -type f -name Makefile -exec sh -c '
        if grep -q "PKG_USE_MIPS16:=0" "$0"; then
            echo -n "[$0] "
            sed -i "s/PKG_USE_MIPS16:=0/PKG_BUILD_FLAGS:=no-mips16/w /dev/stdout" "$0"
        fi' {} \;

    # 修改入口
    change_entry() {
        [ "$#" -lt 3 ] && echo "[ch_entry_error] 需要至少3个参数：旧入口、新入口和目录路径" && return 1
        [ ! -d "$3" ] && echo "目录不存在：$3" && return 1
        
        local old_entry="$1"
        local new_entry="$2"
        echo -e "\n[MOD] 将 $(echo "$3" | grep -o 'luci-app[^/]*') 从 <$old_entry> 移动到 <$new_entry> [$3]"
        
        find "$3" ! -path "*.svn*" -type f \
            -exec grep -q "$old_entry" {} \; -exec \
                sh -c 'echo "\n== 修改入口记录: [$0]"; sed -i "s/$1/$2/w /dev/stdout" "$0"' \
                    {} "$old_entry" "$new_entry" \;
    }
    echo
    echo 'luci-app-vsftpd 定义了一级菜单 <nas>'
    change_entry services nas feeds/luci/applications/luci-app-aria2
    change_entry services nas feeds/luci/applications/luci-app-hd-idle
    # change_entry services nas feeds/luci/applications/luci-app-ksmbd  # <nas> menu defined by vsftpd; ksmbd may not be enabled in clean/basic
    change_entry services nas feeds/luci/applications/luci-app-transmission

    echo
    echo 'luci-app-n2n 定义了一级菜单 <VPN>'
    change_entry services vpn feeds/kenzo/luci-app-npc
    change_entry services vpn feeds/kenzo/luci-app-udp2raw
    change_entry services vpn package/immortalwrt/luci-app-nps
    change_entry services vpn package/immortalwrt/luci-app-speederv2
    change_entry services vpn package/luci-app-tinyfecvpn
    # change_entry services vpn package/luci-app-kcptun

    echo
    # echo '把 luci-app-nft-qos 从 <services> 搬到 <network>'
    change_entry services network feeds/luci/applications/luci-app-nft-qos
    echo "=====================End Of Entry Change======================="
}

add_packages() {
    #=========================================
    # 两种方式：
    # M1. 拉取软件源码包放到feeds文件夹，如luci-app放到feeds/luci/
    # M2. 拉取软件源码包放到package文件夹，可以参考feeds再分源创建不同的文件夹
    # 
    # 大概原理：
    # 1. ./script/feeds install时会将feeds中的包在package/feeds中创建硬链接
    # 
    # 注意：
    # 1. luci包须include feeds/luci.mk，某些包(如immortalwrt)引用的luci.mk是相对路径的，需要修正
    # 2. 部分包，需要创建语言名的硬链接（zh-cn -> zh_Hans），update&install feeds
    #=========================================
    [ -e is_add_packages ] && echo "已进行过加包操作，不再执行" && return 0
    
    # M1 START
    echo '一、向 feeds 里加点东西'
    cd feeds && echo "...Entering `pwd`"
    echo "=====================End Of feeds modification=======================" && cd ..
    # M1 END

    # M2 START
    echo '二、向 package 里加点包或Makefile'
    cd package && echo "...Entering `pwd`"
    echo

    echo '## From coolsnowwolf'
    echo '== 从酷雪狼(lean)那里借个自动外存挂载 automount, luci-app-unblockmusic'
    # https://github.com/coolsnowwolf/lede/tree/master/package/lean/automount
    wget --content-disposition https://codeload.github.com/coolsnowwolf/lede/zip/refs/heads/master
    unzip lede-master.zip lede-master/package/lean/automount/*
    mv -v lede-master/package/lean ./
    rm -rf lede-master lede-master.zip
    # https://github.com/coolsnowwolf/luci/tree/master/applications/luci-app-unblockmusic
    wget --content-disposition https://codeload.github.com/coolsnowwolf/luci/zip/refs/heads/master
    unzip luci-master.zip luci-master/applications/luci-app-unblockmusic/*
    mv -v luci-master/applications/luci-app-unblockmusic ./lean/
    rm -rf luci-master luci-master.zip
    echo -e '备注：\ncoolsnowwolf的unblockmusic支持云解锁、Go和Nodejs\nUnblockNeteaseMusic的luci-app-unblockneteasemusic不支持Go'
    echo

    echo '## From immortalwrt'
    echo '== 从天灵那里借个 luci-app-n2n, luci-app-nps, luci-app-vsftpd, luci-app-speederv2'
    # https://github.com/immortalwrt/luci/blob/master/applications/*
    wget --content-disposition https://codeload.github.com/immortalwrt/luci/zip/refs/heads/master
    unzip luci-master.zip luci-master/applications/luci-app-n2n/* luci-master/applications/luci-app-nps/* luci-master/applications/luci-app-vsftpd/* luci-master/applications/luci-app-speederv2/*
    mv -v luci-master/applications ./immortalwrt
    rm -rf luci-master luci-master.zip
    echo '== 还有依赖 n2n，以及 Yu Wang 的 tinyfecvpn、udp2raw'
    # https://github.com/immortalwrt/packages/blob/master/*
    wget --content-disposition https://codeload.github.com/immortalwrt/packages/zip/refs/heads/master
    unzip packages-master.zip packages-master/net/n2n/* packages-master/net/tinyfecvpn/* packages-master/net/udp2raw/*
    mv -v packages-master/net ./immortalwrt/net
    rm -rf packages-master packages-master.zip
    echo '[MOD] 在有nftables的设备上好像不需要添加防火墙规则，应用 n2n.init.patch'
    patch immortalwrt/net/n2n/files/n2n.init "${GITHUB_WORKSPACE}/patches/n2n.init.patch"
    # echo '从 Hyy2001X 那里借一个改好的 luci-app-npc(kenzo中已间接引用)'
    # echo '还有依赖 nps(kenzo中已引用coolsnowwolf源)'
    echo

    echo '## From OTHERS'
    echo '== 从 lisaac 那里加载 luci-app-diskman'
    wget -nv https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile -P luci-app-diskman
    echo
    echo '== 从 douo 那里拉取 tinyfecvpn 的 GUI'
    git clone --depth 1 https://github.com/douo/luci-app-tinyfecvpn.git
    # echo
    # echo '== 从 kuoruan 那里拉取 kcptun 的 GUI'
    # git clone --depth 1 https://github.com/kuoruan/luci-app-kcptun.git

    # 修正luci依赖
    find . -name Makefile -exec grep -q "../../luci.mk" {} \; -exec \
        sh -c 'echo "\n== 修正luci依赖: [$0]"; sed -i "s#../../luci.mk#\$(TOPDIR)/feeds/luci/luci.mk#w /dev/stdout" "$0"' {} \;
    echo "=====================End Of package modification=======================" && cd ..
    # M2 END

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
