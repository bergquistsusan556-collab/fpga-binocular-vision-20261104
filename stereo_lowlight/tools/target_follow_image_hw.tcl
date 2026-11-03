# Static-scene diagnostic readback; samples span multiple camera frames.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build target_follow_20261103]
if {[llength $argv]!=2} {error "Expected program|image|preview GROUP"}
lassign $argv action group
if {$action ni {program image preview}||![regexp {^[A-Za-z0-9_]+$} $group]} {error "Invalid action/group"}
set folder [file join $out hardware $group]
if {[file exists $folder]} {error "Capture group exists"}
open_hw
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet]
if {[llength $targets]!=1} {error "Wrong JTAG target count"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 1000000 $target
open_hw_target $target
set devs [get_hw_devices -quiet]
if {[llength $devs]!=1} {error "Wrong device count"}
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
set ctrl [get_hw_probes -of_objects $vio]
set observer {}
foreach p [get_hw_probes -of_objects $ila] {
 if {[regexp {(^|/)diagnostic_bus$} [get_property NAME $p]]} {lappend observer $p}
}
if {[llength $ila]!=1||[llength $ctrl]!=1||[llength $observer]!=1} {error "Missing diagnostics"}
scan [get_property OUTPUT_VALUE $ctrl] %x initial_control
set base [expr {$initial_control&255}]
file mkdir $folder
set meta [open [file join $folder capture_meta.txt] w]
puts $meta "build=target_follow_20261103; base_control=$base"
puts $meta "Diagnostic multi-frame sampled luminance; target must remain still; not a synchronized stereo measurement"
puts $meta "host_time=[clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]"
close $meta
if {$action eq "program"} {after 10000}
set failure [catch {
 set_property CONTROL.TRIGGER_POSITION 0 $ila
 # Four phases on each axis reconstruct the detector's 2x sampled geometry.
 set phases {0 2 4 6}
 if {$action eq "preview"} {set phases {0}}
 foreach py $phases {
  foreach px $phases {
   set phase [expr {$px|($py<<3)}]
   set_property OUTPUT_VALUE [format %04x [expr {$base|($phase<<8)}]] $ctrl
   commit_hw_vio $ctrl
   after 100
   set pb "";for {set b 5} {$b>=0} {incr b -1} {append pb [expr {($phase>>$b)&1}]}
   for {set i 0} {$i<6} {incr i} {
    set address [expr {$i*1024}]
    set ab "";for {set b 12} {$b>=0} {incr b -1} {append ab [expr {($address>>$b)&1}]}
    set_property TRIGGER_COMPARE_VALUE "eq32'b110${ab}${pb}01xxxxxxxx" $observer
    run_hw_ila $ila
    wait_on_hw_ila -timeout 10 $ila
    set data [upload_hw_ila_data $ila]
    write_hw_ila_data -force -csv_file [file join $folder phase_${phase}_capture_${i}.csv] $data
   }
   puts "PHASE_READ_OK=$phase"
  }
 }
} problem]
set_property OUTPUT_VALUE [format %04x $initial_control] $ctrl
commit_hw_vio $ctrl
puts "RESTORED_CONTROL=[get_property OUTPUT_VALUE $ctrl]"
close_hw_target
disconnect_hw_server
close_hw
if {$failure} {error $problem}
puts "TARGET_FOLLOW_IMAGE_OK=$folder"
