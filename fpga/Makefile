# =============================================================================
# Makefile -- miniB210 LibreSDR FPGA 一键构建（Linux Vivado 用户）
#
# build.ps1 / build.cmd 的 Linux 对应物。Linux 本来就自带 make，直接用。
#
# 用法（在 fpga/ 目录）：
#   make w19_100t        构建单个产物（w19_100t v18_100t w19_200t v18_200t）
#   make all             4 个全出（串行：100t 两个时钟 → 200t 两个时钟）
#   make clean           删 Vivado 中间目录（含中断残留），保留 build/ 产物
#   make distclean       中间目录 + build/ 产物一起删
#   make help            显示帮助
#
#   make JOBS=12 all                  调综合/实现并行数（默认 8）
#   make VIVADO=/opt/Xilinx/Vivado/2024.1/bin/vivado all   手动指定（默认自动检测）
# =============================================================================

SHELL := /bin/bash
JOBS  ?= 8

# 自动检测 vivado：先 PATH，否则扫标准安装目录（/opt、/tools）取最高版本
VIVADO ?= $(shell command -v vivado 2>/dev/null || \
            ls -d /opt/Xilinx/Vivado/*/bin/vivado /tools/Xilinx/Vivado/*/bin/vivado 2>/dev/null \
            | sort -V | tail -n1)

ROOT      := $(CURDIR)
PROJ_DIR  := $(ROOT)/libresdr_b210
BUILD_TCL := $(ROOT)/build.tcl
OUT_DIR   := $(ROOT)/build
LOG_DIR   := $(OUT_DIR)/logs

# 4 个产物共用同一套 .runs，绝不能并行（make -j 也强制串行，避免互相踩）
.NOTPARALLEL:
.PHONY: help all w19_100t v18_100t w19_200t v18_200t clean distclean

help:
	@awk '/^# ?={5,}/{c++; next} c==1 && /^#/{sub(/^# ?/,""); print} c>=2{exit}' $(firstword $(MAKEFILE_LIST))

# 单产物构建宏（canned recipe，无前导 tab；$(1)=clk  $(2)=dev）
define build_one
@test -n "$(VIVADO)" || { echo "未找到 vivado：用 make VIVADO=<路径>，或先 source settings64"; exit 1; }
@mkdir -p $(LOG_DIR)
@echo "==> 构建 $(1)/$(2)  (jobs=$(JOBS))  vivado=$(VIVADO)"
cd $(OUT_DIR) && "$(VIVADO)" -mode batch -notrace -log $(LOG_DIR)/$(1)_$(2).log -journal $(LOG_DIR)/$(1)_$(2).jou -source $(BUILD_TCL) -tclargs $(1) $(2) $(JOBS)
@echo "==> 完成 $(1)/$(2) -> build/libresdr_b210_$(1)_$(2).bit/.bin"
endef

w19_100t:
	$(call build_one,w19,100t)
v18_100t:
	$(call build_one,v18,100t)
w19_200t:
	$(call build_one,w19,200t)
v18_200t:
	$(call build_one,v18,200t)

# 器件分组：100t 两个时钟 → 200t 两个时钟（器件只切一次）
all: w19_100t v18_100t w19_200t v18_200t

clean:
	@echo "==> 清理 Vivado 中间目录"
	rm -rf $(PROJ_DIR)/libresdr_b210.{runs,gen,cache,hw,ip_user_files,sim} $(PROJ_DIR)/.Xil
	rm -f  $(PROJ_DIR)/vivado*.{log,jou} $(ROOT)/vivado*.{log,jou}
	@echo "==> 清理完成（保留 build/ 产物）"

distclean: clean
	@echo "==> 删除 build/ 最终产物"
	rm -rf $(OUT_DIR)
	@echo "==> 彻底清理完成"
