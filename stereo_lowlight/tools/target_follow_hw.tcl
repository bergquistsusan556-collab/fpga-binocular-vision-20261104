# JTAG RAM only. Preserve all prior frontal calibration captures and bitstreams.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build target_follow_20261103]
if {[llength $argv] ni {2 3}} {error "Usage: target_follow_hw.tcl program|capture GROUP ?COUNT?"}
lassign $argv action group count
if {$count eq ""} {set count 3}
if {![string is integer -strict $count]||$count<3||$count>60} {error "Count must be 3..60"}
if {$action ni {program capture}||![regexp {^[A-Za-z0-9_]+$} $group]} {error "Invalid action/group"}
set folder [file join $out hardware $group]
if {[file exists $folder]} {error "Refuse overwriting hardware evidence"}
open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets]!=1} {error "Expected one JTAG target"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 1000000 $target
open_hw_target $target
set devices [get_hw_devices -quiet]
if {[llength $devices]!=1} {error "Expected one FPGA"}
set dev [lindex $devices 0]
if {![string match "xc7a35t*" [get_property PART $dev]]} {error "Wrong FPGA"}
set_property PROBES.FILE [file join $out fusion.ltx] $dev
if {$action eq "program"} {
 if {![file exists [file join $out timing_pass.txt]]} {error "No timing signoff"}
 set_property PROGRAM.FILE [file join $out fusion.bit] $dev
 program_hw_devices $dev
}
refresh_hw_device $dev
puts "DONE_PIN=[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]"
if {[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]!=1} {error "DONE low"}
set ila [get_hw_ilas -of_objects $dev]
set vio [get_hw_vios -of_objects $dev]
if {[llength $ila]!=1||[llength $vio]!=1} {error "Wrong diagnostics"}
set ctrl [get_hw_probes -of_objects $vio]
if {[llength $ctrl]!=1} {error "Wrong control"}
file mkdir $folder
set meta [open [file join $folder capture_meta.txt] w]
puts $meta "build=target_follow_20261103"
puts $meta "host_time=[clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]"
puts $meta "vio_control=[get_property OUTPUT_VALUE $ctrl]"
puts $meta "probe_layout=tracking256+raw_observer32; depth=1024"
puts $meta "sample_count=$count"
puts $meta "programmed_now=[expr {$action eq {program}}]; jtag_ram_only=1"
close $meta
if {$action eq "program"} {after 10000}
for {set i 0} {$i<$count} {incr i} {
 after 400
 run_hw_ila -trigger_now $ila
 wait_on_hw_ila $ila
 set data [upload_hw_ila_data $ila]
 write_hw_ila_data -force -csv_file [file join $folder capture_$i.csv] $data
}
close_hw_target
disconnect_hw_server
close_hw
puts "TARGET_FOLLOW_CAPTURE_OK=$folder"
