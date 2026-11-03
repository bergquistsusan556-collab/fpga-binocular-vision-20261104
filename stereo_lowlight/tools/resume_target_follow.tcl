set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build target_follow_20261103]
if {[file exists [file join $out timing_pass.txt]]} {error "Signed build already exists"}
open_checkpoint [file join $out synthesized.dcp]
source [file join $root tools implement_target_follow.tcl]
