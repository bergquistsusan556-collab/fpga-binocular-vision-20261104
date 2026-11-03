import csv
from pathlib import Path
import numpy as np
from decode_calibration_native import decode

root=Path(__file__).resolve().parents[1]/'build/calibration_native/decoder_selftest'
for name,eye in (('left',0),('right',1),('left_check',0)):
    folder=root/name;folder.mkdir(parents=True,exist_ok=True)
    image=np.full((480,400),47,dtype=np.uint8)
    for y in range(6):
        for x in range(9):
            xx=140+x*12-12*eye;yy=192+y*12
            image[yy:yy+12,xx:xx+12]=60 if (x+y)%2 else 3
    pixels=image.ravel().reshape(-1,3).astype(np.uint32)
    words=pixels[:,0]|(pixels[:,1]<<6)|(pixels[:,2]<<12)
    for pass_no in range(2):
        for chunk in range(16):
            with (folder/f'pass_{pass_no}_capture_{chunk}.csv').open('w',newline='') as f:
                out=csv.writer(f);out.writerow(['Sample in Buffer','Sample in Window','TRIGGER','diagnostic_bus[479:432]'])
                out.writerow(['Radix - UNSIGNED','UNSIGNED','UNSIGNED','HEX'])
                for n in range(4096):
                    addr=(chunk*4096+n)%64000
                    out.writerow([n,n,int(n==0),f'{(13<<44)|(3<<40)|(eye<<39)|(addr<<18)|int(words[addr]):012x}'])
result=decode(root)
assert all(v['checker_found'] for v in result['views'].values())
assert result['stationarity']['max_px']<0.001
assert abs(result['raw_corner_offset']['median_x_left_minus_right']-12)<0.1
assert abs(result['raw_corner_offset']['median_y_left_minus_right'])<0.1
file=root/'right/pass_1_capture_2.csv';original=file.read_text();lines=original.splitlines()
fields=lines[4].split(',');fields[-1]=f'{int(fields[-1],16)^1:012x}';lines[4]=','.join(fields)
file.write_text('\n'.join(lines)+'\n')
try:
    decode(root)
except ValueError as e:
    assert str(e)=='Repeat reads/eye differ'
else:raise AssertionError('Corrupt read accepted')
file.write_text(original)
print('PASS native packed decoding, known 12-pixel correspondence, stationarity, corrupt-read rejection')
