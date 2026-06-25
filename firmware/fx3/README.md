# FX3 工具链与构建环境搭建

构建 `firmware/fx3` 下的 bootloader / firmware 需要 **Cypress 官方提供的 ARM 交叉工具链 + EZ-USB FX3 SDK**。
本文档记录在 **Linux x86_64** 上把环境跑通的完整步骤，重点是几个容易踩的坑。

代码复制自[UHD v4.10.0.0](https://github.com/EttusResearch/uhd/tree/v4.10.0.0)，在此基础上做仿制板差异修改。

### 相对 UHD 的改动

**bootloader** —— 小修改如下：

1. 支持读写EEPROM元信息。
2. EEPROM未初始化的时候默认为`2500:0020`，而非 UHD 原版的 Cypress `04b4:00f0`。

**firmware（主固件）/ common** —— 从 UHD 拷贝，仅在仿制板与官方 B200/B210 有差异处做针对性修改，改动处就地标注原因。

---

## 1. 准备 SDK 与工具链

从 Cypress 的 EZ-USB FX3 SDK（`ezusbfx3sdk_1.3.5_Linux_*.tar.gz`）中解压出两样东西：

- `arm-2013.11/` —— Sourcery CodeBench Lite ARM 交叉工具链（gcc 4.8.1）
- `cyfx3sdk/`   —— FX3 固件库、链接脚本、构建配置（`fw_lib/`、`fw_build/`、`util/` 等）

**约定的目录布局**（仓库与 SDK 同级摆放）：

```
<某个父目录>/
├── nb-minib210/        <- 本仓库
└── fx3sdk/             <- 解压到这里
    ├── arm-2013.11/
    └── cyfx3sdk/
```

`setup_env.sh` 默认就按这个布局找 SDK；放别处也行，用 `FX3SDK=...` 覆盖即可（见第 4 节）。

---

## 2. ⚠️ 关键坑：32 位运行库

`arm-2013.11` 里的工具链是 **32 位 i386 可执行文件**：

```console
$ file fx3sdk/arm-2013.11/bin/arm-none-eabi-gcc
... ELF 32-bit LSB executable, Intel i386 ...
```

在 64 位系统上，如果没有装 32 位 glibc，会报这种**极具迷惑性**的错误（文件明明在，却说找不到）：

```console
$ arm-none-eabi-gcc --version
bash: .../arm-none-eabi-gcc: cannot execute: required file not found
```

原因是缺少 32 位动态链接器 `/lib/ld-linux.so.2` 和 32 位 `libc/libm/libdl`。装上即可。

### Arch Linux

需要启用 `multilib` 仓库再装 `lib32-glibc`：

```bash
# 1) 启用 multilib：编辑 /etc/pacman.conf，取消（或新增）以下两行的注释
#    [multilib]
#    Include = /etc/pacman.d/mirrorlist
sudo pacman -Sy
sudo pacman -S lib32-glibc
```

### Ubuntu / Debian

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install libc6:i386 libstdc++6:i386 zlib1g:i386
```

> 这套 Sourcery 工具链的核心依赖只有 32 位 `glibc`（`libc6:i386` / `lib32-glibc`）。
> `libstdc++6:i386`、`zlib1g:i386` 是为稳妥起见一并装上，避免个别工具缺库。

### 验证

```console
$ arm-none-eabi-gcc --version
arm-none-eabi-gcc (Sourcery CodeBench Lite 2013.11-24) 4.8.1
```

打印出 `4.8.1` 即说明 32 位工具链已经能正常运行。

---

## 3. 主机侧构建工具

- `make`、`gcc`（编译 bootloader 用到的 `elf2img` 小工具，是**主机本地** gcc，不是交叉工具链）
- `patch`（给 SDK 打内存布局补丁，见 README）

Arch：`sudo pacman -S base-devel`。Ubuntu：`sudo apt install build-essential`。

---

## 4. 设置环境变量

构建用到三个环境变量，由 [`setup_env.sh`](setup_env.sh) 统一设置：

| 变量 | 含义 | 值 |
| --- | --- | --- |
| `ARMGCC_INSTALL_PATH` | ARM 交叉工具链根目录 | `<fx3sdk>/arm-2013.11` |
| `ARMGCC_VERSION`      | 工具链 gcc 版本（用于拼 `libgcc.a` 路径） | `4.8.1` |
| `FX3FWROOT`           | FX3 SDK 根目录 | `<fx3sdk>/cyfx3sdk` |

在每个新 shell 里 `source` 一次（注意是 source，不是直接执行）：

```bash
cd nb-minib210
source firmware/fx3/setup_env.sh
# SDK 不在默认位置时：
FX3SDK=/abs/path/to/fx3sdk source firmware/fx3/setup_env.sh
```

脚本同时会把 `arm-2013.11/bin` 加进 `PATH`，并自检工具链能否运行。

---

## 5. 一键构建（推荐）

`firmware/fx3/` 下有个总 `Makefile`，自动定位 SDK、设好环境变量、**幂等**打补丁并构建：

```bash
make -C firmware/fx3            # 打补丁(幂等) + 构建 firmware 和 bootloader
# SDK 不在默认位置（<repo>/../fx3sdk）时：
make -C firmware/fx3 FX3SDK=/abs/path/to/fx3sdk
```

常用目标：`make firmware` / `make bootloader` / `make patch` / `make unpatch` / `make clean`。

> 它用「反向 dry-run 检测」判断补丁是否已套用：已套用则跳过（不报错、不留 `.rej`），
> 未套用则套用，其它异常状态才报错。所以可以反复 `make` 而不必担心重复打补丁。
> 用了这个总 Makefile 就**不必**手动 `source setup_env.sh`（变量由 Makefile 内部导出）。

下面第 6、7 节是等价的手动步骤，便于理解内部流程或单独调试。

---

## 6. 给 SDK 打内存布局补丁（手动）

固件启用了 `HAS_HEAP` / `ENABLE_MSG`（见 `b200_main.c`），需要调整 SDK 的内存布局：
扩大代码区、预留一块 heap。补丁文件是 [`b200/fx3_mem_map.patch`](b200/fx3_mem_map.patch)。

> **关于这份补丁**：官方 UHD 自带的 `fx3_mem_map.patch` 是针对 **SDK 1.3.4 + LF 换行**写的，
> 对我们用的 **1.3.5** 直接套用会失败（1.3.5 改了 I-TCM 布局，且 SDK 文件是 CRLF 换行）。
> 因此本仓库的 `fx3_mem_map.patch` 已**重做为针对 1.3.5、且 CRLF 原生**的版本 ——
> 功能改动与官方一致（同样的 heap / 内存区调整），但上下文对齐 1.3.5，换行保持 CRLF，
> 可用 `patch --binary` 直接套用，**无需 dos2unix 之类的换行转换工具**。

套用补丁（`--binary` 让 patch 不剥离 CR，从而匹配 CRLF 的 SDK 文件）：

```bash
patch -p1 --binary --forward -d "$FX3FWROOT" < firmware/fx3/b200/fx3_mem_map.patch
```

> `--forward` 让重复套用时被识别为 “already applied” 而跳过，不会重复打。

## 7. 构建子工程（手动）

手动构建前需先 `source firmware/fx3/setup_env.sh`（见第 4 节），然后：

```bash
make -C firmware/fx3/b200/firmware     # 产出 usrp_b200_fw.hex
make -C firmware/fx3/b200/bootloader   # 产出 usrp_b200_bl.img
```

- `usrp_b200_fw.hex` —— FX3 主固件，交给 UHD 用来烧到 B2xx 设备。
- `usrp_b200_bl.img` —— bootloader 镜像，可作为参数传给 `b2xx_fx3_utils` 烧录。

> 编译过程中会有若干 `-Wunused` / `-Wcast-align` 警告，属官方源码原样保留，不影响产物。

以上流程已在本仓库（Arch Linux x86_64 + SDK 1.3.5 + arm-2013.11 gcc 4.8.1）实测跑通。
