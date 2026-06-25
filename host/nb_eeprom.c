/*
 * nb_eeprom —— 读写 mini-B210 (NB Tech) 的 FX3 主板 EEPROM 身份块 (mb_eeprom)。
 *
 * 通过运行中固件/引导程序提供的厂商命令（EEPROM_READ/WRITE 控制传输）读写
 * 0x7F00 处的 mb_eeprom 块（vendor/product id、板名、序列号等），使 UHD 能识别设备。
 *
 * 本板是 B210 仿制板，并非官方 b2xx 系列，故工具名用 nb_ 前缀。
 * 仅依赖 libusb-1.0（UHD 本身就需要）。
 *
 * 子命令：
 *   read   （默认）读出并打印 mb_eeprom
 *   write  先读后写（read-modify-write）：保留已有字段，只改命令行指定的；
 *          若 EEPROM 尚无有效块(无 magic)，未指定的字段取默认值
 *   reset  把整个 mb_eeprom 区域清成 0xFF
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include <getopt.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <libusb-1.0/libusb.h>

/* 默认在总线上查找设备用的 VID/PID（FX3 跑本固件/引导后枚举的 id）。 */
#define DEV_VID 0x2500
#define DEV_PID 0x0020

/* mb_eeprom 各字段默认值（仅 write 在"无 magic"时对未指定字段使用）。
   vid/pid/product 是 UHD 识别本板的依据，默认值即正确值，一般无需改动。 */
#define DEFAULT_VID       0x2500
#define DEFAULT_PID       0x0020
#define DEFAULT_REVISION  0x0000
#define DEFAULT_PRODUCT   0x0002   /* product code：B210 */
#define DEFAULT_NAME      "NB Tech miniB210"

/* mb_eeprom 头固定值（小端写入）。 */
#define MAGIC      0xB200
#define EE_REV     0x0001
#define EE_COMPAT  0x0001

/* FX3 固件/引导的厂商命令（见固件 b200_const.h / bootloader mb_eeprom.c）。 */
#define VRT_VENDOR_OUT 0x40
#define VRT_VENDOR_IN  0xC0
#define B200_VREQ_EEPROM_WRITE 0xBA
#define B200_VREQ_EEPROM_READ  0xBB

/* mb_eeprom 块 @0x7F00，整块 46B。字段在块内的偏移： */
#define BLOCK_ADDR  0x7F00
#define BLOCK_LEN   46
#define OFF_MAGIC      0
#define OFF_EE_REV     2
#define OFF_EE_COMPAT  4
#define OFF_VID        6
#define OFF_PID        8
#define OFF_REVISION   10
#define OFF_PRODUCT    12
#define OFF_NAME       14
#define NAME_LEN       23
#define OFF_SERIAL     37   /* OFF_NAME + NAME_LEN */
#define SERIAL_LEN     9

#define USB_TIMEOUT_MS 1000

/* write 子命令的解析结果：每个字段一个"是否指定"标志 + 值。 */
struct fields {
    int vid_set;  uint16_t vid;
    int pid_set;  uint16_t pid;
    int rev_set;  uint16_t rev;
    int prod_set; uint16_t prod;
    const char *name;    /* NULL = 未指定 */
    const char *serial;  /* NULL = 未指定 */
};

static void put_le16(uint8_t *p, uint16_t v)
{
    p[0] = (uint8_t)(v & 0xFF);
    p[1] = (uint8_t)((v >> 8) & 0xFF);
}

static uint16_t get_le16(const uint8_t *p)
{
    return (uint16_t)(p[0] | (p[1] << 8));
}

/* 把 ASCII 字符串放进定长字段，余下补 0；超长则报错返回 -1。 */
static int fixed_ascii(uint8_t *dst, size_t len, const char *s, const char *field)
{
    size_t n = strlen(s);
    if (n > len) {
        fprintf(stderr, "error: %s \"%s\" exceeds %zu bytes\n", field, s, len);
        return -1;
    }
    memset(dst, 0, len);
    memcpy(dst, s, n);
    return 0;
}

