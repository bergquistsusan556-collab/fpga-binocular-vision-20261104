set script_dir [file normalize [file dirname [info script]]]
cd $script_dir
set build_dir build
file mkdir $build_dir

set build_init 0
if {[llength $argv] > 0} {
    set build_init [lindex $argv 0]
}

read_verilog rtl/key_debounce.v
read_verilog rtl/seg_display.v
read_verilog rtl/i2c_dri.v
read_verilog rtl/rtc_clock_ctrl.v
read_verilog rtl/top_seg_clock.v
read_xdc     constraints/top_seg_clock.xdc

if {$build_init} {
    set init_secs [clock seconds]
    set init_secs [expr {$init_secs + 42}]
    set init_time [clock format $init_secs -format "%y_%m_%d_%H_%M_%S"]
    puts "FORCE_INIT=1 TIME_INIT=48'h$init_time"
    synth_design -top top_seg_clock -part xc7a35tfgg484-2 \
        -generic FORCE_INIT=1 -generic TIME_INIT=48'h$init_time
    set bit_name clock_seg_init.bit
} else {
    synth_design -top top_seg_clock -part xc7a35tfgg484-2
    set bit_name clock_seg.bit
}

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE Yes [current_design]

opt_design
place_design
phys_opt_design
route_design

write_bitstream -force [file join $build_dir $bit_name]
puts "BITSTREAM=[file join $build_dir $bit_name]"
puts "BUILD_OK"


