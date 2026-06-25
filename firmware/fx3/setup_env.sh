#!/usr/bin/env bash
#
# 为构建 FX3 bootloader / firmware 准备环境变量。
# 用法（必须 source，不要直接执行）：
#
#     source firmware/fx3/setup_env.sh
#     # 或者自定义 SDK 位置：
#     FX3SDK=/path/to/fx3sdk source firmware/fx3/setup_env.sh
#
# 默认假设目录布局（详见 TOOLCHAIN.md）：
#     <某目录>/
#     ├── nb-minib210/      <- 本仓库
#     └── fx3sdk/           <- 解压好的 Cypress 工具链 + SDK
#         ├── arm-2013.11/  <- Sourcery CodeBench ARM 交叉工具链
#         └── cyfx3sdk/     <- EZ-USB FX3 SDK

# 解析本脚本所在目录（firmware/fx3），兼容 bash / zsh
_self="${BASH_SOURCE[0]:-${(%):-%x}}"
_here="$(cd "$(dirname "$_self")" && pwd)"

# fx3sdk 默认在仓库同级目录： firmware/fx3 -> ../../.. -> 仓库父目录/fx3sdk
: "${FX3SDK:=$(cd "$_here/../../.." && pwd)/fx3sdk}"

if [ ! -d "$FX3SDK/arm-2013.11" ] || [ ! -d "$FX3SDK/cyfx3sdk" ]; then
    echo "[setup_env] 找不到 SDK：$FX3SDK" >&2
    echo "[setup_env] 请设置 FX3SDK 指向解压后的 fx3sdk 目录（内含 arm-2013.11/ 与 cyfx3sdk/）" >&2
    return 1 2>/dev/null || exit 1
fi

export ARMGCC_INSTALL_PATH="$FX3SDK/arm-2013.11"
export ARMGCC_VERSION="4.8.1"
export FX3FWROOT="$FX3SDK/cyfx3sdk"

# 把交叉工具链加入 PATH（makefile 直接调用 arm-none-eabi-gcc 等）
case ":$PATH:" in
    *":$ARMGCC_INSTALL_PATH/bin:"*) ;;                       # 已在 PATH 中
    *) export PATH="$ARMGCC_INSTALL_PATH/bin:$PATH" ;;
esac

echo "[setup_env] ARMGCC_INSTALL_PATH = $ARMGCC_INSTALL_PATH"
echo "[setup_env] ARMGCC_VERSION      = $ARMGCC_VERSION"
echo "[setup_env] FX3FWROOT           = $FX3FWROOT"

# 顺手自检：32 位工具链能否真正运行（缺 32 位 glibc 时会失败，见 TOOLCHAIN.md）
if ! arm-none-eabi-gcc --version >/dev/null 2>&1; then
    echo "[setup_env] 警告：arm-none-eabi-gcc 无法运行。" >&2
    echo "[setup_env]        多半是缺少 32 位运行库，请参考 TOOLCHAIN.md 安装 lib32-glibc / libc6:i386。" >&2
fi
