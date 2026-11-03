set bit [file normalize [lindex $argv 0]]
if {![file exists $bit]} {error "Missing bitstream: $bit"}
open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets] != 1} {error "Expected one JTAG target, found [llength $targets]"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 6000000 $target
open_hw_target $target
set devices [get_hw_devices -quiet]
if {[llength $devices] != 1} {error "Expected one FPGA"}
set dev [lindex $devices 0]
set part [get_property PART $dev]
puts "CONNECTED_PART=$part"
if {![string match "xc7a35t*" $part]} {error "Unexpected device: $part"}
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
refresh_hw_device $dev
set done [get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]
puts "DONE_PIN=$done"
if {$done != 1} {error "FPGA did not assert DONE"}
close_hw_target
disconnect_hw_server
close_hw
puts "PROGRAM_OK=$bit"
