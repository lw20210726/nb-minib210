# FX3 一键构建入口
# ================
# 自动定位 Cypress SDK、设置环境变量、幂等打补丁，并构建 firmware + bootloader。
#
# 用法：
#     make            # 打补丁(幂等) + 构建 firmware 和 bootloader
#     make firmware   # 仅构建主固件   -> b200/firmware/usrp_b200_fw.hex
#     make bootloader # 仅构建 bootloader -> b200/bootloader/usrp_b200_bl.img
#     make patch      # 仅幂等打补丁
#     make unpatch    # 还原补丁（用于测试 / 切换 SDK）
#     make clean      # 清理两个子工程的构建产物
#
# SDK 位置：默认在仓库同级的 fx3sdk/（即 <repo>/../fx3sdk）。放别处时覆盖：
#     make FX3SDK=/abs/path/to/fx3sdk
#
# 详见 TOOLCHAIN.md。

# 本 Makefile 所在目录（带末尾斜杠），不依赖调用时的 cwd
THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# SDK 默认位置：firmware/fx3 -> 上三级 -> fx3sdk
FX3SDK ?= $(abspath $(THIS_DIR)../../../fx3sdk)

# 构建子工程（b200/*/makefile）需要的环境变量，导出后会自动传给递归 make
export ARMGCC_INSTALL_PATH := $(FX3SDK)/arm-2013.11
export ARMGCC_VERSION      := 4.8.1
export FX3FWROOT           := $(FX3SDK)/cyfx3sdk
export PATH                := $(ARMGCC_INSTALL_PATH)/bin:$(PATH)

PATCH := $(THIS_DIR)b200/fx3_mem_map.patch
FW_DIR := $(THIS_DIR)b200/firmware
BL_DIR := $(THIS_DIR)b200/bootloader

# patch 用 --binary 以匹配 SDK 文件的 CRLF 换行；-f 关闭交互提示
PATCH_BASE := patch -p1 --binary -f -d "$(FX3FWROOT)"

.PHONY: all firmware bootloader patch unpatch clean check

all: firmware bootloader

# 环境自检：SDK 与工具链是否就位
check:
	@if [ ! -d "$(FX3FWROOT)" ] || [ ! -d "$(ARMGCC_INSTALL_PATH)" ]; then \
		echo "ERROR: 找不到 SDK：$(FX3SDK)"; \
		echo "       期望其中包含 arm-2013.11/ 与 cyfx3sdk/。"; \
		echo "       SDK 在别处时用： make FX3SDK=/abs/path/to/fx3sdk"; \
		exit 1; \
	fi
	@if ! arm-none-eabi-gcc --version >/dev/null 2>&1; then \
		echo "ERROR: arm-none-eabi-gcc 无法运行（多半缺 32 位运行库）。"; \
		echo "       Arch: pacman -S lib32-glibc;  Ubuntu: apt install libc6:i386"; \
		echo "       详见 TOOLCHAIN.md。"; \
		exit 1; \
	fi

# 幂等打补丁：直接查询 SDK 当前状态，不依赖标记文件
#   1) 反向 dry-run 成功 => 补丁已套用 => 跳过（不报错、不产生 .rej）
#   2) 正向 dry-run 成功 => 尚未套用 => 套用
#   3) 两者都失败       => SDK 处于异常/非预期状态 => 报错
patch: check
	@if $(PATCH_BASE) -R --dry-run < "$(PATCH)" >/dev/null 2>&1; then \
		echo "[patch] SDK 已打过补丁，跳过。"; \
	elif $(PATCH_BASE) --forward --dry-run < "$(PATCH)" >/dev/null 2>&1; then \
		echo "[patch] 给 SDK 套用内存布局补丁..."; \
		$(PATCH_BASE) --forward < "$(PATCH)"; \
	else \
		echo "ERROR: 补丁既无法正向套用、也不是已套用状态。"; \
		echo "       SDK 可能不是预期的 1.3.5，或已被手工改动。"; \
		exit 1; \
	fi

# 还原补丁（仅在已套用时执行，幂等）
unpatch: check
	@if $(PATCH_BASE) -R --dry-run < "$(PATCH)" >/dev/null 2>&1; then \
		echo "[unpatch] 还原补丁..."; \
		$(PATCH_BASE) -R < "$(PATCH)"; \
	else \
		echo "[unpatch] SDK 未处于已套用状态，无需还原。"; \
	fi

firmware: patch
	@$(MAKE) -C "$(FW_DIR)"

bootloader: patch
	@$(MAKE) -C "$(BL_DIR)"

clean:
	@$(MAKE) -C "$(FW_DIR)" clean
	@$(MAKE) -C "$(BL_DIR)" clean
