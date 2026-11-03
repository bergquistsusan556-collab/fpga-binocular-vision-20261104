"""Decode full native 400x480 single-eye grayscale snapshots and stationarity check."""
import argparse,csv,json,hashlib
from pathlib import Path
import cv2
import numpy as np

def read_pass(folder,number):
    words=np.full(64000,-1,dtype=np.int64);epochs=set();eyes=set()
    for file in sorted(folder.glob(f'pass_{number}_capture_*.csv')):
        with file.open(newline='') as stream:
            rows=csv.reader(stream);header=next(rows);next(rows)
            col=next(i for i,h in enumerate(header) if 'diagnostic_bus' in h)
            previous=None
            for row in rows:
                sample=int(row[col],16)
                if sample>>44!=13:raise ValueError(f'{file}: invalid/incomplete frame')
                epochs.add((sample>>40)&15);eyes.add((sample>>39)&1)
                addr=(sample>>18)&65535;word=sample&262143
                if addr>=64000:raise ValueError('Address outside frame')
                if previous is not None and addr!=(previous+1)%64000:raise ValueError('Address discontinuity')
                previous=addr
                if words[addr]>=0 and words[addr]!=word:raise ValueError('Frozen memory changed')
                words[addr]=word
    if len(epochs)!=1 or len(eyes)!=1 or np.any(words<0):raise ValueError('Incomplete image or mixed epochs/eyes')
    pixels=np.stack([(words>>(6*p))&63 for p in range(3)],axis=1).reshape(480,400).astype(np.uint8)
    # Restore monotonic 0..255 display range; capture itself retains 6 bits.
    image=(pixels<<2)|(pixels>>4)
    return image,next(iter(epochs)),next(iter(eyes))

def checker(image):
    ok,corners=cv2.findChessboardCornersSB(image,(8,5),flags=cv2.CALIB_CB_EXHAUSTIVE|cv2.CALIB_CB_ACCURACY|cv2.CALIB_CB_NORMALIZE_IMAGE)
    if not ok:return None
    corners=corners.reshape(-1,2)
    # Board held roughly upright: choose the upper-left end consistently.
    if corners[0].sum()>corners[-1].sum():corners=corners[::-1].copy()
    return corners

def decode(root):
    result={'capture':str(root.resolve()),'native_size':[400,480],'luminance_bits':6,
            'sensor_exposures_synchronized':False,'sequential_static_capture':True,'views':{}}
    detected={};previews={}
    for name,eye in (('left',0),('right',1),('left_check',0)):
        folder=root/name
        image,e1,eye1=read_pass(folder,0);second,e2,eye2=read_pass(folder,1)
        if e1!=e2 or eye1!=eye or eye2!=eye or not np.array_equal(image,second):raise ValueError('Repeat reads/eye differ')
        cv2.imwrite(str(root/f'{name}.png'),image)
        corners=checker(image)
        view={'epoch':e1,'eye':eye,'repeat_reads_identical':True,'checker_found':corners is not None,
              'sha256':hashlib.sha256(image.tobytes()).hexdigest(),'mean_gray':float(image.mean())}
        if corners is not None:
            detected[name]=corners
            view['corners_native_400x480']=corners.tolist()
            preview=cv2.cvtColor(image,cv2.COLOR_GRAY2BGR)
            cv2.drawChessboardCorners(preview,(8,5),corners.reshape(-1,1,2),True)
            cv2.imwrite(str(root/f'{name}_corners.png'),preview)
            previews[name]=preview
        result['views'][name]=view
    if 'left' in previews and 'right' in previews:
        pair=np.hstack((previews['left'],previews['right']))
        cv2.putText(pair,'LEFT',(8,22),cv2.FONT_HERSHEY_SIMPLEX,0.6,(0,0,255),2)
        cv2.putText(pair,'RIGHT',(408,22),cv2.FONT_HERSHEY_SIMPLEX,0.6,(0,0,255),2)
        cv2.imwrite(str(root/'pair_corners.png'),pair)
    if all(name in detected for name in ('left','right','left_check')):
        drift=np.linalg.norm(detected['left']-detected['left_check'],axis=1)
        result['stationarity']={'rms_px':float(np.sqrt(np.mean(drift**2))),'max_px':float(drift.max()),
                                'max_allowed_px':0.35,'passes_endpoint_check':bool(drift.max()<=0.35),
                                'limitation':'Endpoint check does not prove no motion between the exposures.'}
        result['raw_corner_offset']={'median_x_left_minus_right':float(np.median(detected['left'][:,0]-detected['right'][:,0])),
                                    'median_y_left_minus_right':float(np.median(detected['left'][:,1]-detected['right'][:,1]))}
    (root/'decoded.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({'checker_found':{k:v['checker_found'] for k,v in result['views'].items()},'stationarity':result.get('stationarity')},ensure_ascii=False))
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('folder',type=Path);decode(p.parse_args().folder)
