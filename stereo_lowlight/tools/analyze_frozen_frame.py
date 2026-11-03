"""Validate frozen ROI readback twice, inspect local alignment, preserve evidence."""
from pathlib import Path
import csv,json,sys
import numpy as np
from PIL import Image,ImageDraw
r=Path(__file__).resolve().parents[1]
variant='robust_match' if 'robust' in sys.argv else 'roi_snapshot'
root=r/'build'/variant/'frozen_frames'
names=[arg for arg in sys.argv[1:] if arg!='robust']
if '--folder' in names:
 d=Path(names[names.index('--folder')+1]).resolve()
else:
 d=root/names[0] if names else sorted(p for p in root.iterdir() if p.is_dir())[-1]
frames=[]
for repeat in range(2):
 pixels={}
 for i in range(6):
  previous=None;values=[]
  table=list(csv.reader((d/f'pass_{repeat}_capture_{i}.csv').open()))
  columns=[j for j,name in enumerate(table[0]) if '479:384' in name]
  col=columns[0] if columns else len(table[0])-1
  shift=64 if columns else 448
  for row in table[2:]:
   if not row:continue
   v=int(row[col],16)>>shift
   assert v>>29==6 and (v>>8)&3==2 and (v>>10)&63==1,'Snapshot not complete or wrong format'
   addr=(v>>16)&8191;value=v&255
   assert 0<=addr<6000
   if previous is not None:assert addr==(previous+1)%6000,'Discontinuous read address'
   previous=addr;values.append(addr)
   if addr in pixels:assert pixels[addr]==value,'Frozen memory changed during read'
   pixels[addr]=value
  assert len(values)==1024 and values[0]==i*1024
 assert len(pixels)==6000
 frames.append(np.array([pixels[a] for a in range(5888)],dtype=np.uint8))
assert np.array_equal(*frames),'Saved single-frame ROI changed between two complete reads'
left=frames[0][:4096].reshape(32,128);right=frames[0][4096:].reshape(28,64)
Image.fromarray(left).save(d/'left_roi.png');Image.fromarray(right).save(d/'right_roi.png')
canvas=Image.new('RGB',(768,264),'#202020');draw=ImageDraw.Draw(canvas)
draw.text((4,4),'LEFT raw ROI: x128..255 y192..223 (nearest x4)',fill='white')
canvas.paste(Image.fromarray(left).resize((512,128),Image.Resampling.NEAREST),(4,24))
draw.text((4,160),'RIGHT raw ROI: x176..239 y224..251 (nearest x3)',fill='white')
canvas.paste(Image.fromarray(right).resize((192,84),Image.Resampling.NEAREST),(4,180))
canvas.save(d/'frozen_roi_preview.png')
left=left.astype(float);right=right.astype(float)
def corr(x,y,w,h,dx,dy):
 lx=x+48+dx;ly=y+32+dy
 if min(lx,ly)<0 or lx+w>128 or ly+h>32:return None
 a=left[ly:ly+h,lx:lx+w].ravel().copy();b=right[y:y+h,x:x+w].ravel().copy()
 a-=a.mean();b-=b.mean()
 return float(a@b/(np.linalg.norm(a)*np.linalg.norm(b)+1e-9))
patches=[]
for x,y,w,h in ((8,4,32,16),(8,4,16,16),(24,4,16,16),(40,4,16,16),(16,12,24,12)):
 candidates=[]
 for dy in range(-40,-11):
  for dx in range(-63,33):
   score=corr(x,y,w,h,dx,dy)
   if score is not None:candidates.append((score,dx,dy))
 candidates.sort(reverse=True)
 best=candidates[0]
 alternative=max(c for c,dx,dy in candidates if abs(dx-best[1])>3 or abs(dy-best[2])>2)
 patches.append({'right_xy':[x+176,y+224],'size':[w,h],
  'standard_deviation':round(float(right[y:y+h,x:x+w].std()),3),
  'distinct_peak_gap':round(best[0]-alternative,6),
  'best':[{'ncc':round(s,6),'left_minus_right':[dx,dy]} for s,dx,dy in candidates[:5]]})
record={'complete':True,'pixels':5888,'both_reads_identical':True,'patches':patches,
 'warning':'One LCD frame, from independently timed camera frame buffers; local ROI translation only, not full rectification or metric calibration.'}
def features(im):
 code=np.zeros_like(im,dtype=np.uint8);lo=im.copy();hi=im.copy()
 for bit,(dy,dx) in enumerate(((-2,-2),(-2,-1),(-2,0),(-1,-2),(-1,-1),(-1,0),(0,-2),(0,-1))):
  neighbor=np.roll(im,(-dy,-dx),(0,1))
  code|=(neighbor<im).astype(np.uint8)<<bit
  lo=np.minimum(lo,neighbor);hi=np.maximum(hi,neighbor)
 return code,(hi-lo)>=8
lc,_=features(left);rc,rt=features(right)
pop=np.array([i.bit_count() for i in range(256)])
ys,xs=np.mgrid[4:20,8:40];matches=[]
for dy in range(-36,-19):
 for sign in (-1,1):
  costs=[]
  for disparity in range(1,64):
   lx=xs+48+sign*disparity;ly=ys+32+dy
   inside=(lx>=4)&(lx<128)&(ly>=2)&(ly<32)
   cost=np.zeros(xs.shape,dtype=int)
   for col in range(3):
    cost+=pop[rc[ys,xs-col]^lc[np.clip(ly,0,31),np.clip(lx-col,0,127)]]
   costs.append(np.where(inside,cost,63))
  costs=np.array(costs);order=np.partition(costs,1,axis=0)
  valid=(order[0]<=9)&(order[1]>=order[0]+2)&rt[ys,xs]
  disp=costs.argmin(axis=0)+1;hist=np.bincount(disp[valid],minlength=64)
  peak=int(hist.argmax());cluster=int(hist[max(1,peak-1):peak+2].sum());population=int(valid.sum())
  matches.append({'dy':dy,'horizontal_sign':sign,'population':population,'peak':peak,
   'cluster':cluster,'cluster_fraction':round(cluster/max(1,population),4)})
record['offline_census_textured_pixels']=int(rt[ys,xs].sum())
record['offline_census_max_population']=max(m['population'] for m in matches)
record['offline_census_best']=sorted((m for m in matches if m['population']>=24),key=lambda v:-v['cluster_fraction'])[:8]
record['offline_census_warning']='512-pixel subregion and limited search window; diagnostic only, not hardware ROI acceptance or metric accuracy.'
(d/'analysis.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record,indent=2))
