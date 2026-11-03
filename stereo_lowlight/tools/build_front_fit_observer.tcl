# Reuse the exact tested synthesis checkpoint; add observer readback only.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build front_fit_observer_20261103]
file mkdir $out
if {[file exists [file join $out timing_pass.txt]]} {error "Refuse overwrite of a signed build"}
open_checkpoint [file join $root build front_fit_20261103 synthesized.dcp]
set source [open [file join $root tools implement_front_fit.tcl] r]
set body [read $source]
close $source
if {[string first {set diagnostic_width 320} $body] < 0} {error "Unexpected implementation template"}
set body [string map [list {set diagnostic_width 320} {set diagnostic_width 352}] $body]
eval $body