/* 随机生成默认序列号，格式 NBM-XXXX，XXXX 为大写字母/数字组合。
   总长 8 字节，落在 SERIAL_LEN(9) 内；buf 需 >= 9 字节。 */
static void gen_serial(char *buf)
{
    static const char charset[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    srand((unsigned)(time(NULL) ^ (getpid() << 16)));
    memcpy(buf, "NBM-", 4);
    for (int i = 0; i < 4; i++)
        buf[4 + i] = charset[rand() % (int)(sizeof(charset) - 1)];
    buf[8] = '\0';
}

/* mb_eeprom 是否已初始化（含正确 magic）。 */
static int has_magic(const uint8_t *b)
{
    return get_le16(b + OFF_MAGIC) == MAGIC;
}

/* read-modify-write 组装待写块：
   - 已有 magic：以现块为基底，仅覆盖命令行指定的字段；
   - 无 magic：以默认值为基底（serial 随机生成），再覆盖指定的字段。
   头(magic/rev/compat)总是写成规范值。 */
static int build_write_block(const uint8_t *cur, const struct fields *f, uint8_t *out)
{
    uint16_t vid, pid, rev, prod;
    uint8_t name[NAME_LEN], serial[SERIAL_LEN];

    if (has_magic(cur)) {
        vid  = get_le16(cur + OFF_VID);
        pid  = get_le16(cur + OFF_PID);
        rev  = get_le16(cur + OFF_REVISION);
        prod = get_le16(cur + OFF_PRODUCT);
        memcpy(name,   cur + OFF_NAME,   NAME_LEN);
        memcpy(serial, cur + OFF_SERIAL, SERIAL_LEN);
    } else {
        char s[SERIAL_LEN + 1];
        vid  = DEFAULT_VID;
        pid  = DEFAULT_PID;
        rev  = DEFAULT_REVISION;
        prod = DEFAULT_PRODUCT;
        memset(name, 0, NAME_LEN);
        memcpy(name, DEFAULT_NAME, strlen(DEFAULT_NAME)); /* DEFAULT_NAME 已知 <= NAME_LEN */
        gen_serial(s);
        memset(serial, 0, SERIAL_LEN);
        memcpy(serial, s, strlen(s));
    }

    /* 覆盖命令行显式指定的字段。 */
    if (f->vid_set)  vid  = f->vid;
    if (f->pid_set)  pid  = f->pid;
    if (f->rev_set)  rev  = f->rev;
    if (f->prod_set) prod = f->prod;
    if (f->name && fixed_ascii(name, NAME_LEN, f->name, "name") < 0)
        return -1;
    if (f->serial && fixed_ascii(serial, SERIAL_LEN, f->serial, "serial") < 0)
        return -1;

    put_le16(out + OFF_MAGIC,     MAGIC);
    put_le16(out + OFF_EE_REV,    EE_REV);
    put_le16(out + OFF_EE_COMPAT, EE_COMPAT);
    put_le16(out + OFF_VID,       vid);
    put_le16(out + OFF_PID,       pid);
    put_le16(out + OFF_REVISION,  rev);
    put_le16(out + OFF_PRODUCT,   prod);
    memcpy(out + OFF_NAME,   name,   NAME_LEN);
    memcpy(out + OFF_SERIAL, serial, SERIAL_LEN);
    return 0;
}

/* 把 mb_eeprom 块解码成多行易读输出；无 magic 时只打印一行未初始化提示。
   title 作首行标题（未初始化时作前缀）。 */
static void print_mb_eeprom(const char *title, const uint8_t *b)
{
    char name[NAME_LEN + 1] = {0};
    char serial[SERIAL_LEN + 1] = {0};

    if (!has_magic(b)) {
        printf("%s: uninitialized (no magic)\n", title);
        return;
    }
    memcpy(name, b + OFF_NAME, NAME_LEN);
    memcpy(serial, b + OFF_SERIAL, SERIAL_LEN);
    printf("%s\n", title);
    printf("  magic      0x%04x  (eeprom_rev %u, eeprom_compat %u)\n",
           get_le16(b + OFF_MAGIC), get_le16(b + OFF_EE_REV), get_le16(b + OFF_EE_COMPAT));
    printf("  vid:pid    0x%04x:0x%04x\n", get_le16(b + OFF_VID), get_le16(b + OFF_PID));
    printf("  revision   0x%04x\n", get_le16(b + OFF_REVISION));
    printf("  product    0x%04x\n", get_le16(b + OFF_PRODUCT));
    printf("  name       \"%s\"\n", name);
    printf("  serial     \"%s\"\n", serial);
}

static int read_eeprom(libusb_device_handle *h, uint16_t addr, uint8_t *buf, uint16_t len)
{
    int rc = libusb_control_transfer(h, VRT_VENDOR_IN, B200_VREQ_EEPROM_READ,
                                     0, addr, buf, len, USB_TIMEOUT_MS);
    if (rc != len) {
        fprintf(stderr, "error: EEPROM read 0x%04x failed: %s\n",
                addr, rc < 0 ? libusb_strerror(rc) : "short read");
        return -1;
    }
    return 0;
}

static int write_eeprom(libusb_device_handle *h, uint16_t addr, const uint8_t *buf, uint16_t len)
{
    int rc = libusb_control_transfer(h, VRT_VENDOR_OUT, B200_VREQ_EEPROM_WRITE,
                                     0, addr, (uint8_t *)buf, len, USB_TIMEOUT_MS);
    if (rc != len) {
        fprintf(stderr, "error: EEPROM write 0x%04x failed: %s\n",
                addr, rc < 0 ? libusb_strerror(rc) : "short write");
        return -1;
    }
    return 0;
}

/* 写入整块、回读并逐字节校验；成功返回 0。after 收回读结果。 */
static int commit(libusb_device_handle *h, const uint8_t *block, uint8_t *after)
{
    if (write_eeprom(h, BLOCK_ADDR, block, BLOCK_LEN) < 0)
        return -1;
    if (read_eeprom(h, BLOCK_ADDR, after, BLOCK_LEN) < 0)
        return -1;
    if (memcmp(after, block, BLOCK_LEN) != 0) {
        fprintf(stderr, "error: post-write verification failed\n");
        return -1;
    }
    return 0;
}

static void usage(const char *argv0)
{
    fprintf(stderr,
        "usage: %s [read|write|reset] [options]\n"
        "\n"
        "commands:\n"
        "  read             (default) read and print the mb_eeprom block\n"
        "  write            read-modify-write: keep existing fields, change only the\n"
        "                   ones you pass; if no valid block exists yet, unspecified\n"
        "                   fields get defaults\n"
        "  reset            erase the whole mb_eeprom region to 0xff\n"
        "\n"
        "write field options (all optional):\n"
        "  --name <str>     board name, max 23 bytes (default \"%s\")\n"
        "  --serial <str>   serial, max 9 bytes (default: random NBM-XXXX)\n"
        "  --vid <0xNNNN>   vendor_id  field (default 0x%04x)\n"
        "  --pid <0xNNNN>   product_id field (default 0x%04x)\n"
        "  --revision <0xNNNN> board revision (default 0x%04x)\n"
        "  --product <0xNNNN>  product code   (default 0x%04x; UHD uses it to tell B200/B210)\n"
        "\n"
        "global:\n"
        "  --device <VID:PID>  USB device to open (default %04x:%04x)\n"
        "  --help           show this help\n",
        argv0, DEFAULT_NAME, DEFAULT_VID, DEFAULT_PID, DEFAULT_REVISION, DEFAULT_PRODUCT,
        DEV_VID, DEV_PID);
}

int main(int argc, char **argv)
{
    struct fields f = {0};
    long dev_vid = DEV_VID;
    long dev_pid = DEV_PID;

    /* 第一个非选项参数是子命令；缺省为 read。 */
    const char *cmd = "read";
    if (argc >= 2 && argv[1][0] != '-') {
        cmd = argv[1];
        optind = 2;
    }
    int is_read  = !strcmp(cmd, "read");
    int is_write = !strcmp(cmd, "write");
    int is_reset = !strcmp(cmd, "reset");
    if (!is_read && !is_write && !is_reset) {
        fprintf(stderr, "error: unknown command \"%s\"\n", cmd);
        usage(argv[0]);
        return 2;
    }

    enum { OPT_REVISION = 256, OPT_PRODUCT, OPT_DEVICE };
    static struct option opts[] = {
        {"name",     required_argument, 0, 'n'},
        {"serial",   required_argument, 0, 's'},
        {"vid",      required_argument, 0, 'V'},
        {"pid",      required_argument, 0, 'P'},
        {"revision", required_argument, 0, OPT_REVISION},
        {"product",  required_argument, 0, OPT_PRODUCT},
        {"device",   required_argument, 0, OPT_DEVICE},
        {"help",     no_argument,       0, 'h'},
        {0, 0, 0, 0},
    };
    int c;
    while ((c = getopt_long(argc, argv, "n:s:V:P:h", opts, NULL)) != -1) {
        switch (c) {
        case 'n': f.name = optarg; break;
        case 's': f.serial = optarg; break;
        case 'V': f.vid = (uint16_t)strtol(optarg, NULL, 0); f.vid_set = 1; break;
        case 'P': f.pid = (uint16_t)strtol(optarg, NULL, 0); f.pid_set = 1; break;
        case OPT_REVISION: f.rev = (uint16_t)strtol(optarg, NULL, 0); f.rev_set = 1; break;
        case OPT_PRODUCT:  f.prod = (uint16_t)strtol(optarg, NULL, 0); f.prod_set = 1; break;
        case OPT_DEVICE:
            if (sscanf(optarg, "%lx:%lx", &dev_vid, &dev_pid) != 2) {
                fprintf(stderr, "error: --device wants VID:PID, e.g. 2500:0020\n");
                return 2;
            }
            break;
        case 'h': usage(argv[0]); return 0;
        default:  usage(argv[0]); return 2;
        }
    }

    libusb_context *ctx = NULL;
    libusb_device_handle *h = NULL;
    int ret = 1;
    int claimed = 0;

    int rc = libusb_init(&ctx);
    if (rc != 0) {
        fprintf(stderr, "error: libusb_init failed: %s\n", libusb_strerror(rc));
        return 1;
    }

    h = libusb_open_device_with_vid_pid(ctx, (uint16_t)dev_vid, (uint16_t)dev_pid);
    if (!h) {
        fprintf(stderr, "error: cannot open USB device %04lx:%04lx (not connected / no permission / firmware not running?)\n",
                dev_vid, dev_pid);
        goto out;
    }
    libusb_set_auto_detach_kernel_driver(h, 1); /* 尽力而为，忽略返回值 */
    rc = libusb_claim_interface(h, 0);
    if (rc != 0) {
        fprintf(stderr, "error: claim interface 0 failed: %s\n", libusb_strerror(rc));
        goto out;
    }
    claimed = 1;

    uint8_t before[BLOCK_LEN];
    if (read_eeprom(h, BLOCK_ADDR, before, BLOCK_LEN) < 0)
        goto out;

    /* read：打印当前状态即可。 */
    if (is_read) {
        print_mb_eeprom("mb_eeprom @ 0x7f00", before);
        ret = 0;
        goto out;
    }

    uint8_t block[BLOCK_LEN];
    uint8_t after[BLOCK_LEN];

    /* reset：整块刷 0xFF（抹掉 magic，回到未编程状态）。 */
    if (is_reset) {
        memset(block, 0xFF, BLOCK_LEN);
        if (commit(h, block, after) < 0)
            goto out;
        printf("mb_eeprom erased to 0xff and verified.\n");
        ret = 0;
        goto out;
    }

    /* write：read-modify-write。 */
    int was_init = has_magic(before);
    if (build_write_block(before, &f, block) < 0) {
        ret = 2;
        goto out;
    }
    if (commit(h, block, after) < 0)
        goto out;
    print_mb_eeprom(was_init ? "mb_eeprom written (kept existing fields)"
                             : "mb_eeprom written (initialized with defaults)",
                    after);
    printf("written and verified.\n");
    ret = 0;

out:
    if (claimed)
        libusb_release_interface(h, 0);
    if (h)
        libusb_close(h);
    if (ctx)
        libusb_exit(ctx);
    return ret;
}
