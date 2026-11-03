set root {C:/Users/Li Jiahao/Documents/ChatGPT/fpga/camera_capture_off}
set prj [file normalize {C:/Users/Li Jiahao/Documents/ChatGPT/fpga/camera_capture_off/prj}]
set src [file normalize {C:/Users/Li Jiahao/Documents/ChatGPT/fpga/camera_capture_off/rtl/camera_capture_off.v}]
set xdc [file normalize {C:/Users/Li Jiahao/Documents/ChatGPT/fpga/camera_capture_off/prj/camera_capture_off.xdc}]
puts "ROOT=<$root>"
puts "PRJ=<$prj>"
puts "SRC=<$src>"
puts "XDC=<$xdc>"
create_project -force camera_capture_off $prj -part xc7a35tfgg484-2
add_files -norecurse [list $src]
add_files -fileset constrs_1 -norecurse [list $xdc]
set_property top camera_capture_off [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "SYNTH_FAILED"
    exit 1
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    puts "IMPL_FAILED"
    exit 2
}
puts "CAMERA_OFF_BIT=[file normalize [file join $prj camera_capture_off.runs impl_1 camera_capture_off.bit]]"
exit 0