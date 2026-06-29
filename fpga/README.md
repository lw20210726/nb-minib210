# FPGA

FPGA 工程来自 [lmesserStep/LibreSDRB210](https://github.com/lmesserStep/LibreSDRB210)，
针对本仿制板 **miniB210**（NB2026_0530 / NB20260402 两版）的硬件差异做了适配。

- 器件：Xilinx Artix-7 **xc7a100tfgg484-2**
- 工具：**Vivado 2024.1**
- 工程：`libresdr_b210/libresdr_b210.xpr`
- 约束：`libresdr_b210.srcs/constrs_2/imports/xdc/b210.xdc`（适配改动几乎都在这里）

## 相对 LibreSDRB210 的改动

针对仿制板做了最小化适配，便于日后跟上游对比：

1. **40MHz 主时钟引脚** — 抽成独立的时钟变体约束（见下方「构建」）：
   - **W19** → `clk_w19.xdc`：20260530 板
   - **V18** → `clk_v18.xdc`：所有 202604xx 板（0402/0407…）
   主 `b210.xdc` 不再硬编码时钟脚；由 `build.tcl`（或 GUI 里手动 Enable）二选一启用。
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

### 推荐：批处理 `build.tcl`（多配置一键出 bin）

板子有两个**正交**的差异维度，用一个脚本参数化，免去手点 GUI：

| 维度 | 取值 | 差异 |
|---|---|---|
| **时钟变体** `<clk>` | `w19` / `v18` | 40MHz TCXO 落在哪颗球——**唯一的 PCB 差异**。`w19`=20260530 板；`v18`=所有 202604xx 板（0402/0407…） |
| **器件** `<dev>` | `100t` / `200t` | `100t`=`xc7a100tfgg484-2`；`200t`=`xc7a200tfbg484-2`（484 球封装引脚兼容，约束不变） |

> 为什么按**时钟脚**而不是板号命名？因为 0402/0407 这些 202604xx 板都是 V18，板号会越列越多，
> 但真正决定 bitstream 的只有那根时钟脚。按脚分 profile，将来再出个同为 V18 的新板，直接复用 `v18`。
>
> 注意：板型差异是**引脚**（XDC），不是 RTL，所以**不能用 Verilog `` `ifdef `` ——
> XDC 不经预处理器。脚本通过启用对应的 `clk_w19.xdc` / `clk_v18.xdc` 来切换。

```bash
# 语法： vivado -mode batch -source fpga/build.tcl -tclargs <clk> <dev> [jobs]
vivado -mode batch -source fpga/build.tcl -tclargs w19 100t       # 0530 板 / 100T
vivado -mode batch -source fpga/build.tcl -tclargs v18 200t 12    # 0402/0407 板 / 200T，12 并行
```

脚本会：选 part、启用对应时钟 xdc、（换 part 时）自动重生成 IP、综合→实现→出 bitstream，
输出到 `fpga/build/libresdr_b210_<clk>_<dev>.bit` 和 `.bin`。

> 所有 IP 均为软核（`clk_wiz`/`gen_clks`/`fifo_*`/`vio`），无 MIG/DDR 等器件专属硬 IP，
> 故 100t↔200t 换 part 干净，脚本里 `generate_target` 会自动按新 part 重生成。

### GUI 方式

用 Vivado 2024.1 打开 `libresdr_b210/libresdr_b210.xpr`。时钟脚已从主 `b210.xdc` 抽出到
`clk_w19.xdc` / `clk_v18.xdc`：在 **Sources > Constraints** 里**只启用**与你板子匹配的那一个
（右键 → Enable/Disable File），再综合 → 实现 → 生成 Bitstream。

### 加载到板上

通过 UHD 的 `fpga=` 设备参数：

```bash
uhd_usrp_probe --args="type=b200,fpga=fpga/build/libresdr_b210_w19_100t.bin"
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
