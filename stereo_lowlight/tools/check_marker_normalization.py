from pathlib import Path
import sys
import numpy as np
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tmp/target_follow_opencv'))
import cv2
dictionary=cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
marker=cv2.aruco.generateImageMarker(dictionary,7,60)
pattern=marker[5::10,5::10]//255
for quad in [[[100,85],[144,82],[148,174],[104,177]],[[45,52],[90,55],[88,143],[43,140]]]:
    h=cv2.getPerspectiveTransform(np.float32([[0,0],[59,0],[59,59],[0,59]]),np.float32(quad))
    image=cv2.warpPerspective(marker,h,(200,240),flags=cv2.INTER_NEAREST,borderValue=255)>128
    for normalize in [False,True]:
        candidates=[]
        for y in range(2,226):
            edges=np.diff(np.r_[True,image[y],True].astype(int))
            for x,end in zip(np.where(edges==-1)[0],np.where(edges==1)[0]):
                w=end-x
                if not(12<=w<=190 and x>=2 and end<198):continue
                if not image[max(0,y-w//(2 if normalize else 6)),x+w//2]:continue
                probes=[x+w//12,x+w-1-w//12];bottom=[];top=[]
                for px in probes:
                    yy=y
                    while yy<238 and not image[yy,px]:yy+=1
                    bottom.append(yy)
                    yy=y
                    while yy>1 and not image[yy,px]:yy-=1
                    top.append(yy+int(image[yy,px]))
                cy=min(top) if normalize else y;ch=max(bottom)-cy
                if not(12<=ch and cy+ch<238 and ch*3>=w and ch<=w*3):continue
                if not(image[cy+ch//2,max(0,x-w//6)] and image[cy+ch//2,min(199,x+w+w//6)] and image[min(239,cy+ch+ch//12),x+w//2]):continue
                yy=cy+(2*np.arange(6)+1)*ch//12;xx=x+(2*np.arange(6)+1)*w//12
                cost=int((image[np.ix_(yy,xx)]!=pattern).sum())
                candidates.append((cost,int(x),int(cy),int(w),int(ch)))
        passing=[c for c in candidates if c[0]<=1]
        print({'quad':quad,'normalize':normalize,'passing':len(passing),'best':min(candidates) if candidates else None,
               'largest':max(passing,key=lambda c:c[3]*c[4]) if passing else None})
