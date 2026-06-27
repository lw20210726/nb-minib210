## ROUTE-B GPIF-only test constraints for new board (NB20260402_miniB210)
## Auto-generated from pstxnet.dat. Only FX3<->FPGA + clock + reset constrained.
## AD9361/RF pins intentionally left unconstrained (auto-placed) for this GPIF bring-up test.

# --- main clock: 40MHz TCXO -> FPGA W19 (bank14, 3.3V, clock-capable MRCC) ---
#     CORRECTED per new netlist NB2026_0530 (old wrong schematic said V18; V18 is actually LCD_B1).
#     Verified alive: W19 MMCM LOCKED=1 in the clktest diagnostic.
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports CLK_40MHz_FPGA]
# (input clock constrained by gen_clks IP in-context xdc)

# --- FPGA_RST_N -> G15: this net is DANGLING/floating on the real board (no driver/pull).
#     Add an internal pull-up so G15 reads high => reset_global = ~G15 = 0 (deasserted).
#     Power-on reset is then handled by the MMCM 'locked' signal (clocks_ready gating). ---
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS18 PULLTYPE PULLUP} [get_ports FPGA_RST_N]

# --- GPIF clock / interrupt ---
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS18 SLEW FAST} [get_ports IFCLK]
set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS18} [get_ports FX3_EXTINT]

# --- GPIF data bus D[31:0] (bank15/16, 1.8V) ---
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[0]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[1]}]
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[2]}]
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[3]}]
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[4]}]
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[5]}]
set_property -dict {PACKAGE_PIN B22 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[6]}]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[7]}]
set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[8]}]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[9]}]
set_property -dict {PACKAGE_PIN A21 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[10]}]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[11]}]
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[12]}]
set_property -dict {PACKAGE_PIN A19 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[13]}]
set_property -dict {PACKAGE_PIN D22 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[14]}]
set_property -dict {PACKAGE_PIN F21 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[15]}]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[16]}]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[17]}]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[18]}]
set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[19]}]
set_property -dict {PACKAGE_PIN C18 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[20]}]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[21]}]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[22]}]
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[23]}]
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[24]}]
set_property -dict {PACKAGE_PIN B13 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[25]}]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[26]}]
set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[27]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[28]}]
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[29]}]
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[30]}]
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports {GPIF_D[31]}]

# --- GPIF control lines ---
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports GPIF_CTL0]
set_property -dict {PACKAGE_PIN K22 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports GPIF_CTL1]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports GPIF_CTL2]
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports GPIF_CTL3]
set_property PACKAGE_PIN M22 [get_ports GPIF_CTL4]
set_property IOSTANDARD LVCMOS18 [get_ports GPIF_CTL4]
set_property PACKAGE_PIN J22 [get_ports GPIF_CTL5]
set_property IOSTANDARD LVCMOS18 [get_ports GPIF_CTL5]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports GPIF_CTL7]
set_property -dict {PACKAGE_PIN H22 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports GPIF_CTL11]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS18 SLEW SLOW} [get_ports GPIF_CTL12]

# --- bitstream + DRC waivers: let unconstrained AD9361/RF ports auto-place for this test build ---
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list u_gen_clocks_main/inst/clk_out2_100_bus]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 1 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list bus_rst]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list clocks_ready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list ctrl_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list ctrl_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list gpif_rst]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list resp_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list resp_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list rx_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list rx_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list tx_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list tx_tvalid]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list u_gen_clocks_main/inst/clkfbout_buf_gen_clks]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 1 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list locked]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 1 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list reset_global]]
create_debug_core u_ila_2 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_2]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_2]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_2]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_2]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_2]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_2]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_2]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_2]
set_property port_width 1 [get_debug_ports u_ila_2/clk]
connect_debug_port u_ila_2/clk [get_nets [list u_libresdr_b210_io/radio_clk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe0]
set_property port_width 1 [get_debug_ports u_ila_2/probe0]
connect_debug_port u_ila_2/probe0 [get_nets [list radio_rst]]
create_debug_core u_ila_3 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_3]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_3]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_3]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_3]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_3]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_3]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_3]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_3]
set_property port_width 1 [get_debug_ports u_ila_3/clk]
connect_debug_port u_ila_3/clk [get_nets [list u_gen_clocks_main/inst/clk_out3_200_ref_pll]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe0]
set_property port_width 1 [get_debug_ports u_ila_3/probe0]
connect_debug_port u_ila_3/probe0 [get_nets [list ref_pll_rst]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ref_pll_clk]

