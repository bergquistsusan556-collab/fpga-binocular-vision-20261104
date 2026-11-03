set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build front_range_20261103]
open_checkpoint [file join $out synthesized.dcp]
source [file join $root tools implement_front_range.tcl]
