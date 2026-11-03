set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build brightness]
open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets]!=1} {error "Expected one JTAG target"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 6000000 $target
open_hw_target $target
set devices [get_hw_devices -quiet]
if {[llength $devices]!=1} {error "Expected one FPGA"}
set dev [lindex $devices 0]
if {![string match "xc7a35t*" [get_property PART $dev]]} {error "Wrong FPGA part"}
set_property PROBES.FILE [file join $out brightness.ltx] $dev
if {[llength $argv]>0 && [lindex $argv 0] eq "program"} {
 if {![file exists [file join $out timing_pass.txt]]} {error "Missing timing signoff"}
 set_property PROGRAM.FILE [file join $out brightness.bit] $dev
 program_hw_devices $dev
}
refresh_hw_device $dev
set done [get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]
puts "DONE_PIN=$done"
if {$done!=1} {error "DONE not asserted"}
set ila [lindex [get_hw_ilas -of_objects $dev] 0]
if {$ila eq ""} {error "Diagnostic ILA missing"}
for {set i 0} {$i<3} {incr i} {
 after 1500
 run_hw_ila -trigger_now $ila
 wait_on_hw_ila $ila
 set data [upload_hw_ila_data $ila]
 write_hw_ila_data -force -csv_file [file join $out capture_$i.csv] $data
}
close_hw_target
disconnect_hw_server
close_hw
puts CAPTURE_OK
