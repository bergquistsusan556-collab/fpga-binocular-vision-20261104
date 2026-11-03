from pathlib import Path
root=Path(__file__).resolve().parents[1]
lcd=(root/'variants/calibration_capture/rtl/lcd_rgb_top.v').read_text()
lcd=lcd.replace('calibration_capture capture(', 'calibration_native_capture capture(')
lcd=lcd.replace('diagnostic_extra[95:64]', 'diagnostic_extra[95:48]')
lcd=lcd.replace('diagnostic_extra[63:0]', 'diagnostic_extra[47:0]')
(root/'variants/calibration_native/rtl/lcd_rgb_top.v').write_text(lcd)
build=(root/'tools/build_calibration_capture.tcl').read_text().replace('calibration_capture','calibration_native')
(root/'tools/build_calibration_native.tcl').write_text(build)
impl=(root/'tools/implement_calibration_capture.tcl').read_text()
impl=impl.replace('C_DATA_DEPTH 8192','C_DATA_DEPTH 4096').replace('set diagnostic_width 32','set diagnostic_width 48').replace('$i+448','$i+432')
(root/'tools/implement_calibration_native.tcl').write_text(impl)
print('Prepared native single-eye profile; production fusion unchanged')
