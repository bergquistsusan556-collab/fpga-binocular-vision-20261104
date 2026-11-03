"""Inspect normalized border candidates on static diagnostic images."""
from pathlib import Path
import csv
import json
import numpy as np

root=Path(__file__).resolve().parents[1]
folder=root/'build/target_follow_observer_20261103/hardware/static_target'
pattern=np.array(json.loads((root/'calibration/target_v1/spec.json').read_text())['matrix_including_border'])
records=[]
for phase in [2,4,6,16,18,22,34,38,48,54]:
    pixels={}
    for i in range(6):
        table=list(csv.reader((folder/f'phase_{phase}_capture_{i}.csv').open()))
        col=next(j for j,h in enumerate(table[0]) if '479:448' in h)
        for row in table[2:]:
            value=int(row[col],16);pixels.setdefault((value>>16)&8191,value&255)
    gray=np.array([pixels[a] for a in range(6000)],np.uint8).reshape(60,100)[:,50:]
    image=np.repeat(np.repeat(gray,4,0),4,1)>=128
    candidates=[]
    for y in range(2,226):
        edges=np.diff(np.r_[True,image[y],True].astype(int))
        for x,end in zip(np.where(edges==-1)[0],np.where(edges==1)[0]):
            w=end-x
            if not(12<=w<=190 and x>=2 and end<198):continue
            if not image[max(0,y-w//6),x+w//2]:continue
            heights=[]
            for px in [x+w//12,x+w-1-w//12]:
                yy=y
                while yy<238 and not image[yy,px]:yy+=1
                heights.append(yy-y)
            h=max(heights)
            if not(12<=h and y+h<238 and h*3>=w and h<=w*3):continue
            if not(image[y+h//2,max(0,x-w//6)] and image[y+h//2,min(199,x+w+w//6)] and image[min(239,y+h+h//12),x+w//2]):continue
            yy=y+(2*np.arange(6)+1)*h//12;xx=x+(2*np.arange(6)+1)*w//12
            sample=image[np.ix_(yy,xx)]
            costs=[int((sample!=np.rot90(pattern,-rotation)).sum()) for rotation in range(4)]
            candidates.append((min(costs),int(x),y,int(w),h,costs.index(min(costs))))
    records.append({'phase':phase,'best':sorted(candidates)[:4]})
text=json.dumps(records,indent=2,default=int)
(folder/'normalized_candidate_diagnosis.json').write_text(text)
print(text)
