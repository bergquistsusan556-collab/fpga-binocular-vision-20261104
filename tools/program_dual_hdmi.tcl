set bit [file normalize [lindex $argv 0]]
if {[catch {open_hw_manager} _]} { open_hw }
if {[catch {connect_hw_server -url localhost:3121} err]} {
    puts "HWSERVER_CONNECT_FAIL: $err"
    exit 2
}
refresh_hw_server -quiet
set targets [get_hw_targets -quiet]
puts "TARGET_COUNT=[llength $targets]"
foreach t $targets { puts "TARGET=$t" }
if {[llength $targets] == 0} {
    puts "NO_JTAG_TARGET"
    disconnect_hw_server
    exit 3
}
set t [lindex $targets 0]
catch { set_property PARAM.FREQUENCY 6000000 $t }
if {[catch {open_hw_target $t} err]} {
    puts "OPEN_TARGET_FAIL: $err"
    disconnect_hw_server
    exit 4
}
set dev [lindex [get_hw_devices -quiet] 0]
if {$dev eq ""} {
    puts "NO_HW_DEVICE"
    close_hw_target
    disconnect_hw_server
    exit 5
}
puts "DEVICE=$dev"
puts "PART=[get_property PART $dev]"
set_property PROGRAM.FILE $bit $dev
if {[catch {program_hw_devices $dev} err]} {
    puts "PROGRAM_FAIL: $err"
    close_hw_target
    disconnect_hw_server
    exit 6
}
refresh_hw_device $dev
puts "DONE_PIN=[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]"
close_hw_target
disconnect_hw_server
puts "PROGRAM_OK=$bit"
exit 0

