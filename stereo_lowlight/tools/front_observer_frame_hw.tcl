# Read the existing luminance observer without changing processing parameters.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build front_fit_observer_20261103]
if {[llength $argv] != 1 || ![regexp {^[A-Za-z0-9_]+$} [lindex $argv 0]]} {error "Expected a new capture group"}
set folder [file join $root calibration frontal_20261103 [lindex $argv 0]]
if {[file exists $folder]} {error "Refuse overwrite of original observations"}
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
refresh_hw_device $dev
if {[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev] != 1} {error "DONE low"}
set ila [get_hw_ilas -of_objects $dev]
set vio [get_hw_vios -of_objects $dev]
if {[llength $ila] != 1 || [llength $vio] != 1} {error "Wrong diagnostics"}
set ctrl [get_hw_probes -of_objects $vio]
set high {}
foreach probe [get_hw_probes -of_objects $ila] {
 if {[regexp {479:384} [get_property NAME $probe]]} {lappend high $probe}
}
if {[llength $ctrl] != 1 || [llength $high] != 1} {error "Missing observer probe"}
scan [get_property OUTPUT_VALUE $ctrl] %x initial_control
set base [expr {$initial_control & 255}]
file mkdir $folder
set meta [open [file join $folder frame_meta.txt] w]
puts $meta "build=front_fit_observer_20261103"
puts $meta "host_time=[clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]"
puts $meta "base_control=$base"
puts $meta "same_lcd_frame=1; independent_camera_exposures=1"
close $meta
set failure [catch {
 set_property OUTPUT_VALUE [format %04x $base] $ctrl
 commit_hw_vio $ctrl
 after 200
 set_property OUTPUT_VALUE [format %04x [expr {$base | 16384}]] $ctrl
 commit_hw_vio $ctrl
 after 250
 set_property CONTROL.TRIGGER_POSITION 0 $ila
 for {set pass 0} {$pass < 2} {incr pass} {
  for {set i 0} {$i < 6} {incr i} {
   set address [expr {$i * 1024}]
   set ab ""
   for {set b 12} {$b >= 0} {incr b -1} {append ab [expr {($address >> $b) & 1}]}
   set_property TRIGGER_COMPARE_VALUE "eq96'b110${ab}00000110[string repeat x 72]" $high
   run_hw_ila $ila
   wait_on_hw_ila -timeout 10 $ila
   set data [upload_hw_ila_data $ila]
   write_hw_ila_data -force -csv_file [file join $folder pass_${pass}_capture_${i}.csv] $data
  }
 }
} problem]
# Restore the exact control value even if reading times out.
set_property OUTPUT_VALUE [format %04x $initial_control] $ctrl
commit_hw_vio $ctrl
puts "RESTORED_CONTROL=[get_property OUTPUT_VALUE $ctrl]"
close_hw_target
disconnect_hw_server
close_hw
if {$failure} {error $problem}
puts "FRONT_OBSERVER_FRAME_OK=$folder"
