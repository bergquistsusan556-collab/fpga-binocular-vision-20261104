"""Estimate tag/texture geometry from separate raw diagnostic sampling phases.

Diagnostic only: multi-frame, coarse images cannot certify stereo accuracy.
"""
from pathlib import Path
import argparse
import csv
import json
import sys
import numpy as np

root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tmp/target_follow_opencv'))
import cv2

parser=argparse.ArgumentParser();parser.add_argument('folder',type=Path)
args=parser.parse_args()
detector=cv2.aruco.ArucoDetector(cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50))
canonical=np.float32([[0,0],[1,0],[1,1],[0,1]])
texture=np.float32([[[0.5,1.1875],[0.125,1.125],[0.875,1.125],[0.875,1.25],[0.125,1.25]]])
records=[]
for py in [0,2,4,6]:
 for px in [0,2,4,6]:
  phase=px|(py<<3);pixels={}
  for number in range(6):
   with (args.folder/f'phase_{phase}_capture_{number}.csv').open(newline='') as stream:table=list(csv.reader(stream))
   col=next(i for i,h in enumerate(table[0]) if '479:448' in h)
   for row in table[2:]:
    word=int(row[col],16);pixels.setdefault((word>>16)&8191,word&255)
  gray=np.array([pixels[i] for i in range(6000)],np.uint8).reshape(60,100)
  record={'phase':phase,'eyes':{}}
  for eye_name,eye in [('left',gray[:,:50]),('right',gray[:,50:])]:
   enlarged=cv2.resize(eye,None,fx=6,fy=6,interpolation=cv2.INTER_NEAREST)
   corners,ids,_=detector.detectMarkers(enlarged)
   quads=[] if ids is None else [q for ident,q in zip(ids.ravel(),corners) if int(ident)==7]
   if len(quads)!=1:continue
   quad=quads[0].reshape(4,2)/6*4+np.float32([px/2,py/2])
   homography=cv2.getPerspectiveTransform(canonical,np.float32(quad))
   band=cv2.perspectiveTransform(texture,homography)[0]
   record['eyes'][eye_name]={'marker_analysis_quad':quad.tolist(),
                            'texture_center_native':(band[0]*2).tolist(),
                            'texture_outline_native':(band[1:]*2).tolist()}
  if len(record['eyes'])==2:
   left=np.array(record['eyes']['left']['texture_center_native'])
   right=np.array(record['eyes']['right']['texture_center_native'])
   record['texture_right_minus_left_native']=(right-left).tolist()
  records.append(record)
pairs=[r['texture_right_minus_left_native'] for r in records if 'texture_right_minus_left_native' in r]
result={'warning':'Coarse, multi-frame diagnostic. Neither range calibration nor accuracy verification.',
        'paired_id7_phases':len(pairs),
        'median_texture_right_minus_left_native':np.median(pairs,axis=0).tolist() if pairs else None,
        'records':records}
(args.folder/'tag_texture_geometry.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='records'},indent=2))
