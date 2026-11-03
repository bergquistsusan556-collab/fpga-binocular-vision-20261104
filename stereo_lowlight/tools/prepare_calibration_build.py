"""Derive isolated build scripts without modifying production source or builds."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'tools/build.tcl').read_text()
start=source.index('set out [file join $root build fusion]')
end=source.index('file mkdir $out',start)
source=source[:start]+'set out [file join $root build calibration_capture]\n'+source[end:]
source=source.replace('set skip {','set skip {lcd_rgb_top.v ')
source=source.replace('read_verilog [list [file join $ip clk_wiz_0_1',
 'foreach f [glob [file join $root variants calibration_capture rtl *.v]] {read_verilog [list $f]}\nread_verilog [list [file join $ip clk_wiz_0_1',1)
source=source.replace('source [file join $root tools implement.tcl]',
 'source [file join $root tools implement_calibration_capture.tcl]')
(root/'tools/build_calibration_capture.tcl').write_text(source)
impl=(root/'tools/implement.tcl').read_text()
impl=impl.replace('C_DATA_DEPTH 1024','C_DATA_DEPTH 8192')
start=impl.index('set diagnostic_width 480')
end=impl.index('set_property port_width',start)
impl=impl[:start]+'set diagnostic_width 32\n'+impl[end:]
impl=impl.replace('[format {diagnostic_bus[%d]} $i]', '[format {diagnostic_bus[%d]} [expr {$i+448}]]')
(root/'tools/implement_calibration_capture.tcl').write_text(impl)
print('Prepared isolated calibration_capture scripts')
