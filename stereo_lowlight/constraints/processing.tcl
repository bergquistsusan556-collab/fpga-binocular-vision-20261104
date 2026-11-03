# I2C dri_clk toggles every 25 cycles of clk_50m: 50-cycle full period.
# Define generated clocks explicitly; they are clocks, not false paths.
set master_pin [get_pins -leaf -of_objects [get_nets clk_50m] -filter {DIRECTION == OUT}]
if {[llength $master_pin]!=1} {error "Cannot locate 50 MHz clock source: $master_pin"}
create_generated_clock -name lcd_25m -source $master_pin -divide_by 2 [get_pins u_lcd_rgb_top/divider/divide2_reg/Q]
foreach camera {1 2} {
 set p [get_pins -hier -filter "NAME =~ *u_ov5640_dri_$camera/*u_i2c_dri*/dri_clk_reg/Q"]
 if {[llength $p]!=1} {error "Cannot locate camera $camera I2C clock: $p"}
 create_generated_clock -name sccb_$camera -source $master_pin -divide_by 50 $p
}
# Source-synchronous camera timing budget, provisional until board/pin delay
# characterization. OV5640 launches on falling PCLK; capture on rising PCLK.
# 2..8 ns includes module and cable skew, checked at the measured 48 MHz PCLK.
foreach camera {1 2} {
 set ports [get_ports [list cam_href_$camera cam_vsync_$camera cam_data_${camera}\[*\]]]
 set_input_delay -clock cmos_pclk_$camera -clock_fall -min 2.0 $ports
 set_input_delay -clock cmos_pclk_$camera -clock_fall -max 8.0 $ports
}
# Each module has its own oscillator/PLL; equal nominal frequencies do not
# establish a phase relationship. Camera data crosses via asynchronous FIFOs;
# frame/config controls cross via synchronizers. Do not time their first stage
# as synchronous to the unrelated system clock.
set_clock_groups -asynchronous -group [get_clocks cmos_pclk_1] -group [get_clocks cmos_pclk_2] -group [get_clocks -include_generated_clocks sys_clk]
# Fabric input registers avoid the fixed IOB ZHOLD delay, which consumed the
# half-cycle setup budget on camera 1 at 48 MHz. Verify both setup and hold.
set_property IOB FALSE [get_ports {cam_data_1[*] cam_data_2[*]}]
set_property IOB FALSE [get_cells -hier -filter {NAME =~ *u_cmos_capture_data/cmos_data_t_reg* && REF_NAME =~ FD*}]
