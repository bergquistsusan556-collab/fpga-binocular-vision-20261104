set script_dir [file normalize [file dirname [info script]]]
set root [file normalize [file join $script_dir ..]]
set prj [file join $root "Verilog" "60_top_dual_ov5640_hdmi" "prj" "top_dual_ov5640_hdmi.xpr"]
set rtl [file join $root "Verilog" "60_top_dual_ov5640_hdmi" "rtl"]
set bit_file [file join $root "Verilog" "60_top_dual_ov5640_hdmi" "prj" "top_dual_ov5640_hdmi.runs" "impl_1" "top_dual_ov5640_hdmi_alg.bit"]

open_project $prj
add_files -norecurse -fileset sources_1 [list [file join $rtl "video_alg_top.v"] [file join $rtl "key_debounce.v"]]
set_property top top_dual_ov5640_hdmi [current_fileset]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "SYNTH_FAIL"
    exit 2
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "IMPL_FAIL"
    exit 3
}

set impl_bit [file join $root "Verilog" "60_top_dual_ov5640_hdmi" "prj" "top_dual_ov5640_hdmi.runs" "impl_1" "top_dual_ov5640_hdmi.bit"]
if {![file exists $impl_bit]} {
    puts "BIT_NOT_FOUND=$impl_bit"
    exit 4
}
file copy -force $impl_bit $bit_file
puts "BUILD_OK=$bit_file"
exit 0
