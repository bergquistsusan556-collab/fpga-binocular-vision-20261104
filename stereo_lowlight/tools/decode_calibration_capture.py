"""Verify two complete identical reads, save native-coordinate checker corners."""
import argparse,csv,json,hashlib
from pathlib import Path
import cv2
import numpy as np

def read_pass(folder,number):
    values=np.full(96000,-1,dtype=np.int16)
    epochs=set()
    for file in sorted(folder.glob(f'pass_{number}_capture_*.csv')):
        with file.open(newline='') as stream:
            rows=csv.reader(stream);header=next(rows);next(rows)
            col=next(i for i,h in enumerate(header) if 'diagnostic_bus' in h)
            prev=None
            for row in rows:
                word=int(row[col],16)
                if word>>29!=7: raise ValueError(f'{file}: incomplete/invalid frame')
                epochs.add((word>>25)&15)
                addr=(word>>8)&131071;pixel=word&255
                if addr>=96000:raise ValueError('Address outside image')
                if prev is not None and addr!=(prev+1)%96000:raise ValueError('Address discontinuity')
                prev=addr
                if values[addr]>=0 and values[addr]!=pixel:raise ValueError('Frozen memory changed')
                values[addr]=pixel
    if len(epochs)!=1 or np.any(values<0):raise ValueError(f'Missing pixels / epochs: {epochs}, {(values<0).sum()}')
    return values.astype(np.uint8).reshape(240,400),next(iter(epochs))

def decode(root):
    result={'capture':str(root.resolve()),'sensor_exposures_synchronized':False,'views':{}}
    for name in ('fullfield','center_crop'):
        folder=root/name
        first,e1=read_pass(folder,0);second,e2=read_pass(folder,1)
        if e1!=e2 or not np.array_equal(first,second):raise ValueError('Repeat reads differ')
        cv2.imwrite(str(folder/'pair.png'),first)
        entry={'epoch':e1,'repeat_reads_identical':True,'sha256':hashlib.sha256(first.tobytes()).hexdigest(),'eyes':{}}
        for eye,image in (('left',first[:,:200]),('right',first[:,200:])):
            cv2.imwrite(str(folder/f'{eye}.png'),image)
            ok,corners=cv2.findChessboardCornersSB(image,(8,5),flags=cv2.CALIB_CB_EXHAUSTIVE|cv2.CALIB_CB_ACCURACY|cv2.CALIB_CB_NORMALIZE_IMAGE)
            view={'checker_found':bool(ok),'mean_gray':float(image.mean()),'min':int(image.min()),'max':int(image.max())}
            if ok:
                local=corners.reshape(-1,2)
                native=local*2 if name=='fullfield' else local+np.array([100,120])
                view['corners_image']=local.tolist();view['corners_native_400x480']=native.tolist()
                preview=cv2.cvtColor(image,cv2.COLOR_GRAY2BGR)
                cv2.drawChessboardCorners(preview,(8,5),corners,ok)
                cv2.imwrite(str(folder/f'{eye}_corners.png'),preview)
            entry['eyes'][eye]=view
        result['views'][name]=entry
    (root/'decoded.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({name:{eye:v['checker_found'] for eye,v in data['eyes'].items()} for name,data in result['views'].items()},ensure_ascii=False))
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('folder',type=Path)
    decode(parser.parse_args().folder)
