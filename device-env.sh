#!/bin/bash

echo "Hi, I'm $0."
# 提取整数部分：删除第一个小数点及其后面的所有字符
int_part="${1%%.*}"

case $int_part in
    1)
        DEVICE_TAG="Lean's LEDE - HC5661"
        REPO_USE=coolsnowwolf/lede
        REPO_BRANCH=master
#         COMMIT_SHA=latest
        DEVICE_ARCH="ramips"
        DIY_P2_SH="diy-part2/diy2arch.sh"
        DEPENDS=$(curl -fsSL "https://gist.githubusercontent.com/1-1-2/38e424cd9da729f72fa4a495d23271ea/raw/lean's%2520lede")
        SEQ_FILE="testSeq/lean's lede.ini"
        # 新增：新架构参数
        DEVICE_NAME="HC5661"
        SYSTEM_NAME="lede"
        FLASH_SIZE="32M"
        ;;
    2)
        DEVICE_TAG="Lean's LEDE - Newifi3_D2"
        REPO_USE=coolsnowwolf/lede
        REPO_BRANCH=master
#         COMMIT_SHA=latest
        DEVICE_ARCH="ramips"
        DIY_P2_SH="diy-part2/diy2arch.sh"
        DEPENDS=$(curl -fsSL "https://gist.githubusercontent.com/1-1-2/38e424cd9da729f72fa4a495d23271ea/raw/lean's%2520lede")
        SEQ_FILE="testSeq/lean's lede.ini"
        # 新增：新架构参数
        DEVICE_NAME="Newifi3D2"
        SYSTEM_NAME="lede"
        FLASH_SIZE="32M"
        ;;
    3)
        DEVICE_TAG="Lean's LEDE - RE-SP-01B"
        REPO_USE=coolsnowwolf/lede
        REPO_BRANCH=master
#         COMMIT_SHA=latest
        DEVICE_ARCH="ramips"
        DIY_P2_SH="diy-part2/diy2arch.sh"
        DEPENDS=$(curl -fsSL "https://gist.githubusercontent.com/1-1-2/38e424cd9da729f72fa4a495d23271ea/raw/lean's%2520lede")
        SEQ_FILE="testSeq/lean's lede.ini"
        # 新增：新架构参数
        DEVICE_NAME="RE-SP-01B"
        SYSTEM_NAME="lede"
        FLASH_SIZE="32M"
        ;;
    4)
        DEVICE_TAG="OpenWrt - Newifi3_D2"
        REPO_USE=openwrt/openwrt
        REPO_BRANCH=master
#         COMMIT_SHA=latest
        DEVICE_ARCH="ramips"
        DIY_P2_SH="diy-part2/diy2arch.sh"
        DEPENDS=$(curl -fsSL "https://gist.githubusercontent.com/1-1-2/38e424cd9da729f72fa4a495d23271ea/raw/openwrt")
        SEQ_FILE="testSeq/openwrt.ini"
        # 新增：新架构参数
        DEVICE_NAME="Newifi3D2"
        SYSTEM_NAME="openwrt"
        FLASH_SIZE="32M"
        ;;
    5)
        DEVICE_TAG="OpenWrt - RE-SP-01B"
        REPO_USE=openwrt/openwrt
        REPO_BRANCH=master
#         COMMIT_SHA=latest
        DEVICE_ARCH="ramips"
        DIY_P2_SH="diy-part2/diy2arch.sh"
        DEPENDS=$(curl -fsSL "https://gist.githubusercontent.com/1-1-2/38e424cd9da729f72fa4a495d23271ea/raw/openwrt")
        SEQ_FILE="testSeq/openwrt.ini"
        # 新增：新架构参数
        DEVICE_NAME="RE-SP-01B"
        SYSTEM_NAME="openwrt"
        FLASH_SIZE="32M"
        ;;
    6)
        DEVICE_TAG="OpenWrt - RE-CP-02"
        REPO_USE=openwrt/openwrt
        REPO_BRANCH=master
#         COMMIT_SHA=latest
        DEVICE_ARCH="ramips"
        DIY_P2_SH="diy-part2/diy2arch.sh"
        DEPENDS=$(curl -fsSL "https://gist.githubusercontent.com/1-1-2/38e424cd9da729f72fa4a495d23271ea/raw/openwrt")
        SEQ_FILE="testSeq/openwrt.ini"
        # 新增：新架构参数
        DEVICE_NAME="RE-CP-02"
        SYSTEM_NAME="openwrt"
        FLASH_SIZE="16M"
        ;;
    7)
        # undefined
        ;;
    *)
        echo "input error"
        exit 1
esac

# 检查是否已经指定 COMMIT_SHA 了
if [ $COMMIT_SHA == 'latest' ]; then
    USE_COMMIT_SHA='latest'
else
    USE_COMMIT_SHA=$COMMIT_SHA
fi

# set ENVs
cat << EOF | tee -a $GITHUB_ENV
DEVICE_TAG=${DEVICE_TAG}
REPO_USE=${REPO_USE}
REPO_BRANCH=${REPO_BRANCH}
USE_COMMIT_SHA=${USE_COMMIT_SHA}
DEVICE_ARCH=${DEVICE_ARCH}
DIY_P2_SH=${DIY_P2_SH}
DEPENDS=${DEPENDS}
SEQ_FILE=${SEQ_FILE}
DEVICE_NAME=${DEVICE_NAME}
SYSTEM_NAME=${SYSTEM_NAME}
FLASH_SIZE=${FLASH_SIZE}

EOF