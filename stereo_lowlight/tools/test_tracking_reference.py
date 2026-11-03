"""Synthetic feasibility study at existing geometry, not physical accuracy signoff."""
from pathlib import Path
import json
import cv2
import numpy as np
from target_tracking_reference import TargetTracker
r=Path(__file__).resolve().parents[1]
dest=r/'calibration/target_v1';dest.mkdir(parents=True,exist_ok=True)
t=TargetTracker()
dictionary=cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
marker=cv2.aruco.generateImageMarker(dictionary,7,600)
K=np.array([[346.,0,200],[0,346.,240],[0,0,1]])
P1=K@np.c_[np.eye(3),np.zeros(3)]
P2=K@np.c_[np.eye(3),[-32.,0,0]]
corners=np.array([[-80.,-80,0],[80,-80,0],[80,80,0],[-80,80,0]])
src=np.float32([[0,0],[599,0],[599,599],[0,599]])
def scene(z,angle,shift,eye):
    theta=np.deg2rad(angle)
    R=np.array([[np.cos(theta),-np.sin(theta),0],[np.sin(theta),np.cos(theta),0],[0,0,1]])
    xyz=corners@R.T+np.array([shift-32*eye,0,z])
    uv=(K@xyz.T).T;uv=uv[:,:2]/uv[:,2:]
    H=cv2.getPerspectiveTransform(src,np.float32(uv*4))
    image=cv2.warpPerspective(marker,H,(1600,1920),borderValue=255)
    return cv2.resize(image,(400,480),interpolation=cv2.INTER_AREA)
records=[]
for z in (300,500,1000,1500,2000):
 for angle in (-10,0,10):
  for shift in (-25,0,25):
   a,b=scene(z,angle,shift,0),scene(z,angle,shift,1)
   d=t.measure(a,b,P1,P2)
   records.append(dict(true_mm=z,angle=angle,shift_mm=shift,
       both_detected=d['left'] is not None and d['right'] is not None,
       valid=d['valid'],estimate_mm=d['distance_mm'],
       raw_estimate_mm=d.get('raw_distance_mm'),
       error_mm=None if d.get('raw_distance_mm') is None else d['raw_distance_mm']-z))
   if z==1000 and angle==0 and shift==0:cv2.imwrite(str(dest/'synthetic_pair.png'),np.hstack((a,b)))
blank=np.full((480,400),255,np.uint8)
assert t.locate(blank) is None
assert not t.measure(scene(1000,0,0,0),blank,P1,P2)['valid']
assert t.locate(scene(1000,0,0,0)) is not None
assert not t.measure(scene(1000,0,0,0),scene(1000,0,0,1))['valid']
wrong=cv2.aruco.generateImageMarker(dictionary,8,120)
blank[180:300,140:260]=wrong
assert t.locate(blank) is None
result={'geometry':'estimated fx=346px, baseline32mm, 400x480; ideal rectification, no exposure skew',
 'host_reference_only':True,'physical_accuracy_verified':False,'cases':records}
(dest/'reference_tests.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
for z in (300,500,1000,1500,2000):
 rows=[v for v in records if v['true_mm']==z]
 errors=[abs(v['error_mm']) for v in rows if v['error_mm'] is not None]
 print(z,'detected',sum(v['both_detected'] for v in rows),'/9 valid',sum(v['valid'] for v in rows),'raw_max_error_mm',max(errors,default=None))
print('PASS loss, reacquisition, wrong ID and missing-calibration rejection; see numerical study')
