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
set out [file join $root build diagnostic]
file mkdir $out
create_project -in_memory -part xc7a35tfgg484-2
set_property target_language Verilog [current_project]
read_ip [list [file join $ip rd_fifo rd_fifo.xci] [file join $ip wr_fifo wr_fifo.xci]]
foreach name {rd_fifo wr_fifo} {
 generate_target all [get_ips $name]
 synth_ip [get_ips $name]
}
set skip {stream_features.v luma_histogram.v lowlight_fixed.v stereo_census.v depth_frame.v depth_roi.v video_alg_top.v stereo_depth.v stereo_red_ruler.v red_ycbcr_morph.v distance_osd.v lcd_disply.v}
foreach f [glob [file join $root rtl *.v]] {
 if {[lsearch -exact $skip [file tail $f]]<0} {read_verilog [list $f]}
}
read_verilog [list [file join $ip clk_wiz_0_1 clk_wiz_0.v] [file join $ip clk_wiz_0_1 clk_wiz_0_clk_wiz.v]]
set mig [file join $ip mig_7series_0 mig_7series_0 user_design]
set files [lsearch -all -inline -not -regexp [glob_recursive [file join $mig rtl] *.v] {_sim\.v$}]
read_verilog $files
read_xdc [list [file join $root constraints pin.xdc]]
read_xdc [list [file join $mig constraints mig_7series_0.xdc]]
synth_design -top top_dual_ov5640_lcd -part xc7a35tfgg484-2 -flatten_hierarchy rebuilt
create_debug_core u_diagnostic ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_diagnostic]
set_property C_TRIGIN_EN false [get_debug_cores u_diagnostic]
set_property C_TRIGOUT_EN false [get_debug_cores u_diagnostic]
set_property port_width 256 [get_debug_ports u_diagnostic/probe0]
connect_debug_port u_diagnostic/clk [get_nets clk_50m]
set probes {}
for {set i 0} {$i<256} {incr i} {lappend probes [get_nets [format {diagnostic_bus[%d]} $i]]}
connect_debug_port u_diagnostic/probe0 $probes
implement_debug_core
opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
report_drc -file [file join $out drc.rpt]
write_checkpoint -force [file join $out routed.dcp]
write_debug_probes -force [file join $out diagnostic.ltx]
write_bitstream -force [file join $out diagnostic.bit]
puts "BUILD_OK=$out"
