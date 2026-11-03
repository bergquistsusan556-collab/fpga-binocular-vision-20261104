# Temporary calibration acquisition; JTAG RAM programming only, no Flash access.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build calibration_capture]
foreach arg $argv {if {[string match "-*" $arg]} {error "Options must precede -tclargs"}}
set action [lindex $argv 0]
if {$action ni {program capture}} {error "Expected program or capture"}
open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets]!=1} {error "Expected one JTAG target"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 1000000 $target
open_hw_target $target
set devs [get_hw_devices -quiet]
if {[llength $devs]!=1} {error "Expected one FPGA"}
set dev [lindex $devs 0]
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
if {[llength $ila]!=1||[llength $vio]!=1} {error "Expected one ILA/VIO"}
set ctrl [get_hw_probes -of_objects $vio]
set probe [get_hw_probes -of_objects $ila -filter {NAME =~ *diagnostic_bus*}]
if {[llength $ctrl]!=1||[llength $probe]!=1} {error "Wrong diagnostic probes"}
proc control {ctrl value} {
 set_property OUTPUT_VALUE [format %04x $value] $ctrl
 commit_hw_vio $ctrl
 after 250
}
if {$action eq "program"} {
 control $ctrl 0
 after 3000
}
set pose [lindex $argv 1]
if {$pose eq ""} {set pose pose}
if {![regexp {^[A-Za-z0-9_]+$} $pose]} {error "Bad pose name"}
set dir [file join $out frames [clock format [clock seconds] -format %Y%m%d_%H%M%S]_$pose]
file mkdir $dir
set manifest [open [file join $dir capture_metadata.txt] w]
puts $manifest "LCD raster snapshot; independent sensor exposures; static board required"
puts $manifest "Each view 400x480 native. Full-field sampled every 2 pixels, or native crop x=100,y=120,size=200x240."
close $manifest
set_property CONTROL.TRIGGER_POSITION 0 $ila
foreach {name value} {fullfield 1 center_crop 20} {
 set image_dir [file join $dir $name];file mkdir $image_dir
 control $ctrl 0
 control $ctrl [expr {16384|$value}]
 for {set pass 0} {$pass<2} {incr pass} {
  for {set i 0} {$i<12} {incr i} {
   set address [expr {$i*8192}]
   set ab "";for {set b 16} {$b>=0} {incr b -1} {append ab [expr {($address>>$b)&1}]}
   # header=11, complete=1, epoch=xxxx, address[16:0], luminance=xxxxxxxx.
   set_property TRIGGER_COMPARE_VALUE "eq32'b111xxxx${ab}xxxxxxxx" $probe
   run_hw_ila $ila
   wait_on_hw_ila -timeout 10 $ila
   set data [upload_hw_ila_data $ila]
   write_hw_ila_data -force -csv_file [file join $image_dir pass_${pass}_capture_${i}.csv] $data
  }
  puts "CAPTURE_PASS_OK=$name/$pass"
 }
 control $ctrl 0
}
puts "CALIBRATION_FRAME_DIRECTORY=$dir"
close_hw_target
disconnect_hw_server
close_hw
puts CALIBRATION_CAPTURE_HW_OK
