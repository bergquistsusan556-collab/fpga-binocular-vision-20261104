from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'tools/calibration_capture_hw.tcl').read_text().replace('calibration_capture','calibration_native')
source=source.replace('CALIBRATION_CAPTURE_HW_OK','CALIBRATION_NATIVE_HW_OK')
source=source.replace('Each view 400x480 native. Full-field sampled every 2 pixels, or native crop x=100,y=120,size=200x240.',
 'Native 400x480 single-eye frames; luminance quantized to 6 bits. Left, right, then left-check exposures are sequential; keep board fixed.')
source=source.replace('foreach {name value} {fullfield 1 center_crop 20}', 'foreach {name value} {left 0 right 1 left_check 0}')
source=source.replace('{$i<12}', '{$i<16}').replace('$i*8192','$i*4096').replace('set b 16','set b 15')
source=source.replace('# header=11, complete=1, epoch=xxxx, address[16:0], luminance=xxxxxxxx.',
 '# header=110, complete=1, epoch=xxxx, eye, reserved=00000, address16, packed_luma18.')
source=source.replace('"eq32\'b111xxxx${ab}xxxxxxxx"', '"eq48\'b1101xxxx${value}00000${ab}[string repeat x 18]"')
source=source.replace('for {set pass 0}', 'puts "CAPTURE_HELD=${name}:[clock milliseconds]"\n for {set pass 0}')
(root/'tools/calibration_native_hw.tcl').write_text(source)
print('Prepared native acquisition helper')
