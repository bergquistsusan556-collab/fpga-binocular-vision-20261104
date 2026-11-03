set script_dir [file normalize [file dirname [info script]]]
set root [file normalize [file join $script_dir ..]]
set rtl [file join $root "Verilog" "60_top_dual_ov5640_hdmi" "rtl"]
set ip [file join $root "Verilog" "60_top_dual_ov5640_hdmi" "prj" "top_dual_ov5640_hdmi.srcs" "sources_1" "ip"]
set xdc [file join $root "Verilog" "60_top_dual_ov5640_hdmi" "prj" "top_dual_ov5640_hdmi.srcs" "constrs_1" "new" "pin.xdc"]
set out [file join $root "Verilog" "60_top_dual_ov5640_hdmi" "prj" "top_dual_ov5640_hdmi.runs" "impl_1" "top_dual_ov5640_hdmi_alg.bit"]

set rtl_files [lsort [glob -nocomplain [file join $rtl "*.v"]]]
read_verilog $rtl_files
read_ip [list [file join $ip "clk_wiz_0_1" "clk_wiz_0.xci"] [file join $ip "mig_7series_0" "mig_7series_0.xci"] [file join $ip "rd_fifo" "rd_fifo.xci"] [file join $ip "wr_fifo" "wr_fifo.xci"]]
read_xdc $xdc
synth_design -top top_dual_ov5640_hdmi -part xc7a35tfgg484-2 -flatten_hierarchy rebuilt
opt_design
place_design
route_design
write_bitstream -force $out
puts "BUILD_OK=$out"
exit 0
