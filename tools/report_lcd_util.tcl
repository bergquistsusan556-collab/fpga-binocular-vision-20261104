set script_dir [file normalize [file dirname [info script]]]
set root [file normalize [file join $script_dir ..]]
set dir [file join $root "Verilog" "59_top_dual_ov5640_lcd" "prj" "top_dual_ov5640_lcd.runs" "impl_1"]
set dcp [file join $dir "top_dual_ov5640_lcd_alg_ip_routed.dcp"]
set out [file join $dir "top_dual_ov5640_lcd_alg_ip_utilization_hier.rpt"]
open_checkpoint $dcp
report_utilization -hierarchical -hierarchical_depth 5 -file $out
puts "UTIL_HIER_OK=$out"
close_project
exit 0
