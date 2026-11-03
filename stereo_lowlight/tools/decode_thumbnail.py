"""Reconstruct the diagnostic RGB565 tap; retain actual low-resolution pixels."""
from pathlib import Path
import csv,json
from PIL import Image
root=Path(__file__).resolve().parents[1]
folder=root/'build/distance_observer/thumbnail'
pixels={};conflicts=0;bad_order=0
for p in sorted(folder.glob('capture_*.csv')):
 rows=list(csv.reader(p.open()))[2:]
 previous=None
 for row in rows:
  if not row:continue
  sample=int(row[-1],16)>>448
  assert sample>>29==5,'Wrong diagnostic layout'
  addr=(sample>>16)&8191;rgb=sample&65535
  assert addr<6000,addr
  if previous is not None and addr!=(previous+1)%6000:bad_order+=1
  previous=addr
  if addr in pixels and pixels[addr]!=rgb:conflicts+=1
  pixels[addr]=rgb
assert len(pixels)==6000,f'Incomplete image: {len(pixels)}/6000'
assert bad_order==0,f'Unexpected read address order: {bad_order}'
im=Image.new('RGB',(100,60))
im.putdata([(((pixels[i]>>11)&31)*255//31,((pixels[i]>>5)&63)*255//63,(pixels[i]&31)*255//31)
            for i in range(6000)])
im.save(folder/'raw_stereo_100x60.png')
im.resize((800,480),Image.Resampling.NEAREST).save(folder/'raw_stereo_preview.png')
record={'pixels':len(pixels),'width':100,'height':60,'sample_step_xy':8,
 'changed_duplicate_pixels':conflicts,'bad_address_order':bad_order,
 'note':'Live sampled thumbnail across captures, not a synchronized stereo exposure.'}
(folder/'thumbnail_verification.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record))
