# Clock variant: CLK_W19_20260530
# 40MHz TCXO -> FPGA on ball W19 (bank14, 3.3V, MRCC clock-capable).
# Board: NB2026_0530.  (On this board V18 is the LCD_B1 FPC line.)
# Verified: W19 MMCM LOCKED=1 in the clktest diagnostic.
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports CLK_40MHz_FPGA]
