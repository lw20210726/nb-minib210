# Clock variant: CLK_V18_202604xx
# 40MHz TCXO -> FPGA on ball V18 (bank14, 3.3V, SRCC clock-capable).
# Boards: all NB20260 4xx (0402 / 0407 ...).  (On these boards W19 is the LCD_B1 FPC line.)
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports CLK_40MHz_FPGA]
