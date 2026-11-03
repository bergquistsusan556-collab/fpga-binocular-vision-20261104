"""Reconstruct actual sampled luminance at all 8x8 phases; not one exposure."""
from pathlib import Path
import csv,json,sys
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[1];out=r/'build/row_alignment'
vertical=len(sys.argv)>1 and sys.argv[1]=='vertical'
folder='static_vertical' if vertical else 'phases'
im=np.zeros((480,100 if vertical else 800),dtype=np.uint8);covered=np.zeros_like(im,dtype=bool)
for phase in range(0,64,8 if vertical else 1):
 pixels={};bad=0;changed=0
 for path in sorted((out/folder/f'phase_{phase:02d}').glob('capture_*.csv')):
  previous=None
  for row in list(csv.reader(path.open()))[2:]:
   if not row:continue
   v=int(row[-1],16)>>448
   assert v>>29==6 and (v>>8)&3==1,'Wrong luminance tap format'
   assert (v>>10)&63==phase,'Sample phase not settled'
   addr=(v>>16)&8191;value=v&255
   assert addr<6000
   if previous is not None and addr!=(previous+1)%6000:bad+=1
   previous=addr
   if addr in pixels and pixels[addr]!=value:changed+=1
   pixels[addr]=value
 assert len(pixels)==6000 and bad==0,(phase,len(pixels),bad)
 for addr,value in pixels.items():
  y=(addr//100)*8+(phase>>3);x=addr%100 if vertical else (addr%100)*8+(phase&7)
  im[y,x]=value;covered[y,x]=True
assert covered.all()
name='vertical' if vertical else 'phases';half=50 if vertical else 400
Image.fromarray(im).save(out/f'raw_stereo_{name}.png')
Image.fromarray(im).resize((800,480),Image.Resampling.NEAREST).save(out/f'raw_stereo_{name}_preview.png')
Image.fromarray(im[:,:half]).save(out/f'raw_left_{name}.png')
Image.fromarray(im[:,half:]).save(out/f'raw_right_{name}.png')
(out/f'{name}_verification.json').write_text(json.dumps({'complete':bool(covered.all()),'pixels':int(covered.sum()),
 'warning':f'{int(covered.sum())} actual samples assembled over multiple frames/exposures; moving content is not geometrically valid.'},indent=2))
print(f'Complete luminance sampling: {covered.sum()} pixels; all phase tags/address sequences verified')
