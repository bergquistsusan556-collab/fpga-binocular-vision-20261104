create_debug_core u_diagnostic ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_diagnostic]
set_property C_TRIGIN_EN false [get_debug_cores u_diagnostic]
set_property C_TRIGOUT_EN false [get_debug_cores u_diagnostic]
set diagnostic_width 480
if {[file tail $out] eq "video_fusion"} {set diagnostic_width 256}
set_property port_width $diagnostic_width [get_debug_ports u_diagnostic/probe0]
connect_debug_port u_diagnostic/clk [get_nets clk_50m]
set probes {}
for {set i 0} {$i<$diagnostic_width} {incr i} {lappend probes [get_nets [format {diagnostic_bus[%d]} $i]]}
connect_debug_port u_diagnostic/probe0 $probes
implement_debug_core
opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
report_drc -file [file join $out drc.rpt]
report_clocks -file [file join $out clocks.rpt]
report_timing -max_paths 20 -file [file join $out worst_paths.rpt]
report_cdc -file [file join $out cdc.rpt]
write_checkpoint -force [file join $out routed.dcp]
write_debug_probes -force [file join $out fusion.ltx]
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
puts "FINAL_WNS=$wns FINAL_WHS=$whs"
if {$wns<0||$whs<0} {error "Timing failed: do not program this candidate"}
write_bitstream -force [file join $out fusion.bit]
set signoff [open [file join $out timing_pass.txt] w]
puts $signoff "WNS=$wns WHS=$whs"
close $signoff
puts "BUILD_OK=$out"
