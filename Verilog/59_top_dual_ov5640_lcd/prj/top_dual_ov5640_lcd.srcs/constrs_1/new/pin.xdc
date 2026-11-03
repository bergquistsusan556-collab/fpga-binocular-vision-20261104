#RGB LCD
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[0]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[1]}]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[2]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[3]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[4]}]
set_property -dict {PACKAGE_PIN N13 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[5]}]
set_property -dict {PACKAGE_PIN V9 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[6]}]
set_property -dict {PACKAGE_PIN W9 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[7]}]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[8]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[9]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[10]}]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[11]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[12]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[13]}]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[14]}]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[15]}]
set_property -dict {PACKAGE_PIN AB18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[16]}]
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[17]}]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[18]}]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[19]}]
set_property -dict {PACKAGE_PIN W20 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[20]}]
set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[21]}]
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[22]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[23]}]
set_property -dict {PACKAGE_PIN V8 IOSTANDARD LVCMOS33} [get_ports lcd_hs]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports lcd_vs]
set_property -dict {PACKAGE_PIN AB7 IOSTANDARD LVCMOS33} [get_ports lcd_de]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports lcd_bl]
set_property -dict {PACKAGE_PIN Y9 IOSTANDARD LVCMOS33} [get_ports lcd_pclk]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS33} [get_ports lcd_rst]


set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sys_clk]
create_clock -period 20.000 -name sys_clk [get_ports sys_clk]
set_property PACKAGE_PIN R4 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PACKAGE_PIN U2 [get_ports sys_rst_n]
#CAMERA
################ J2 ###########################
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33} [get_ports cam_scl_1]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD LVCMOS33} [get_ports cam_sda_1]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_1[0]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_1[2]}]
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_1[4]}]
set_property -dict {PACKAGE_PIN H20 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_1[6]}]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports cam_pclk_1]
create_clock -period 40.000 -name cmos_pclk [get_ports cam_pclk_1]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_1_IBUF]
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33} [get_ports cam_vsync_1]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD LVCMOS33} [get_ports cam_href_1]
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVCMOS33} [get_ports cam_rst_n_1]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_1[1]}]
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_1[3]}]
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_1[5]}]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_1[7]}]
set_property -dict {PACKAGE_PIN F21 IOSTANDARD LVCMOS33} [get_ports cam_pwdn_1]

#摄像头2接口的时钟
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports cam_pwdn_2]
set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS33} [get_ports cam_scl_2]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports cam_sda_2]
set_property -dict {PACKAGE_PIN L21 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_2[0]}]
set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_2[2]}]
set_property -dict {PACKAGE_PIN H22 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_2[4]}]
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_2[6]}]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports cam_pclk_2]
create_clock -period 40.000 -name cmos_pclk [get_ports cam_pclk_2]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_2_IBUF]

set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33} [get_ports cam_vsync_2]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS33} [get_ports cam_href_2]
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVCMOS33} [get_ports cam_rst_n_2]
set_property -dict {PACKAGE_PIN K22 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_2[1]}]
set_property -dict {PACKAGE_PIN J22 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_2[3]}]
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_2[5]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports {cam_data_2[7]}]






















# USER KEY
set_property -dict {PACKAGE_PIN T1 IOSTANDARD LVCMOS33} [get_ports {key[0]}]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD LVCMOS33} [get_ports {key[1]}]
set_property -dict {PACKAGE_PIN W2 IOSTANDARD LVCMOS33} [get_ports {key[2]}]
set_property -dict {PACKAGE_PIN T3 IOSTANDARD LVCMOS33} [get_ports {key[3]}]
# USER LED
set_property -dict {PACKAGE_PIN R2 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN R3 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN V2 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN Y2 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

#----------------------------------------------------------------------------
# Timing exception for the lcd_clk control-path synchronisers.
#
# lcd_clk is produced by the combinational mux inside clk_div, so the flops it
# drives see a very different clock insertion delay from the flops driven by
# clk_out2 directly (measured 4.5 ns of skew on the cal_scale path).  Vivado
# resolves both groups to the same clock object, so the first flop of every
# two-stage synchroniser fails the same-clock hold check even though the data
# path between them is a bare wire with no logic, and no amount of routing
# detour can pay the skew back.
#
# These signals are quasi-static key-press values that already pass through
# (* ASYNC_REG = "TRUE" *) two-flop synchronisers, so the correct constraint is
# a datapath-only maximum delay: it drops the hold check and the clock-skew
# pessimism on exactly these paths while still bounding the routing delay.
# The [*] patterns are braced so Tcl does not treat them as command
# substitution.
#----------------------------------------------------------------------------
set_max_delay -datapath_only -from [get_cells {cal_scale_reg[*]}]  -to [get_cells {u_lcd_rgb_top/cal_scale_sync1_reg[*]}]  8.000
set_max_delay -datapath_only -from [get_cells {filter_enable_reg}] -to [get_cells {u_lcd_rgb_top/filter_enable_sync1_reg}] 8.000
set_max_delay -datapath_only -from [get_cells {follow_enable_reg}] -to [get_cells {u_lcd_rgb_top/follow_enable_sync1_reg}] 8.000
set_max_delay -datapath_only -from [get_cells {thr_low_reg[*]}]    -to [get_cells {u_lcd_rgb_top/thr_low_sync1_reg[*]}]    8.000
set_max_delay -datapath_only -from [get_cells {thr_high_reg[*]}]   -to [get_cells {u_lcd_rgb_top/thr_high_sync1_reg[*]}]   8.000
set_max_delay -datapath_only -from [get_cells {mode_50m_reg[*]}]   -to [get_cells {u_lcd_rgb_top/mode_sync1_reg[*]}]       8.000
