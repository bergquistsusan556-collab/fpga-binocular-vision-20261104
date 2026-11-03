"""Reconstruct static-scene 2x-sampled raw luminance for detector diagnosis."""
from pathlib import Path
import argparse
import csv
import json
import sys
import numpy as np
from PIL import Image

root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tmp/target_follow_opencv'))
import cv2

parser=argparse.ArgumentParser();parser.add_argument('folder',type=Path);args=parser.parse_args()
image=np.zeros((240,400),dtype=np.uint8)
conflicts=0
phase_views={}
for py in [0,2,4,6]:
 for px in [0,2,4,6]:
  phase=px|(py<<3);pixels={}
  for number in range(6):
   file=args.folder/f'phase_{phase}_capture_{number}.csv'
   with file.open(newline='',encoding='utf-8-sig') as stream:table=list(csv.reader(stream))
   col=next(i for i,h in enumerate(table[0]) if '479:448' in h)
   assert len(table[2:])==1024
   for row in table[2:]:
    word=int(row[col],16)
    assert word>>29==6 and (word>>8)&3==1 and (word>>10)&63==phase
    addr=(word>>16)&8191;value=word&255
    assert addr<6000
    if addr in pixels:conflicts+=int(pixels[addr]!=value)
    else:pixels[addr]=value
  assert len(pixels)==6000
  sample=np.array([pixels[i] for i in range(6000)],dtype=np.uint8).reshape(60,100)
  phase_views[phase]=sample
  image[py//2::4,px//2::4]=sample
Image.fromarray(image).save(args.folder/'raw_pair_analysis.png')
detector=cv2.aruco.ArucoDetector(cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50))
report={'warning':'Static-scene diagnostic assembled across multiple camera frames; not synchronized stereo or range evidence.',
        'duplicate_pixel_disagreements':conflicts,'eyes':{}}
phasewise=[]
for phase,sample in phase_views.items():
 eye=cv2.resize(sample[:,50:],None,fx=6,fy=6,interpolation=cv2.INTER_NEAREST)
 corners,ids,_=detector.detectMarkers(eye)
 phasewise.append({'phase':phase,'ids':[] if ids is None else ids.ravel().tolist(),
                   'corners_in_6x_preview':[] if ids is None else [q.reshape(4,2).tolist() for q in corners]})
report['phasewise_right_detections']=phasewise
report['phasewise_right_id7_count']=sum(7 in entry['ids'] for entry in phasewise)
report['phasewise_scope']='Separate sampling phases; not FPGA detector results or coherent synchronized stereo frames.'
for name,eye in [('left',image[:,:200]),('right',image[:,200:])]:
 Image.fromarray(eye).save(args.folder/f'{name}.png')
 Image.fromarray((eye>=128).astype(np.uint8)*255).save(args.folder/f'{name}_binary128.png')
 corners,ids,_=detector.detectMarkers(eye)
 found=[]
 if ids is not None:
  found=[{'id':int(ident),'corners':quad.reshape(4,2).tolist()} for ident,quad in zip(ids.ravel(),corners)]
 _,mirror_ids,_=detector.detectMarkers(cv2.flip(eye,1))
 report['eyes'][name]={'gray_min':int(eye.min()),'gray_max':int(eye.max()),'gray_mean':float(eye.mean()),
                      'fraction_below_128':float((eye<128).mean()),'markers':found,
                      'mirrored_ids':[] if mirror_ids is None else mirror_ids.ravel().tolist()}
(args.folder/'image_diagnosis.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
