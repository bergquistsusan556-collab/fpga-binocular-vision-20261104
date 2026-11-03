set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build fusion]
if {[llength $argv]>0 && [string match "observer*" [lindex $argv 0]]} {
 set out [file join $root build distance_observer]
}
set watching [expr {[llength $argv]>0 && [lindex $argv 0] eq "watch"}]
set capture_dir $out
set captures 3
set interval 1500
if {$watching} {set capture_dir [file join $out watch]; file mkdir $capture_dir; set captures 12; set interval 5000}
if {[llength $argv]>0 && [lindex $argv 0] eq "distance_issue"} {
 set capture_dir [file join $out distance_issue]; file mkdir $capture_dir
 set captures 5; set interval 2000
}
open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets]!=1} {error "Expected exactly one JTAG target"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 6000000 $target
open_hw_target $target
set devices [get_hw_devices -quiet]
if {[llength $devices]!=1} {error "Expected exactly one FPGA"}
set dev [lindex $devices 0]
if {![string match "xc7a35t*" [get_property PART $dev]]} {error "Wrong FPGA part"}
set_property PROBES.FILE [file join $out fusion.ltx] $dev
if {[llength $argv]>0 && [lindex $argv 0] in {program observer_program}} {
 if {![file exists [file join $out timing_pass.txt]]} {error "Missing timing signoff"}
 set_property PROGRAM.FILE [file join $out fusion.bit] $dev
 program_hw_devices $dev
}
refresh_hw_device $dev
set done [get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]
puts "DONE_PIN=$done"
if {$done!=1} {error "FPGA DONE not asserted"}
set ila [lindex [get_hw_ilas -of_objects $dev] 0]
if {$ila eq ""} {error "Diagnostic ILA not detected"}
if {[llength $argv]>0 && [lindex $argv 0] eq "observer_thumbnail"} {
 set capture_dir [file join $out thumbnail];file mkdir $capture_dir
 set probe [get_hw_probes -of_objects $ila -filter {NAME =~ *diagnostic_bus*}]
 if {[llength $probe]!=1} {error "Expected one thumbnail diagnostic probe"}
 set_property CONTROL.TRIGGER_POSITION 0 $ila
 for {set i 0} {$i<6} {incr i} {
  set address [expr {$i*1024}];set binary ""
  for {set b 12} {$b>=0} {incr b -1} {append binary [expr {($address>>$b)&1}]}
  set_property TRIGGER_COMPARE_VALUE "eq480'b101${binary}[string repeat x 464]" $probe
  run_hw_ila $ila
  wait_on_hw_ila $ila
  set data [upload_hw_ila_data $ila]
  write_hw_ila_data -force -csv_file [file join $capture_dir capture_$i.csv] $data
 }
 set captures 0
}
for {set i 0} {$i<$captures} {incr i} {
 after $interval
 run_hw_ila -trigger_now $ila
 wait_on_hw_ila $ila
 set data [upload_hw_ila_data $ila]
 write_hw_ila_data -force -csv_file [file join $capture_dir capture_$i.csv] $data
}
close_hw_target
disconnect_hw_server
close_hw
puts CAPTURE_OK
