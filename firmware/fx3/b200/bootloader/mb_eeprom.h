//
// Copyright 2019 Ettus Research, a National Instruments Brand
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
// mini-B210 差异：bootloader 阶段对主板 EEPROM 身份块(0x7F00, 46B，即 UHD
// 所称 mb_eeprom)的受钳制读写厂商命令(0xBB 读 / 0xBA 写)。方便只烧了引导
// 程序的裸板直接写板参数，不依赖主固件；地址硬钳制在 mb_eeprom 窗口内，
// 不影响 0xA0 等原有刷机流程。

#ifndef _MB_EEPROM_H
#define _MB_EEPROM_H

#include "cyu3types.h"

/* 处理 mb_eeprom 读写厂商命令。命中并已自行完成 USB 应答/stall 时返回非 0；
   不是本模块的命令返回 0，交回 vendorCmdHandler 继续后续处理。
     bReq : bRequest（0xBB 读 / 0xBA 写）
     dir  : bmReqType & 0x80（非 0 = 设备到主机）
     addr : wIndex（EEPROM 字节地址）
     len  : wLength
     buf  : EP0 数据缓冲区（读写都用它中转） */
int mb_eeprom_vendor_cmd(uint8_t bReq, int dir, uint16_t addr, uint16_t len, uint8_t* buf);

#endif /* _MB_EEPROM_H */
