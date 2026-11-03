# Three short captures per frontal distance; optional explicit candidate programming.
set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength $argv] ni {2 3}} {error "Usage: front_range_hw.tcl video|front|fit SESSION_GROUP_NAME ?program?"}
lassign $argv variant group action
if {$variant ni {video front fit observer} || ![regexp {^[a-zA-Z0-9_]+$} $group]} {error "Invalid variant or group"}
if {$action ne "" && ($action ne "program" || $variant ni {front fit observer})} {error "Invalid action"}
set build video_fusion
if {$variant eq "front"} {set build front_range_20261103}
if {$variant eq "fit"} {set build front_fit_20261103}
if {$variant eq "observer"} {set build front_fit_observer_20261103}
set out [file join $root build $build]
set folder [file join $root calibration frontal_20261103 $group]
if {[file exists $folder]} {error "Group exists; choose a new name to preserve prior samples"}
open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets] != 1} {error "Expected one JTAG target"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 1000000 $target
open_hw_target $target
set devices [get_hw_devices -quiet]
if {[llength $devices] != 1} {error "Expected one FPGA"}
set dev [lindex $devices 0]
if {![string match "xc7a35t*" [get_property PART $dev]]} {error "Wrong FPGA"}
set_property PROBES.FILE [file join $out fusion.ltx] $dev
if {$action eq "program"} {
 if {![file exists [file join $out timing_pass.txt]]} {error "Missing timing signoff"}
 set_property PROGRAM.FILE [file join $out fusion.bit] $dev
 program_hw_devices $dev
}
refresh_hw_device $dev
puts "DONE_PIN=[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]"
if {[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev] != 1} {error "FPGA not programmed"}
set ila [get_hw_ilas -of_objects $dev]
set vio [get_hw_vios -of_objects $dev]
if {[llength $ila] != 1 || [llength $vio] != 1} {error "Wrong diagnostics"}
set ctrl [get_hw_probes -of_objects $vio]
if {[llength $ctrl] != 1} {error "Wrong control probe"}
file mkdir $folder
set meta [open [file join $folder capture_meta.txt] w]
puts $meta "build=$build"
puts $meta "vio_control=[get_property OUTPUT_VALUE $ctrl]"
puts $meta "host_time=[clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]"
puts $meta "bitstream=[file join $out fusion.bit]"
puts $meta "probe_layout=compact256_roi64"
set allow_zero 0
if {$variant in {fit observer}} {set allow_zero 1}
puts $meta "allow_zero_disparity=$allow_zero"
if {$action eq "program"} {
 puts $meta "post_refresh_settle_delay_ms=10000"
} else {
 puts $meta "post_refresh_settle_delay_ms=0; program_time_not_known_to_this_capture"
}
close $meta
if {$action eq "program"} {after 10000}
for {set i 0} {$i < 3} {incr i} {
 after 350
 run_hw_ila -trigger_now $ila
 wait_on_hw_ila $ila
 set data [upload_hw_ila_data $ila]
 write_hw_ila_data -force -csv_file [file join $folder capture_$i.csv] $data
}
close_hw_target
disconnect_hw_server
close_hw
puts "FRONTAL_RANGE_CAPTURE_OK=$folder"
