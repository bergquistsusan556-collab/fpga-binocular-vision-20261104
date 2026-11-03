# Same synthesized algorithm; expose the already existing raw-luminance observer.
set root [file normalize [file join [file dirname [info script]] ..]]
set prior [file join $root build target_follow_20261103]
set out [file join $root build target_follow_observer_20261103]
file mkdir $out
if {[file exists [file join $out timing_pass.txt]]} {error "Signed build exists"}
open_checkpoint [file join $prior synthesized.dcp]
# Current tracking signoff already exposes the 32-bit raw observer alongside
# the 256-bit status probes. This archive helper uses the same implementation.
source [file join $root tools implement_target_follow.tcl]
