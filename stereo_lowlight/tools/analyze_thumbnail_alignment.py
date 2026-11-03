"""Coarse image shift evidence only, not stereo calibration or depth accuracy."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[1]
folder=r/'build/distance_observer/thumbnail'
a=np.asarray(Image.open(folder/'raw_stereo_100x60.png')).astype(float)
gray=a@np.array([.299,.587,.114]);left,right=gray[:,:50],gray[:,50:]
results=[]
for dy in range(-8,9):
 for dx in range(-8,9):
  # Compare R(x,y) to L(x+dx,y+dy); all shifts use the same right crop.
  aa=left[12+dy:48+dy,10+dx:40+dx].ravel()
  bb=right[12:48,10:40].ravel()
  aa-=aa.mean();bb-=bb.mean()
  score=float(aa@bb/(np.linalg.norm(aa)*np.linalg.norm(bb)+1e-9))
  results.append({'dx_thumbnail':dx,'dy_thumbnail':dy,'dx_source_px':dx*8,
                  'dy_source_px':dy*8,'normalized_correlation':round(score,6)})
results.sort(key=lambda d:-d['normalized_correlation'])
record={'comparison':'R(x,y) versus L(x+dx,y+dy)','best':results[0],
 'best_same_row':max((d for d in results if d['dy_thumbnail']==0),key=lambda d:d['normalized_correlation']),
 'top10':results[:10],
 'limitations':'8-pixel sampling, live asynchronous thumbnail, scene-dependent global shift. Not a rectification map or calibration; do not use as a distance scale.'}
(folder/'coarse_alignment.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record,indent=2))
