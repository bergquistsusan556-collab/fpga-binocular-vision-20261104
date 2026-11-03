"""Recover actual full-resolution samples around the ROI, then inspect translation.

Samples span many live frames. This is a diagnostic, not synchronized calibration.
"""
from pathlib import Path
import csv,json
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[1];out=r/'build/row_alignment'
a=np.zeros((80,800),dtype=np.uint8);covered=np.zeros_like(a,dtype=bool)
for phase in range(64):
 p=out/'static_roi'/f'phase_{phase:02d}'/'capture_0.csv'
 values=[]
 for row in list(csv.reader(p.open()))[2:]:
  if not row:continue
  v=int(row[-1],16)>>448
  assert v>>29==6 and (v>>8)&3==1 and (v>>10)&63==phase
  values.append(((v>>16)&8191,v&255))
 assert len(values)==1024 and [v[0] for v in values]==list(range(2300,3324))
 for address,value in values[:1000]:
  y=(address//100-23)*8+(phase>>3);x=(address%100)*8+(phase&7)
  a[y,x]=value;covered[y,x]=True
assert covered.all()
Image.fromarray(a).save(out/'raw_stereo_roi.png')
Image.fromarray(a).resize((1200,120)).save(out/'raw_stereo_roi_preview.png')
left,right=a[:,:400].astype(float),a[:,400:].astype(float)
def corr(x,y,w,h,dx,dy):
 aa=left[y+dy:y+dy+h,x+dx:x+dx+w].ravel().copy()
 bb=right[y:y+h,x:x+w].ravel().copy()
 if aa.shape!=bb.shape or aa.size==0:return -1
 aa-=aa.mean();bb-=bb.mean()
 return float(aa@bb/(np.linalg.norm(aa)*np.linalg.norm(bb)+1e-9))
patches=[]
for x,y,w,h in [(180,36,41,41),(160,36,80,40),(100,36,50,35),(240,36,50,35)]:
 candidates=sorted([(corr(x,y,w,h,dx,dy),dx,dy) for dy in range(-36,1) for dx in range(-63,64)],reverse=True)
 patches.append({'right_xy':[x,y+184],'size':[w,h],
  'best':[{'ncc':round(c,5),'left_minus_right':[dx,dy]} for c,dx,dy in candidates[:8]],
  'best_same_row':max(corr(x,y,w,h,dx,0) for dx in range(-63,64))})
record={'pixels':int(covered.sum()),'coverage_complete':True,'raw_y_origin':184,'patches':patches,
 'warning':'Multiple live frames; neither synchronized exposure nor calibrated geometry. Repeated text can create ambiguous correlation peaks.'}
def features(im):
 code=np.zeros_like(im,dtype=np.uint8)
 lo=im.copy();hi=im.copy()
 for bit,(dy,dx) in enumerate(((-2,-2),(-2,-1),(-2,0),(-1,-2),(-1,-1),(-1,0),(0,-2),(0,-1))):
  neighbor=np.roll(im,(-dy,-dx),(0,1))
  code|=(neighbor<im).astype(np.uint8)<<bit
  lo=np.minimum(lo,neighbor);hi=np.maximum(hi,neighbor)
 return code,(hi-lo)>=8
lc,_=features(left);rc,rt=features(right)
pop=np.array([int(i).bit_count() for i in range(256)])
ys,xs=np.mgrid[36:77,180:221]
matches=[]
for dy in range(-34,1):
 for sign in (-1,1):
  costs=[]
  for d in range(1,64):
   c=np.zeros(ys.shape,dtype=int)
   for col in range(3):c+=pop[rc[ys,xs-col]^lc[ys+dy,xs-col+sign*d]]
   costs.append(c)
  costs=np.array(costs);order=np.partition(costs,1,axis=0)
  valid=(order[0]<=9)&(order[1]>=order[0]+2)&rt[ys,xs]
  disp=costs.argmin(axis=0)+1
  hist=np.bincount(disp[valid],minlength=64);peak=int(hist.argmax())
  cluster=int(hist[max(1,peak-1):peak+2].sum());population=int(valid.sum())
  matches.append({'dy':dy,'horizontal_sign':sign,'population':population,'peak':peak,
   'cluster':cluster,'cluster_fraction':round(cluster/max(1,population),4)})
record['offline_census_best']=sorted(matches,key=lambda v:-v['cluster_fraction'])[:12]
record['offline_census_warning']='Multi-frame sampled input and Python algorithm diagnostic; hardware captures remain authoritative.'
(out/'static_roi_analysis.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record,indent=2))
