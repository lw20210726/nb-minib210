# nb-minib210 host 小工具
# 仅依赖 libusb-1.0（与 UHD 相同），用 pkg-config 定位。
#
#   make            # 构建所有工具
#   make clean
#
# 若 pkg-config 找不到 libusb-1.0：Arch 装 `libusb`，Ubuntu 装 `libusb-1.0-0-dev`。

CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra
CFLAGS  += $(shell pkg-config --cflags libusb-1.0)
LDLIBS  += $(shell pkg-config --libs libusb-1.0)

PROGS = nb_eeprom

.PHONY: all clean
all: $(PROGS)

$(PROGS): %: %.c
	$(CC) $(CFLAGS) -o $@ $< $(LDLIBS)

clean:
	rm -f $(PROGS)
