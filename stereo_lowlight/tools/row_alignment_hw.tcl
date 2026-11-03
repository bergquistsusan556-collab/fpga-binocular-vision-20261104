# JTAG-only control/capture. Does not write configuration Flash.
set root [file normalize [file join [file dirname [info script]] ..]]
foreach arg $argv {
 if {[string match "-*" $arg]} {error "Vivado options must precede -tclargs; refusing ambiguous hardware arguments"}
}
set out [file join $root build row_alignment]
if {[lindex $argv end] eq "final"} {set out [file join $root build row_alignment_final]}
if {[lindex $argv end] eq "snapshot"} {set out [file join $root build roi_snapshot]}
if {[lindex $argv end] eq "robust"} {set out [file join $root build robust_match]}
if {[lindex $argv end] eq "video"} {set out [file join $root build video_fusion]}
puts "HARDWARE_BUILD=$out"
set action [lindex $argv 0]
if {$action ni {program capture phases vertical roi frame paired sweep set}} {error "Unknown hardware action"}
open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets]!=1} {error "Expected one JTAG target"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 1000000 $target
open_hw_target $target
set devs [get_hw_devices -quiet]
if {[llength $devs]!=1} {error "Expected one device"}
set dev [lindex $devs 0]
if {![string match "xc7a35t*" [get_property PART $dev]]} {error "Wrong FPGA"}
set_property PROBES.FILE [file join $out fusion.ltx] $dev
if {$action eq "program"} {
 if {![file exists [file join $out timing_pass.txt]]} {error "Missing timing signoff"}
 set_property PROGRAM.FILE [file join $out fusion.bit] $dev
 program_hw_devices $dev
}
refresh_hw_device $dev
puts "DONE_PIN=[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]"
if {[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]!=1} {error "DONE low"}
set ila [get_hw_ilas -of_objects $dev]
set vio [get_hw_vios -of_objects $dev]
if {[llength $ila]!=1||[llength $vio]!=1} {error "Expected one ILA and one VIO"}
set ctrl [get_hw_probes -of_objects $vio]
set probe [get_hw_probes -of_objects $ila -filter {NAME =~ *diagnostic_bus*}]
if {[llength $ctrl]!=1||[llength $probe]!=1} {error "Wrong diagnostic probes"}
proc set_control {ctrl value} {
 if {$value<0||$value>32767} {error "Control outside supported range"}
 set_property OUTPUT_VALUE [format %04x $value] $ctrl
 commit_hw_vio $ctrl
 after 160
 puts "CONTROL=[get_property OUTPUT_VALUE $ctrl]"
}
proc capture_now {ila path} {
 run_hw_ila -trigger_now $ila
 wait_on_hw_ila $ila
 set data [upload_hw_ila_data $ila]
 write_hw_ila_data -force -csv_file $path $data
}
if {$action in {program capture}} {
 set dir [file join $out captures];file mkdir $dir
 for {set i 0} {$i<3} {incr i} {after 250;capture_now $ila [file join $dir capture_$i.csv]}
}
if {$action eq "set"} {
 set_control $ctrl [lindex $argv 1]
 set dir [file join $out selected];file mkdir $dir
 for {set i 0} {$i<5} {incr i} {after 150;capture_now $ila [file join $dir capture_$i.csv]}
}
if {$action in {frame paired}} {
 if {[lindex $argv end] ni {snapshot robust}} {error "Single-frame mode requires snapshot-enabled build"}
 scan [get_property OUTPUT_VALUE $ctrl] %x current_control
 set base [expr {$current_control&255}]
 set dir [file join $out frozen_frames [clock format [clock seconds] -format %Y%m%d_%H%M%S]]
 file mkdir $dir
 set_control $ctrl $base
 if {$action eq "paired"} {
  set metrics_dir [file join $dir metrics];file mkdir $metrics_dir
  for {set i 0} {$i<5} {incr i} {after 150;capture_now $ila [file join $metrics_dir capture_$i.csv]}
 }
 set_control $ctrl [expr {$base|16384}]
 set_property CONTROL.TRIGGER_POSITION 0 $ila
 for {set pass 0} {$pass<2} {incr pass} {
  for {set i 0} {$i<6} {incr i} {
   set address [expr {$i*1024}];set ab ""
   for {set b 12} {$b>=0} {incr b -1} {append ab [expr {($address>>$b)&1}]}
   set_property TRIGGER_COMPARE_VALUE "eq480'b110${ab}00000110[string repeat x 456]" $probe
   run_hw_ila $ila
   wait_on_hw_ila $ila
   set data [upload_hw_ila_data $ila]
   write_hw_ila_data -force -csv_file [file join $dir pass_${pass}_capture_${i}.csv] $data
   after 200
  }
 }
 set_control $ctrl $base
 if {$action eq "paired"} {
  for {set i 5} {$i<10} {incr i} {after 150;capture_now $ila [file join $metrics_dir capture_$i.csv]}
 }
 puts "FROZEN_FRAME_DIRECTORY=$dir"
}
if {$action in {phases vertical roi}} {
 # Preserve compensation/direction while scanning sample phase.
 scan [get_property OUTPUT_VALUE $ctrl] %x current_control
 set base [expr {$current_control&255}]
 set_property CONTROL.TRIGGER_POSITION 0 $ila
 set phase_step 1;set folder phases
 if {$action eq "vertical"} {set phase_step 8;set folder static_vertical}
 if {$action eq "roi"} {set folder static_roi}
 for {set phase 0} {$phase<64} {incr phase $phase_step} {
  set dir [file join $out $folder [format phase_%02d $phase]]
  set count 6
  if {$action eq "roi"} {set count 1}
  if {[llength [glob -nocomplain -directory $dir capture_*.csv]]==$count} {continue}
  set_control $ctrl [expr {$base|($phase<<8)}]
  file mkdir $dir
  set pb "";for {set b 5} {$b>=0} {incr b -1} {append pb [expr {($phase>>$b)&1}]}
  for {set i 0} {$i<$count} {incr i} {
   set address [expr {$action eq "roi"?2300:$i*1024}];set ab ""
   for {set b 12} {$b>=0} {incr b -1} {append ab [expr {($address>>$b)&1}]}
   set_property TRIGGER_COMPARE_VALUE "eq480'b110${ab}${pb}01[string repeat x 456]" $probe
   run_hw_ila $ila
   wait_on_hw_ila $ila
   set data [upload_hw_ila_data $ila]
   write_hw_ila_data -force -csv_file [file join $dir capture_$i.csv] $data
   after 200
  }
 }
 set_control $ctrl $base
}
if {$action eq "sweep"} {
 set lo [lindex $argv 1];set hi [lindex $argv 2]
 if {$lo<0||$hi>31||$lo>$hi} {error "Invalid row sweep range"}
 for {set reverse 0} {$reverse<2} {incr reverse} {
  for {set dy $lo} {$dy<=$hi} {incr dy} {
   set value [expr {128|($reverse<<6)|$dy}]
   set_control $ctrl $value
   set dir [file join $out sweep [format control_%03d $value]];file mkdir $dir
   for {set i 0} {$i<3} {incr i} {after 80;capture_now $ila [file join $dir capture_$i.csv]}
  }
 }
 set_control $ctrl 0
}
close_hw_target
disconnect_hw_server
close_hw
puts ROW_ALIGNMENT_HW_OK
