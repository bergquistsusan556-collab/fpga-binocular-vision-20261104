set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build fusion]
open_checkpoint [file join $out routed.dcp]
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
puts "FINAL_WNS=$wns FINAL_WHS=$whs"
if {$wns<0||$whs<0} {error "Timing failed: do not program"}
set fh [open [file join $out timing_pass.txt] w]
puts $fh "WNS=$wns WHS=$whs"
close $fh
puts SIGNOFF_OK
