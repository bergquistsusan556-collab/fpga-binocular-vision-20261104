"""Known disparity on observed blurry text, with independent radiometric noise."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[1];sim=r/'sim'
texture=sim/'degraded_texture.png'
if not texture.exists():
 Image.open(r/'build/roi_snapshot/frozen_frames/20261025_002806/left_roi.png').save(texture)
tile=np.array(Image.open(texture),dtype=float)
base=np.tile(tile,(15,4))[:480,:400]
truth=np.where(np.arange(400)<133,4,np.where(np.arange(400)<267,12,22))
source=np.tile(tile,(15,5))[:480,:500]
rng=np.random.default_rng(564015)
right=np.clip(source[:,np.arange(400)+truth]*1.04+5+rng.normal(0,0.75,(480,400)),0,255)
frame=np.hstack((base,right)).astype(np.uint16)
packed=((frame>>3)<<11)|((frame>>2)<<5)|(frame>>3)
(sim/'degraded_rgb565.hex').write_text('\n'.join(f'{v:04x}' for v in packed.ravel())+'\n')
source_tb=(sim/'tb_stereo_scene.v').read_text()
source_tb=source_tb.replace('module tb_stereo_scene;','module tb_stereo_degraded;\n reg [15:0] observed[0:383999];')
source_tb=source_tb.replace('  for(i=0;i<3;i=i+1)begin per_total[i]=0;per_good[i]=0;end',
 '  $readmemh("degraded_rgb565.hex",observed);\n  for(i=0;i<3;i=i+1)begin per_total[i]=0;per_good[i]=0;end')
source_tb=source_tb.replace('rgb=i<400?pixel(i,j):pixel(i-400+truth(i-400),j);','rgb=observed[j*800+i];')
source_tb=source_tb.replace('if(accepted*100<checked*50 || correct*100<accepted*95)',
 'if(accepted<1000 || correct*100<accepted*95)')
# This sparse, low-contrast input need not produce a central valid distance.
source_tb=source_tb.replace('  if(!dv||dominant!=12||cm<91||cm>93)$fatal(1,"Scene center distance wrong: valid=%b d=%0d cm=%0d",dv,dominant,cm);','')
source_tb=source_tb.replace('PASS 400x480 RGB stereo scene,','PASS observed blurry text + gain/bias/noise,')
(sim/'tb_stereo_degraded.v').write_text(source_tb)
(sim/'degraded_scene_metadata.json').write_text(json.dumps({'seed':564015,'gain':1.04,'bias':5,
 'noise_standard_deviation':0.75,'disparities':[4,12,22],
 'source':'Observed left ROI from 20261025_002806; generated correspondence, not physical ground truth.'},indent=2))
print('Generated known-disparity degraded scene from observed blurry-text texture')
