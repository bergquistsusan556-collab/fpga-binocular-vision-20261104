"""End-to-end synthetic raster test, including missing/corrupt read rejection."""
import csv
from pathlib import Path
import cv2
import numpy as np
from decode_calibration_capture import decode,read_pass

root=Path(__file__).resolve().parents[1]/'build/calibration_capture/decoder_selftest'
root.mkdir(parents=True,exist_ok=True)
pair=np.full((480,800),190,dtype=np.uint8)
# Native 9x6 checker, deliberately different offsets in the two views.
for offset in (0,400):
    for y in range(6):
        for x in range(9):
            yy=192+y*12;xx=140+x*12+offset-(12 if offset else 0)
            pair[yy:yy+12,xx:xx+12]=240 if (x+y)%2 else 12
for name,image in (
    ('fullfield',pair[::2,::2]),
    ('center_crop',np.hstack((pair[120:360,100:300],pair[120:360,500:700])))):
    folder=root/name;folder.mkdir(exist_ok=True)
    flat=image.ravel()
    for pass_no in range(2):
        for chunk in range(12):
            with (folder/f'pass_{pass_no}_capture_{chunk}.csv').open('w',newline='') as f:
                out=csv.writer(f);out.writerow(['Sample in Buffer','Sample in Window','TRIGGER','diagnostic_bus[479:448]'])
                out.writerow(['Radix - UNSIGNED','UNSIGNED','UNSIGNED','HEX'])
                for n in range(8192):
                    addr=(chunk*8192+n)%96000
                    out.writerow([n,n,int(n==0),f'{(7<<29)|(3<<25)|(addr<<8)|int(flat[addr]):08x}'])
result=decode(root)
assert all(v['checker_found'] for view in result['views'].values() for v in view['eyes'].values())
for eye in ('left','right'):
    full=np.array(result['views']['fullfield']['eyes'][eye]['corners_native_400x480'])
    crop=np.array(result['views']['center_crop']['eyes'][eye]['corners_native_400x480'])
    # Sampling the top-left pixel of each 2x2 cell introduces about half a native pixel.
    assert np.max(np.linalg.norm(full-crop,axis=1))<1.5
folder=root/'center_crop'
file=folder/'pass_1_capture_2.csv'
original=file.read_text();lines=original.splitlines()
fields=lines[4].split(',');fields[-1]=f'{int(fields[-1],16)^1:08x}';lines[4]=','.join(fields)
file.write_text('\n'.join(lines)+'\n')
try:
    decode(root)
except ValueError as e:
    assert str(e)=='Repeat reads differ'
else:
    raise AssertionError('Corrupted repeat read accepted')
file.write_text(original)
missing=folder/'pass_1_capture_5.csv';saved=missing.with_suffix('.saved')
missing.rename(saved)
try:
    read_pass(folder,1)
except ValueError as e:
    assert 'Missing pixels' in str(e)
else:
    raise AssertionError('Missing pixels accepted')
finally:
    saved.rename(missing)
decode(root)
print('PASS checker corner extraction in native coordinates, repeat-read mismatch and incomplete-read rejection')
