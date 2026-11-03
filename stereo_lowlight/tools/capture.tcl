set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build diagnostic]
open_hw
connect_hw_server -url localhost:3121
set target [lindex [get_hw_targets] 0]
set_property PARAM.FREQUENCY 6000000 $target
open_hw_target $target
set dev [lindex [get_hw_devices] 0]
set_property PROBES.FILE [file join $out diagnostic.ltx] $dev
if {[llength $argv]>0 && [lindex $argv 0] eq "program"} {
 set_property PROGRAM.FILE [file join $out diagnostic.bit] $dev
 program_hw_devices $dev
}
refresh_hw_device $dev
puts "DONE_PIN=[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]"
set ila [lindex [get_hw_ilas -of_objects $dev] 0]
if {$ila eq ""} {error "Diagnostic ILA not detected"}
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
