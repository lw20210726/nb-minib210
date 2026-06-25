//
// Copyright 2019 Ettus Research, a National Instruments Brand
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
// 新增功能: mb_eeprom 读写厂商命令的实现，详见 mb_eeprom.h

#include "mb_eeprom.h"

#include "cyfx3usb.h"
#include "cyfx3device.h"
#include "cyfx3i2c.h"
#include "cyfx3error.h"

/* 厂商命令码，与主固件 b200_const.h / host 工具一致。 */
#define B200_VREQ_EEPROM_WRITE      (0xBA)
#define B200_VREQ_EEPROM_READ       (0xBB)

/* mb_eeprom 窗口：板身份数据全部落在 EEPROM 0x7F00 起的 46 字节内
   （头 6B + vid/pid/revision/product/name/serial）。引导镜像在 0x0000 起，
   与此窗口不相交——读写命令把地址硬钳制在此窗口内，绝不触碰镜像区。 */
#define MB_EEPROM_ADDR              (0x7F00)
#define MB_EEPROM_LEN               (46)

/* EEPROM 基本读，定义在 usb_boot.c（枚举时读 VID/PID 也用它），此处复用。 */
extern void eeprom_read(uint16_t addr, uint8_t* buffer, uint8_t length);

/* 按需上电/配置 I2C，命令处理完即 DeInit。配置同 usbBoot 读 VID/PID：
   100KHz、寄存器模式。 */
static void eeprom_i2c_on(void)
{
    CyFx3BootI2cInit();
    CyFx3BootI2cConfig_t i2cCfg = {
        .bitRate    = 100000,
        .isDma      = CyFalse,
        .busTimeout = 0xFFFFFFFF,
        .dmaTimeout = 0xFFFF};
    CyFx3BootI2cSetConfig(&i2cCfg);
}

/* EEPROM 基本写。整块 46B 落在 24LC256 单个 64B 页内（0x7F00..0x7F3F），单页写
   即可，无需分页循环；写后轮询 ACK 等待 EEPROM 内部写周期完成。成功返回 0。 */
static int eeprom_write(uint16_t addr, uint8_t* buffer, uint8_t length)
{
    CyFx3BootI2cPreamble_t preamble;
    preamble.length    = 3;
    preamble.buffer[0] = 0xA0;
    preamble.buffer[1] = addr >> 8;
    preamble.buffer[2] = addr & 0xFF;
    preamble.ctrlMask  = 0x0000;
    if (CyFx3BootI2cTransmitBytes(&preamble, buffer, length, 0) != CY_FX3_BOOT_SUCCESS) {
        return -1;
    }

    /* 轮询从机 ACK，等待内部写周期结束。 */
    preamble.length    = 1;
    preamble.buffer[0] = 0xA0;
    preamble.ctrlMask  = 0x0000;
    if (CyFx3BootI2cWaitForAck(&preamble, 200) != CY_FX3_BOOT_SUCCESS) {
        return -1;
    }
    return 0;
}

/* [addr, addr+len) 是否完全落在 mb_eeprom 窗口内（len 须非 0）。安全钳制的唯一
   判定点：用 32 位中间量算 end，避免 addr+len 在 16 位上回绕导致误判通过。 */
static int mb_eeprom_range_ok(uint16_t addr, uint16_t len)
{
    const uint32_t end = (uint32_t)addr + len;
    return (len != 0)
        && (addr >= MB_EEPROM_ADDR)
        && (end <= (uint32_t)MB_EEPROM_ADDR + MB_EEPROM_LEN);
}

int mb_eeprom_vendor_cmd(uint8_t bReq, int dir, uint16_t addr, uint16_t len, uint8_t* buf)
{
    CyFx3BootErrorCode_t status;

    /* mb_eeprom 读 (0xBB)：仅允许窗口内，越界 stall、不下发 I2C。 */
    if (dir && bReq == B200_VREQ_EEPROM_READ) {
        if (!mb_eeprom_range_ok(addr, len)) {
            CyFx3BootUsbStall(0, CyTrue, CyFalse);
            return 1;
        }

        /* 钳制通过后 len <= MB_EEPROM_LEN(46)，收窄到 uint8_t 安全。 */
        eeprom_i2c_on();
        eeprom_read(addr, buf, (uint8_t)len);
        CyFx3BootI2cDeInit();

        CyFx3BootUsbAckSetup();
        status = CyFx3BootUsbDmaXferData(0x80, (uint32_t)buf, len, CY_FX3_BOOT_WAIT_FOREVER);
        if (status != CY_FX3_BOOT_SUCCESS) {
            CyFx3BootUsbStall(0, CyTrue, CyFalse);
        }
        return 1;
    }

    /* mb_eeprom 写 (0xBA)：地址硬钳制在窗口内，绝不触碰引导镜像区。
       先校验范围，越界直接 stall（连主机数据都不接收）。 */
    if (!dir && bReq == B200_VREQ_EEPROM_WRITE) {
        if (!mb_eeprom_range_ok(addr, len)) {
            CyFx3BootUsbStall(0, CyTrue, CyFalse);
            return 1;
        }

        /* 接收主机要写入的字节到缓冲区。 */
        CyFx3BootUsbAckSetup();
        status = CyFx3BootUsbDmaXferData(0x00, (uint32_t)buf, len, CY_FX3_BOOT_WAIT_FOREVER);
        if (status != CY_FX3_BOOT_SUCCESS) {
            CyFx3BootUsbStall(0, CyTrue, CyFalse);
            return 1;
        }

        eeprom_i2c_on();
        status = eeprom_write(addr, buf, (uint8_t)len);
        CyFx3BootI2cDeInit();
        if (status != 0) {
            CyFx3BootUsbStall(0, CyTrue, CyFalse);
        }
        return 1;
    }

    return 0;  /* 不是 mb_eeprom 命令，交回 vendorCmdHandler */
}
