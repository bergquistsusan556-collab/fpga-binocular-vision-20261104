"""Verify observable hardware facts; never infer physical accuracy without ground truth."""
from pathlib import Path
import json,sys,datetime,re
root=Path(__file__).resolve().parents[1]
selection=sys.argv[1] if len(sys.argv)>1 else 'fusion'
paired=bool(re.fullmatch(r'(?:roi_snapshot|robust_match)/frozen_frames/[0-9]{8}_[0-9]{6}/metrics',selection))
if not paired and selection not in ('fusion','watch','distance_observer','row_alignment/captures','row_alignment/selected','row_alignment/verified_boot','row_alignment_final/captures','row_alignment_final/selected','row_alignment_final/verified_boot','roi_snapshot/captures','roi_snapshot/selected','robust_match/captures','robust_match/selected'):raise SystemExit('Unknown capture set')
folder=root/'build'/('fusion/watch' if selection=='watch' else selection)
data=json.loads((folder/'decoded.json').read_text())
checks=[]
def check(name,passed,details):
    checks.append({'name':name,'pass':bool(passed),'details':details})
check('multiple_captures',len(data)>=3,len(data))
for i,d in enumerate(data):
    check(f'{i}:identities',d['chip1']==0x5640 and d['chip2']==0x5640 and d['lcd']==0x4384,
          [d['chip1'],d['chip2'],d['lcd']])
    check(f'{i}:initialization',(d['flags']&15)==15,d['flags'])
    check(f'{i}:capture_geometry',d['pixels1']==192000 and d['pixels2']==192000,[d['pixels1'],d['pixels2']])
    check(f'{i}:pixel_clocks',47<d['camera1_mhz']<49 and 47<d['camera2_mhz']<49,
          [d['camera1_mhz'],d['camera2_mhz']])
    check(f'{i}:output_pixels',d.get('display_pixels')==384000,d.get('display_pixels'))
    check(f'{i}:auto_exposure',d.get('aec_manual1')==0 and d.get('aec_manual2')==0 and
          d.get('aec_target1')==88 and d.get('aec_target2')==88,
          [d.get('aec_manual1'),d.get('aec_manual2'),d.get('aec_target1'),d.get('aec_target2')])
    a,b=d.get('raw_mean',0),d.get('enhanced_mean',0)
    if d.get('display_mode')==0:check(f'{i}:raw_bypass',a==b,[a,b])
    else:check(f'{i}:enhancement_brightness',b>=a-3 and (a<3 or a>80 or b>a+5),[a,b])
    if 'roi_reason' in d:
        reason=d['roi_reason'];pop=d['roi_population'];samples=d['roi_cluster_samples'];peak=d['roi_peak']
        check(f'{i}:roi_counters',0<=peak<=samples<=pop<=1681,[peak,samples,pop])
        explained={0:True,1:pop==0,2:samples<24 or peak<24,3:samples*2<pop,
                   4:d['distance_cm']<50,5:d['distance_cm']>300,
                   6:d['distance_valid'] and 50<=d['distance_cm']<=300}
        check(f'{i}:roi_diagnosis',explained.get(reason,False),reason)
for channel in (1,2):
    values=[d[f'frame{channel}'] for d in data]
    live=len(values)>1
    for a,b in zip(data,data[1:]):
        dt=((b['ticks_hi']-a['ticks_hi'])%65536)*65536/50_000_000
        delta=(b[f'frame{channel}']-a[f'frame{channel}'])%256
        error=abs((delta-dt*26.6666667+128)%256-128)
        live=live and delta!=0 and error<4
    check(f'camera{channel}:live',live,values)
check('changing_camera_data',all(len({d[f'hash{c}'] for d in data})>1 for c in (1,2)),
      [[d[f'hash{c}'] for d in data] for c in (1,2)])
frames=[d.get('display_frame_mod16',0) for d in data]
check('display_frames_live',len(frames)>1 and all((b-a)%16!=0 for a,b in zip(frames,frames[1:])),frames)
check('matching_candidates_produced',all(0<d.get('valid_matches',0)<=192000 for d in data),
      [d.get('valid_matches',0) for d in data])
result={'created':datetime.datetime.now().isoformat(),'passed':all(c['pass'] for c in checks),
 'checks':checks,'physical_depth_accuracy_verified':False,
 'limitations':['No calibrated focal length/rectification or measured target distance supplied.',
               'ILA cross-domain diagnostic snapshots are observations, not coherent frame transactions.']}
(folder/'hardware_verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
for c in checks:print(('PASS ' if c['pass'] else 'FAIL ')+c['name']+' '+str(c['details']))
print('HARDWARE_OBSERVATIONS_PASS' if result['passed'] else 'HARDWARE_OBSERVATIONS_FAIL')
sys.exit(0 if result['passed'] else 1)
