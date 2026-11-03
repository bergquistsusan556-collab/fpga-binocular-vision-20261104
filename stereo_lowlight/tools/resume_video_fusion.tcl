set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build video_fusion]
open_checkpoint [file join $out synthesized.dcp]
source [file join $root tools implement.tcl]
