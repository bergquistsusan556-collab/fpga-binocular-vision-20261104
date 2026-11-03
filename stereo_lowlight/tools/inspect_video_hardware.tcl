open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
puts "TARGET_COUNT=[llength $targets]"
if {[llength $targets]==1} {
 set target [lindex $targets 0]
 set_property PARAM.FREQUENCY 1000000 $target
 open_hw_target $target
 foreach dev [get_hw_devices -quiet] {puts "CONNECTED_PART=[get_property PART $dev]"}
}
close_hw
