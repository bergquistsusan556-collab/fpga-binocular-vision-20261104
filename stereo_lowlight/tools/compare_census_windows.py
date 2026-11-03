"""Compare window sizes on saved real input before changing the FPGA matcher."""
from pathlib import Path
import numpy as np
from PIL import Image
import json,sys
r=Path(__file__).resolve().parents[1]
d=r/'build/roi_snapshot/frozen_frames'/(sys.argv[1] if len(sys.argv)>1 else '20261025_002806')
left=np.array(Image.open(d/'left_roi.png'),dtype=int);right=np.array(Image.open(d/'right_roi.png'),dtype=int)
def features(im):
 code=np.zeros_like(im,dtype=np.uint8);lo=im.copy();hi=im.copy()
 for bit,(dy,dx) in enumerate(((-2,-2),(-2,-1),(-2,0),(-1,-2),(-1,-1),(-1,0),(0,-2),(0,-1))):
  n=np.roll(im,(-dy,-dx),(0,1));code|=(n<im).astype(np.uint8)<<bit;lo=np.minimum(lo,n);hi=np.maximum(hi,n)
 return code,(hi-lo)>=8
lc,_=features(left);rc,rt=features(right);pop=np.array([i.bit_count() for i in range(256)])
results=[]
for window in (3,7,15,31):
 ys,xs=np.mgrid[4:20,max(16,window+1):56]
 for dy in (-25,-26,-27,-28):
  costs=[]
  for disparity in range(1,64):
   lx=xs+48-disparity;ly=ys+32+dy
   inside=(lx>=window+1)&(lx<128)&(ly>=2)&(ly<32)
   cost=np.zeros(xs.shape,dtype=int)
   for col in range(window):cost+=pop[rc[ys,xs-col]^lc[np.clip(ly,0,31),np.clip(lx-col,0,127)]]
   costs.append(np.where(inside,cost,255))
  costs=np.array(costs);order=np.partition(costs,1,axis=0);disp=costs.argmin(axis=0)+1
  for margin in (2,4,6):
   valid=(order[0]<=window*3)&(order[1]>=order[0]+margin)&rt[ys,xs]
   hist=np.bincount(disp[valid],minlength=64);peak=int(hist.argmax());cluster=int(hist[max(1,peak-1):peak+2].sum());population=int(valid.sum())
   results.append({'window':window,'dy':dy,'margin':margin,'population':population,'peak':peak,
    'peak_count':int(hist[peak]),'cluster':cluster,'cluster_fraction':round(cluster/max(1,population),4)})
(d/'window_comparison.json').write_text(json.dumps(results,indent=2))
for v in results:
 if v['margin'] in (2,6):print(v)
