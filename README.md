# 自用 OpenWrt 编译库

基于 GitHub Actions 云编译，为手头几台 MT762x 路由器按需打造固件。支持 **Lean's LEDE** 和 **OpenWrt 主线** 双系统，设备定义、系统补丁、配置档位全部模块化，改一两个文件就能为新设备/新系统快速配出一套编译方案。

## 设备型号

| [Model](https://openwrt.org/toh) | SoC               | CPU MHz | Flash MB | RAM MB | WLAN Hardware                         | WLAN2.4  | WLAN5.0 | 100M ports | Gbit ports | TF-slot | USB    |
| :------------------------------- | :---------------- | :------ | :------- | :----- | :------------------------------------ | :------- | :------ | :--------- | :--------- | :------ | :----- |
| HC5661                           | MediaTek MT7620A  | 580     | 16       | 128    | MediaTek MT7620A                      | b/g/n    | -       | 5          | -          | -       | -      |
| Newifi D2 (Newifi3)              | MediaTek MT7621AT | 880     | 32       | 512    | MediaTek MT7603EN, MediaTek MT7612EN  | b/g/n    | ac/n    | -          | 5          | -       | 1x 3.0 |
| RE-SP-01B                        | MediaTek MT7621AT | 880     | 32       | 512    | MediaTek MT7603, MediaTek MT7615      | b/g/n    | ac/n    | -          | 3          | -       | 1x 2.0 |
| RE-CP-02                         | MediaTek MT7621AT | 880     | 16       | 512    | MediaTek MT7975DN, MediaTek MT7905DAN | ax/b/g/n | ac/ax/n | -          | 4          | Y       | -      |

## 适配系统

| Model               | [Lean's LEDE](https://github.com/coolsnowwolf/lede) | [OpenWrt](https://github.com/openwrt/openwrt) | 备注                                     |
| ------------------- | --------------------------------------------------- | --------------------------------------------- | ---------------------------------------- |
| HC5661              | ✅                                                   | 🤪                                             | 弃坑，太弱鸡了，建议用 padavan           |
| Newifi D2 (Newifi3) | ✅                                                   | ✅                                             |                                          |
| RE-SP-01B           | ✅                                                   | 🧙‍♂️                                             |                                          |
| RE-CP-02            | 🤪                                                   | 🧙‍♂️                                             | [鲁班固件魔改分区说明](RE-CP-02.md) |

✅-与上游一致 | 🧙‍♂️-基于上游适配 | 🤪-本库未配置

> 对于 RE-CP-02（京东云鲁班），我折腾了一套"不硬改 + 最大榨取 16M 闪存"的方案：魔改 breed bootloader 内嵌 EEPROM/MAC，将固件可用空间推到 **16192 KiB**。详细思路见 [鲁班固件魔改分区说明](RE-CP-02.md)。

## 怎么用

这玩意儿跑在 GitHub Actions 上，不需要本地搭编译环境。

### 触发一次编译

1. 打开仓库的 **Actions** 标签页
2. 选择 **Build Image** workflow → **Run workflow**
3. 填三个参数：
   - `选择型号`：`device-env.sh` 里定义的设备编号（1~6）
   - `选择配置版本`：`clean`（仅默认） / `basic`（基础增强） / `func`（全功能） / `test`（功能全开 + 实验包）
   - `使用指定的commit`：留空用最新，也可指定某个 commit hash
4. 跑完去 Artifacts 下载固件

### 项目结构

```
├── device-env.sh                  # 设备环境变量清单（每台设备=一个 case）
├── diy-part1.sh                   # 编译前步骤：追加第三方 feed 源
├── diy-part2/                     # 编译中期：模块化配置生成
│   ├── diy2arch.sh                #   统一调度入口，按 DEVICE/SYSTEM/FLASH/TAG 组装
│   ├── _device/                   #   设备定义（target、默认配置、DTS/MK/NETWORK 补丁）
│   │   ├── HC5661.sh
│   │   ├── Newifi3D2.sh
│   │   ├── RE-SP-01B.sh
│   │   └── RE-CP-02.sh
│   ├── _lib/                      #   系统级通用修改
│   │   ├── sys-lede.sh            #     Lean's LEDE：去冲突、调菜单
│   │   ├── sys-openwrt.sh         #     OpenWrt：拉外部包（luci-app-n2n/nps/vsftpd 等）、修依赖、调入口
│   │   └── defaults-helper.sh     #     共享函数：改 IP / 时区 / 主机名 / 主题 / uci-defaults
│   ├── config-profiles/           #   配置档位（clean/basic/func/test），按系统+闪存大小分文件
│   │   ├── lede-32M.sh
│   │   ├── openwrt-16M.sh
│   │   └── openwrt-32M.sh
│   └── uci-defaults.sh            #   首次启动时注入的系统默认设置
├── patches/                       # 设备专属补丁（DTS 分区重划、IMAGE_SIZE 扩容、MAC 读取逻辑等）
├── .github/workflows/
│   ├── [AIO]Build.yml             #   主编译流水线
│   ├── [AIO]SizeTest.yml          #   固件体积测试
│   └── update-checker.yml         #   上游更新检测
├── scripts/
│   ├── preview-config.sh          #   预览生成的 .config
│   ├── generate-html.sh           #   生成设备配置对照表 HTML 页面
│   └── conflict-clamer.sh         #   配置冲突检测
└── testSeq/                       #   测试序列，用于配置项校验
```

### 一条流水线怎么跑的

```
device-env.sh         → 确定 REPO / BRANCH / ARCH / 闪存大小
    ↓
diy-part1.sh          → 追加 feeds 源（kenzok8 小包合集等）
    ↓
feeds update & install → 加载所有软件包索引
    ↓
diy2arch.sh           → ① 载入设备定义 → ② 载入系统修改 → ③ 载入配置档
    ↓                   ④ 应用 DTS/mk 补丁（扩容闪存、重划分区）
    ↓                   ⑤ 生成最终的 .config
make download         → 下载源码包（含重试机制）
    ↓
make                  → 编译，自动降线程容错
    ↓
Artifacts / Release   → 产出固件（可选上传 wetransfer 等网盘）
```

### 配置档位说明

| 档位    | 包含内容                                                       |
| ------- | -------------------------------------------------------------- |
| `clean` | 仅设备默认功能 + 中文本地化                                    |
| `basic` | 基础增强：Argon 主题、DDNS、upnp、ksmbd、USB 自动挂载、TTYD 等 |
| `func`  | 常用全功能：aria2、vsftpd、n2n、udp2raw、tinyfecvpn、sqm 等    |
| `test`  | 全功能 + 实验包：AdGuardHome、ddns-go、lucky、wechatpush 等    |

### 本地预览

不用真编译就能看一眼生成的 `.config` 长啥样：

```bash
# 预览设备 5（OpenWrt RE-SP-01B）的 func 配置
bash scripts/preview-config.sh 5 func

# 生成配置对比 HTML（所有设备 x 所有档位）
bash scripts/generate-html.sh
```

## 亮点

- **全模块化**：加新设备只需新建一个 `_device/xxx.sh` 文件，shell 脚本干净、可读性强
- **智能容错**：下载包两轮重试、编译失败自动降线程到单线程 `V=s` 排障
- **配置子集校验**：生成的 `.config` 会与上游 defconfig 做 diff，确认自定义配置项不丢不落
- **鲁班专项适配**：在 OpenWrt 上游已有支持的基础上，通过补丁调整分区布局，最大化 16M 闪存的利用率
- **设备对照 HTML**：一键生成可视化对比页面，所有配置项按分组折叠/展开，一目了然

——如果能帮到你，那是我的荣幸——

*暂无更多适配计划*

## 致谢

云编译模板源自 [P3TERX 的 Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) Ver.[97697df](https://github.com/P3TERX/Actions-OpenWrt/tree/97697df385dc2036681aafed73afd2cd903632f1)

> Actions-OpenWrt - A template for building OpenWrt with GitHub Actions
>
> [English](https://github.com/P3TERX/Actions-OpenWrt/blob/main/README.md) | [中文](https://p3terx.com/archives/build-openwrt-with-github-actions.html)
>
> [![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE) ![GitHub Stars](https://img.shields.io/github/stars/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Stars&logo=github) ![GitHub Forks](https://img.shields.io/github/forks/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Forks&logo=github)
