proc glob_recursive {dir pattern} {
 set result {}
 foreach item [glob -nocomplain -directory $dir *] {
  if {[file isdirectory $item]} {
   set result [concat $result [glob_recursive $item $pattern]]
  } elseif {[string match $pattern [file tail $item]]} {lappend result $item}
 }
 return $result
}
set root [file normalize [file join [file dirname [info script]] ..]]
set ip [file join $root ip]
set out [file join $root build front_fit_20261103]
file mkdir $out
file delete -force [file join $out timing_pass.txt]
create_project -in_memory -part xc7a35tfgg484-2
set_property target_language Verilog [current_project]
file mkdir [file join $out generated_ip]
if {[file exists [file join $out generated_ip stereo_control stereo_control.xci]]} {
 read_ip [file join $out generated_ip stereo_control stereo_control.xci]
} else {
 create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name stereo_control -dir [file join $out generated_ip]
}
set_property -dict [list CONFIG.C_NUM_PROBE_IN {0} CONFIG.C_NUM_PROBE_OUT {1} CONFIG.C_PROBE_OUT0_WIDTH {16} CONFIG.C_PROBE_OUT0_INIT_VAL {0x00DB}] [get_ips stereo_control]
generate_target all [get_ips stereo_control]
synth_ip [get_ips stereo_control]
read_ip [list [file join $ip rd_fifo rd_fifo.xci] [file join $ip wr_fifo wr_fifo.xci]]
foreach name {rd_fifo wr_fifo} {
 generate_target all [get_ips $name]
 synth_ip [get_ips $name]
}
set skip {stereo_census.v depth_roi.v video_alg_top.v stereo_depth.v stereo_red_ruler.v red_ycbcr_morph.v lcd_disply.v}
foreach f [glob [file join $root rtl *.v]] {
 if {[lsearch -exact $skip [file tail $f]]<0} {read_verilog [list $f]}
}
foreach f [glob [file join $root variants front_fit_20261103 rtl *.v]] {read_verilog [list $f]}
read_verilog [list [file join $ip clk_wiz_0_1 clk_wiz_0.v] [file join $ip clk_wiz_0_1 clk_wiz_0_clk_wiz.v]]
set mig [file join $ip mig_7series_0 mig_7series_0 user_design]
set files [lsearch -all -inline -not -regexp [glob_recursive [file join $mig rtl] *.v] {_sim\.v$}]
read_verilog $files
read_xdc [list [file join $root constraints pin.xdc]]
read_xdc [list [file join $mig constraints mig_7series_0.xdc]]
synth_design -top top_dual_ov5640_lcd -part xc7a35tfgg484-2 -flatten_hierarchy rebuilt
source [file join $root constraints processing.tcl]
report_utilization -file [file join $out synthesis_utilization.rpt]
write_checkpoint -force [file join $out synthesized.dcp]
source [file join $root tools implement_front_fit.tcl]
