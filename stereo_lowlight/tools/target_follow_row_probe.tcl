# Temporary geometry diagnostic; always restore the original VIO setting.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build target_follow_20261103]
if {[llength $argv]!=1||![regexp {^[A-Za-z0-9_]+$} [lindex $argv 0]]} {error "Expected fresh GROUP"}
set folder [file join $out hardware [lindex $argv 0]]
if {[file exists $folder]} {error "Refusing overwrite"}
open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets]!=1} {error "Wrong target count"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 1000000 $target
open_hw_target $target
set devices [get_hw_devices -quiet]
if {[llength $devices]!=1} {error "Wrong device count"}
set dev [lindex $devices 0]
if {![string match xc7a35t* [get_property PART $dev]]} {error "Wrong device"}
set_property PROBES.FILE [file join $out fusion.ltx] $dev
refresh_hw_device $dev
set ila [get_hw_ilas -of_objects $dev]
set ctrl [get_hw_probes -of_objects [get_hw_vios -of_objects $dev]]
if {[llength $ila]!=1||[llength $ctrl]!=1} {error "Wrong diagnostics"}
scan [get_property OUTPUT_VALUE $ctrl] %x initial
file mkdir $folder
set failure [catch {
 foreach dy {24 25 26 27 28 29 30 31} {
  set value [expr {($initial&65504)|$dy}]
  set_property OUTPUT_VALUE [format %04x $value] $ctrl
  commit_hw_vio $ctrl
  after 300
  set dir [file join $folder row_$dy];file mkdir $dir
  set meta [open [file join $dir capture_meta.txt] w]
  puts $meta "temporary_row=$dy; original_control=$initial"
  puts $meta "host_time=[clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]"
  close $meta
  for {set i 0} {$i<3} {incr i} {
   after 100
   run_hw_ila -trigger_now $ila
   wait_on_hw_ila $ila
   write_hw_ila_data -force -csv_file [file join $dir capture_$i.csv] [upload_hw_ila_data $ila]
  }
  puts "ROW_READ_OK=$dy"
 }
} problem]
set_property OUTPUT_VALUE [format %04x $initial] $ctrl
commit_hw_vio $ctrl
puts "RESTORED_CONTROL=[get_property OUTPUT_VALUE $ctrl]"
close_hw_target
disconnect_hw_server
close_hw
if {$failure} {error $problem}
puts "ROW_PROBE_OK=$folder"
