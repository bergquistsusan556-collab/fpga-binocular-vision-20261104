"""Compact ILA checks only observable facts; never infer LCD appearance or accuracy."""
from pathlib import Path
import json,sys,datetime
r=Path(__file__).resolve().parents[1]
folder=r/'build/video_fusion'/('selected' if len(sys.argv)<2 else sys.argv[1])
data=json.loads((folder/'decoded.json').read_text())
checks=[]
def check(name,passed,details):checks.append(dict(name=name,passed=bool(passed),details=details))
check('at_least_3_captures',len(data)>=3,len(data))
for i,d in enumerate(data):
 check(f'{i}:device_identity',[d['chip1'],d['chip2'],d['lcd']]==[0x5640,0x5640,0x4384],
       [d['chip1'],d['chip2'],d['lcd']])
 check(f'{i}:initialization',d['flags']&15==15,d['flags'])
 check(f'{i}:two_camera_pixel_counts',d['pixels1']==192000 and d['pixels2']==192000,[d['pixels1'],d['pixels2']])
 check(f'{i}:camera_clocks',all(47<d[f'camera{c}_mhz']<49 for c in (1,2)),[d[f'camera{c}_mhz'] for c in (1,2)])
 check(f'{i}:auto_exposure',d['aec_manual1']==d['aec_manual2']==0 and d['aec_target1']==d['aec_target2']==88,
       [d['aec_manual1'],d['aec_manual2'],d['aec_target1'],d['aec_target2']])
for c in (1,2):
 live=len(data)>1
 for a,b in zip(data,data[1:]):
  dt=((b['ticks_hi']-a['ticks_hi'])%65536)*65536/50_000_000
  delta=(b[f'frame{c}']-a[f'frame{c}'])%256
  live=live and delta!=0 and abs((delta-dt*26.6666667+128)%256-128)<4
 check(f'camera{c}:frames_advance',live,[d[f'frame{c}'] for d in data])
 check(f'camera{c}:pixel_data_changes',len({d[f'hash{c}'] for d in data})>1,[d[f'hash{c}'] for d in data])
check('ddr_read_stream_changes',len({d['read_hash'] for d in data})>1,[d['read_hash'] for d in data])
result=dict(created=datetime.datetime.now().isoformat(),passed=all(c['passed'] for c in checks),checks=checks,
 physical_accuracy_verified=False,new_modes_visually_verified=False,
 limitations=['Compact probe does not measure output DE count or enhanced image brightness.',
 'Algorithm correctness/latency tested in simulation; screen appearance still requires visual observation.'])
(folder/'hardware_verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
for c in checks:print(('PASS ' if c['passed'] else 'FAIL ')+c['name']+' '+str(c['details']))
raise SystemExit(0 if result['passed'] else 1)
