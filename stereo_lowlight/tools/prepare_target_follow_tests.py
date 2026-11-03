"""Create detector fixtures from OpenCV's dictionary, independently of RTL ROM."""
from pathlib import Path
import sys
import zipfile
import numpy as np

root=Path(__file__).resolve().parents[1]
try:
    import cv2
except ModuleNotFoundError:
    local=root/'tmp/target_follow_opencv'
    wheel=root/'.cache/opencv_contrib_python_headless-4.11.0.86-cp37-abi3-win_amd64.whl'
    if not (local/'cv2').exists():
        with zipfile.ZipFile(wheel) as archive:archive.extractall(local)
    sys.path.insert(0,str(local))
    import cv2
sim=root/'variants/target_follow_20261103/sim'
dictionary=cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
cases=[[],[(80,80,48,48,0,7)],[(39,51,48,48,0,7)],[(20,21,132,156,0,7)],
       [(129,130,24,36,0,7)],[(50,60,36,24,1,7)],[(60,60,48,48,0,8)],
       [(20,20,36,36,0,7),(130,160,36,36,0,7)],[],[(70,40,60,96,2,7)],
       [(30,45,48,60,3,7)],[(40,40,48,96,3,44)],[(40,40,48,96,3,45)],[(70,70,48,72,0,7)],[],[]]
payload=cv2.aruco.generateImageMarker(dictionary,7,60)[15:50:10,15:50:10]//255
minimum_other=min(int((payload-np.rot90(cv2.aruco.generateImageMarker(dictionary,ident,60)[15:50:10,15:50:10]//255,rot)!=0).sum())
                  for ident in range(50) if ident!=7 for rot in range(4))
assert minimum_other>=4,'One-bit correction would not be safe for this dictionary ID'
with (sim/'marker_frames.hex').open('w') as stream:
    for number,marks in enumerate(cases):
        image=np.ones((240,200),dtype=np.uint8)
        for x,y,w,h,rot,ident in marks:
            marker=cv2.aruco.generateImageMarker(dictionary,ident,60)
            marker=np.rot90(marker,-rot)
            image[y:y+h,x:x+w]=cv2.resize(marker,(w,h),interpolation=cv2.INTER_NEAREST)//255
        if number==13:image[82:94,78:86]^=1 # one interior cell corrupted
        if number in [14,15]:
            quad=([[100,85],[144,82],[148,174],[104,177]] if number==14 else
                  [[45,52],[90,55],[88,143],[43,140]])
            transform=cv2.getPerspectiveTransform(np.float32([[0,0],[59,0],[59,59],[0,59]]),np.float32(quad))
            image=cv2.warpPerspective(cv2.aruco.generateImageMarker(dictionary,7,60),transform,(200,240),
                                      flags=cv2.INTER_NEAREST,borderValue=255)//255
            _,decoded,_=cv2.aruco.ArucoDetector(dictionary).detectMarkers(image*255)
            assert decoded is not None and decoded.ravel().tolist()==[7]
        stream.write('\n'.join(map(str,image.ravel()))+'\n')
# Original binary/edge/motion assertions run against the extended sidecar interface.
bench=(root/'sim/tb_video_tools.v').read_text()
bench=bench.replace('video_tools dut(clk,rst,sof,de,x,y,rgb,mode,out);',
    'video_tools dut(.clk(clk),.rst_n(rst),.sof(sof),.de(de),.x(x),.y(y),.rgb(rgb),.mode(mode),.processed(out));')
(sim/'tb_video_tools.v').write_text(bench)
print('OpenCV detector fixtures and unchanged display assertions prepared')
