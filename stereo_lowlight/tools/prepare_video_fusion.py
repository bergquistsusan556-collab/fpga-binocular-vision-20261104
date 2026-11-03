"""Narrow byte-preserving updates to the GBK board top and build selectors."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=r/'rtl/top_dual_ov5640_lcd.v'
b=p.read_bytes()
old=b'mode_50m==3 ? 0 : mode_50m+1\'b1'
new=b'mode_50m+1\'b1'
assert b.count(old)==1
p.write_bytes(b.replace(old,new))
p=r/'tools/manifest.py'
s=p.read_text()
s=s.replace("'roi_snapshot','robust_match'", "'roi_snapshot','robust_match','video_fusion'")
s=s.replace("if variant=='robust_match':", "if variant in ('robust_match','video_fusion'):")
p.write_text(s,encoding='utf-8')
p=r/'tools/row_alignment_hw.tcl'
s=p.read_text()
s=s.replace('set action [lindex $argv 0]', 'if {[lindex $argv end] eq "video"} {set out [file join $root build video_fusion]}\nset action [lindex $argv 0]')
p.write_text(s,encoding='utf-8')