# ============================================================================
# AD9361 SPI + control + reset  (bank 34, 1.8V -> LVCMOS18)
# Mapped from new netlist NB2026_0530 (AD9361 U10 <-> FPGA U7).
# Step 1 of AD9361 bring-up: enough to reset the chip and read its Device ID over SPI.
# (Data bus CAT_P0_D/CAT_P1_D + clocks/frames are CMOS and added in a later step.)
# ============================================================================
set_property -dict {PACKAGE_PIN Y1  IOSTANDARD LVCMOS18} [get_ports CAT_SPI_CLK]   ;# AD9361 J5
set_property -dict {PACKAGE_PIN Y2  IOSTANDARD LVCMOS18} [get_ports CAT_SPI_DI]    ;# AD9361 J4 (MOSI)
set_property -dict {PACKAGE_PIN W1  IOSTANDARD LVCMOS18} [get_ports CAT_SPI_DO]    ;# AD9361 L6 (MISO)
set_property -dict {PACKAGE_PIN V2  IOSTANDARD LVCMOS18} [get_ports CAT_SPI_EN]    ;# AD9361 K6
set_property -dict {PACKAGE_PIN Y3  IOSTANDARD LVCMOS18} [get_ports CAT_RESETn]    ;# AD9361 K5
set_property -dict {PACKAGE_PIN AB5 IOSTANDARD LVCMOS18} [get_ports CAT_EN]        ;# AD9361 G6
set_property -dict {PACKAGE_PIN AB2 IOSTANDARD LVCMOS18} [get_ports CAT_EN_AGC]    ;# AD9361 G5
set_property -dict {PACKAGE_PIN AB1 IOSTANDARD LVCMOS18} [get_ports CAT_SYNC]      ;# AD9361 H5
set_property -dict {PACKAGE_PIN AA1 IOSTANDARD LVCMOS18} [get_ports CAT_TXnRX]     ;# AD9361 H4

# ============================================================================
# AD9361 data interface (CMOS Dual Port Full Duplex) -- bank 35, 1.8V LVCMOS18
# CMOS P0_D reuses the AD9361 LVDS "TX_D" balls; P1_D reuses the "RX_D" balls
# (AD9361 dual-function pins). In this design CAT_P0_D=RX, CAT_P1_D=TX.
# Bit order (P0_D[2k+1]=Dk_P, P0_D[2k]=Dk_N) is best-guess pending UG-570;
# a wrong bit order only scrambles sample data, it does NOT block init/probe.
# ============================================================================
# RX sample clock from AD9361 (L3 = SRCC clock-capable) -> radio_clk
set_property -dict {PACKAGE_PIN L3 IOSTANDARD LVCMOS18} [get_ports CAT_DCLK_P]
create_clock -period 12.500 [get_ports CAT_DCLK_P]
# TX feedback clock to AD9361
set_property -dict {PACKAGE_PIN H3 IOSTANDARD LVCMOS18} [get_ports CAT_FBCLK_P]
# frame signals
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS18} [get_ports CAT_RX_FR_P]
set_property -dict {PACKAGE_PIN K1 IOSTANDARD LVCMOS18} [get_ports CAT_TX_FR_P]
# RX data bus CAT_P0_D[11:0]  (on AD9361 TX_D balls)
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[0]}]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[1]}]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[2]}]
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[3]}]
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[4]}]
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[5]}]
set_property -dict {PACKAGE_PIN D1 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[6]}]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[7]}]
set_property -dict {PACKAGE_PIN A1 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[8]}]
set_property -dict {PACKAGE_PIN B1 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[9]}]
set_property -dict {PACKAGE_PIN D2 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[10]}]
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS18} [get_ports {CAT_P0_D[11]}]
# TX data bus CAT_P1_D[11:0]  (on AD9361 RX_D balls)
set_property -dict {PACKAGE_PIN M2 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[0]}]
set_property -dict {PACKAGE_PIN M3 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[1]}]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[2]}]
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[3]}]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[4]}]
set_property -dict {PACKAGE_PIN M1 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[5]}]
set_property -dict {PACKAGE_PIN P1 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[6]}]
set_property -dict {PACKAGE_PIN R1 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[7]}]
set_property -dict {PACKAGE_PIN N2 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[8]}]
set_property -dict {PACKAGE_PIN P2 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[9]}]
set_property -dict {PACKAGE_PIN P4 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[10]}]
set_property -dict {PACKAGE_PIN P5 IOSTANDARD LVCMOS18} [get_ports {CAT_P1_D[11]}]
# async CDC: AD9361 sample clock <-> MMCM-derived clocks
set_false_path -from [get_clocks CAT_DCLK_P] -to [get_clocks -of_objects [get_pins u_gen_clocks_main/inst/mmcm_adv_inst/CLKOUT1]]
set_false_path -from [get_clocks CAT_DCLK_P] -to [get_clocks -of_objects [get_pins u_libresdr_b210_io/BUFR_inst/O]]
set_false_path -from [get_clocks -of_objects [get_pins u_gen_clocks_main/inst/mmcm_adv_inst/CLKOUT1]] -to [get_clocks CAT_DCLK_P]
set_false_path -from [get_clocks -of_objects [get_pins u_gen_clocks_main/inst/mmcm_adv_inst/CLKOUT2]] -to [get_clocks CAT_DCLK_P]
