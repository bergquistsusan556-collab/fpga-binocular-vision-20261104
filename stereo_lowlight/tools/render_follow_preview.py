from pathlib import Path
import csv
import json
import sys
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tmp/target_follow_opencv'))
import cv2
folder=Path(sys.argv[1]);pixels={}
for i in range(6):
    with (folder/f'phase_0_capture_{i}.csv').open(newline='') as stream:table=list(csv.reader(stream))
    column=next(j for j,h in enumerate(table[0]) if '479:448' in h)
    for row in table[2:]:
        word=int(row[column],16);pixels.setdefault((word>>16)&8191,word&255)
assert len(pixels)==6000
gray=np.array([pixels[i] for i in range(6000)],np.uint8).reshape(60,100)
Image.fromarray(gray).resize((600,360),Image.Resampling.NEAREST).save(folder/'preview.png')
detector=cv2.aruco.ArucoDetector(cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50))
report={'warning':'Coarse raw preview spans six block reads, not a synchronized capture.','eyes':{}}
for name,eye in [('left',gray[:,:50]),('right',gray[:,50:])]:
    enlarged=cv2.resize(eye,None,fx=6,fy=6,interpolation=cv2.INTER_NEAREST)
    corners,ids,_=detector.detectMarkers(enlarged)
    report['eyes'][name]={'ids':[] if ids is None else ids.ravel().tolist(),
                         'corners':[] if ids is None else [q.reshape(4,2).tolist() for q in corners]}
(folder/'preview.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
