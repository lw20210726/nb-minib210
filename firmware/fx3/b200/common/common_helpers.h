//
// Copyright 2019 Ettus Research, a National Instruments Brand
//
// SPDX-License-Identifier: GPL-3.0-or-later
//

#ifndef _COMMON_HELPERS_H
#define _COMMON_HELPERS_H

#include "cyu3types.h"

typedef void (*eeprom_read_t)(uint16_t, uint8_t*, uint8_t);

/* mini-B210 差异：公开此函数的声明（原仅在 common_helpers.c 内定义）。
   bootloader 用它判断 mb_eeprom 是否已编程，从而决定枚举用的 VID/PID 回退。
   返回非 0 表示 EEPROM 布局可识别且 magic/compat 校验通过。 */
int eeprom_is_readable(eeprom_read_t read_fn);

/* Read the EEPROM layout revision number from EEPROM using the function
   specified */
int get_rev(eeprom_read_t read_fn);

/* Read the vendor ID from EEPROM using the function specified*/
uint16_t get_vid(eeprom_read_t read_fn);

/* Read the product ID from EEPROM using the function specified*/
uint16_t get_pid(eeprom_read_t read_fn);

/* Read the vendor ID from EEPROM using the function specified
   Buffer must be at least length 20 */
const uint8_t* get_serial_string_descriptor(eeprom_read_t read_fn);

/* Return the string descriptor based on the VID given */
const uint8_t* get_manufacturer_string_descriptor(uint16_t vid);

/* Return the string descriptor based on the PID given */
const uint8_t* get_product_string_descriptor(uint16_t pid);

#endif /* _COMMON_HELPERS_H */
