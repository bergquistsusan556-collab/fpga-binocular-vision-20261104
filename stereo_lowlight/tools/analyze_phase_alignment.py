"""Estimate local registration from observed imagery, never label it calibration."""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[1];folder=r/'build/row_alignment'
vertical=len(sys.argv)>1 and sys.argv[1]=='vertical'
scale=8 if vertical else 1
a=np.array(Image.open(folder/('raw_stereo_vertical.png' if vertical else 'raw_stereo_phases.png')),dtype=float)
half=a.shape[1]//2
left,right=a[:,:half],a[:,half:]
def correlation(x0,y0,size,dx,dy):
 w=max(1,size//scale)
 if min(x0+dx,y0+dy)<0 or x0+dx+w>half or y0+dy+size>480:return -1
 aa=left[y0+dy:y0+dy+size,x0+dx:x0+dx+w].ravel().copy()
 bb=right[y0:y0+size,x0:x0+w].ravel().copy()
 if aa.shape!=bb.shape:return -1
 aa-=aa.mean();bb-=bb.mean()
 return float(aa@bb/(np.linalg.norm(aa)*np.linalg.norm(bb)+1e-9))
results=[]
for x,y in ((80,100),(200,100),(80,220),(200,220),(80,340),(200,340)):
 x//=scale
 candidates=[]
 for dy in range(-40,9):
  for dx in range(-40//scale,40//scale+1,1 if vertical else 2):candidates.append((correlation(x,y,64,dx,dy),dx,dy))
 best=max(candidates);score,dx,dy=best
 fine=[(correlation(x,y,64,ddx,ddy),ddx,ddy) for ddx in range(dx-2,dx+3) for ddy in range(dy-2,dy+3)]
 score,dx,dy=max(fine)
 results.append({'right_patch_xy':[x*scale,y],'size':64,'left_minus_right_xy':[dx*scale,dy],'correlation':round(score,5)})
record={'patches':results,'warning':'Local translations in a multi-frame image; not intrinsic/extrinsic or metric-depth calibration.'}
(folder/('vertical_registration.json' if vertical else 'local_registration.json')).write_text(json.dumps(record,indent=2))
print(json.dumps(record,indent=2))
