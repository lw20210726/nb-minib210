# FPGA

FPGA 工程来自 [lmesserStep/LibreSDRB210](https://github.com/lmesserStep/LibreSDRB210)，
针对本仿制板 **miniB210**（NB2026_0530 / NB20260402 两版）的硬件差异做了适配。

- 器件：Xilinx Artix-7 **xc7a100tfgg484-2**
- 工具：**Vivado 2024.1**
- 工程：`libresdr_b210/libresdr_b210.xpr`
- 约束：`libresdr_b210.srcs/constrs_2/imports/xdc/b210.xdc`（适配改动几乎都在这里）

## 相对 LibreSDRB210 的改动

针对仿制板做了最小化适配，便于日后跟上游对比：

1. **40MHz 主时钟引脚** — `b210.xdc` 里合并了两版板的变体：
   - `0530` 板（NB2026_0530）：时钟在 **W19**（默认，active）
   - `0402` 板（NB20260402）：时钟在 **V18**（注释备选；换板时取消注释 V18 行、注释掉 W19 行）
   > 注：另一颗球在对应板上是 `LCD_B1`（FPC 预留线，FPGA 侧无逻辑）。

2. **AD9361 数据口 = CMOS**（非 LVDS）。与 UHD b200 驱动写入的寄存器配置一致
   （`0x010=0xc8 / 0x011=0x00 / 0x012=0x02` = 双口全双工 DDR CMOS）。
   `DATA_CLK_P` 走 SRCC 时钟脚 L3。

3. **修复 radio_clk 死** — 未约束输出曾被工具自动放到 AD9361 的 `_N` 时钟/帧脚上，
   经板上 ~100Ω 端接电阻把对面的 `_P` 实信号钳住，导致 radio_clk 不动、寄存器环回超时。
   用 `PROHIBIT` 锁死这些球，禁止工具占用：
   - `K3`=DATA_CLK_N、`G3`=FB_CLK_N、`B2`=RX_FRAME_N、`J1`=TX_FRAME_N
   - 另禁 `AB3`(AD9361 TEST)、`W2`(CLK_OUT)、`F4`(NC)

4. **未用端口泊到 NC** — 仿制板简化掉了 RF 开关、`fp_gpio`、参考时钟分配等 B210 特性，
   对应顶层端口（36 个）统一分配到封装上**真正空脚（NC）的球**，IOSTANDARD `LVCMOS18`、
   输入/inout 加 `PULLDOWN`。这样满足 `NSTD-1 / UCIO-1` 这两条 DRC，
   **无需 waiver 即可正常 `write_bitstream` 出 `.bin`**。

5. **UART** — `FPGA_RXD0=AA13 / FPGA_TXD0=Y14`，bank 13（3.3V），承载 FX3 UART 控制台。

6. **时钟跨域 false_path** — 补齐 `rx_clk_mimo_bufr ↔ clk_out2_100_bus_gen_clks`
   两个方向的 `set_false_path`（二者经 FIFO 异步），消除虚假时序违例，WNS ≥ 0。

7. **精简** — 删除了原工程的 LED 支持、EEPROM DNA/AES 加密校验、顶层注释掉的 GPS 死代码。

## 构建

用 Vivado 2024.1 打开 `libresdr_b210/libresdr_b210.xpr`，综合 → 实现 → 生成 Bitstream。
得到 `.bit` 后转出 `.bin`（或在生成时一并产出），加载方式见下。

加载到板上（通过 UHD 的 `fpga=` 设备参数）：

```bash
uhd_usrp_probe --args="type=b200,fpga=/tmp/libresdr_b210.bin"
```

## 验收状态

| 项目 | 结果 |
|---|---|
| `uhd_usrp_probe` 寄存器环回 | ✅ 通过 |
| `benchmark_rate` 单向到 61.44 Msps | ✅ 干净（0 序列错误） |
| MIMO（双通道） | ✅ 干净 |
| 30.72 Msps 全双工 2 小时稳定性 | ✅ 链路级错误全 0 |

> 数据**正确性**（bit 是否翻）需用射频环回另测——见 [`../testkit/`](../testkit/)。
> `benchmark_rate` 只数样本流，不校验样本值。

板级验收测试套件见 [`../testkit/README.md`](../testkit/README.md)。
