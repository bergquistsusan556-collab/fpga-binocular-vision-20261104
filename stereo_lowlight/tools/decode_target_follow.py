"""Decode actual named net ranges, without assuming CSV column ordering."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import re
from front_range_summary import ungray

def decode(path):
    with path.open(newline='',encoding='utf-8-sig') as stream:table=list(csv.reader(stream))
    assert len(table[2:])==1024,'Incomplete ILA capture'
    diagnostic=tracking=0
    covered=set();track_covered=set()
    for index,name in enumerate(table[0]):
        if 'diagnostic_bus' not in name and 'tracking_diagnostic' not in name:continue
        match=re.search(r'\[(\d+):(\d+)\]',name)
        assert match,f'Unexpected probe name: {name}'
        high,low=map(int,match.groups())
        value=int(table[2][index],16)
        if 'tracking_diagnostic' in name:
            tracking|=value<<low;track_covered.update(range(low,high+1))
        else:
            diagnostic|=value<<low;covered.update(range(low,high+1))
    required=set(range(72))|set(range(104,144))|set(range(208,232))|set(range(384,448))
    assert covered in [required,required|set(range(448,480))]
    assert track_covered==set(range(56))
    bits=lambda off,n:(diagnostic>>off)&((1<<n)-1)
    tb=lambda off,n:(tracking>>off)&((1<<n)-1)
    identity=(bits(0,4)==15 and [bits(8,16),bits(24,16),bits(40,16)]==[0x5640,0x5640,0x4384]
              and bits(104,20)==bits(124,20)==192000)
    n=bits(400,12);weighted=bits(424,20)
    return {'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'hardware_identity_ok':identity,'frame1':ungray(bits(56,8)),'frame2':ungray(bits(64,8)),
            'target_valid':bool(tb(0,1)),'box_right_analysis':[tb(8,8),tb(16,8),tb(24,8),tb(32,8)],
            'effective_alignment_row':tb(1,5) if tb(1,7) else None,
            'alignment_searching':bool(tb(6,1)) if tb(1,7) else None,
            'alignment_ready':bool(tb(7,1)) if tb(1,7) else None,
            'tracking_epoch':tb(40,8),'following_mode':bool(tb(48,1)),'rotation_quarters':tb(49,2),
            'follow_roi_in_frame':bool(tb(51,1)) if 448 in covered else None,
            'measured_roi_on_target':bool(tb(52,1)) if 448 in covered else None,
            'roi_internal_valid':bool(tb(53,1)) if 448 in covered else None,
            'raw_distance_cm':bits(214,16),'distance_valid':bool(bits(230,1)),
            'dominant_disparity':bits(208,6),'roi_reason':bits(384,4),
            'roi_population':bits(388,12),'roi_cluster':n,'roi_peak':bits(412,12),
            'mean_disparity_px':weighted/n if n else None}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('folder',type=Path);args=parser.parse_args()
    files=sorted(args.folder.glob('capture_*.csv'),key=lambda path:int(re.search(r'capture_(\d+)',path.name).group(1)))
    assert len(files)>=3
    samples=[decode(path) for path in files]
    positions=[s['box_right_analysis'] for s in samples if s['target_valid']]
    span=[max(p[k] for p in positions)-min(p[k] for p in positions) if positions else 0 for k in [0,1]]
    lost=[i for i,s in enumerate(samples) if not s['target_valid']]
    reacquired=any(any(s['target_valid'] for s in samples[i+1:]) for i in lost)
    result={'samples':samples,'hardware_checks_passed':all(s['hardware_identity_ok'] for s in samples),
            'cameras_advancing':all(a['frame1']!=b['frame1'] and a['frame2']!=b['frame2'] for a,b in zip(samples,samples[1:])),
            'tracking_updates_advancing':all(a['tracking_epoch']!=b['tracking_epoch'] for a,b in zip(samples,samples[1:])),
            'target_found_count':sum(s['target_valid'] for s in samples),
            'target_distance_valid_count':sum(s['target_valid'] and s['distance_valid'] for s in samples),
            'box_span_analysis_xy':span,'loss_then_reacquisition_observed':reacquired,
            'all_lost_samples_cleared_distance':all(not samples[i]['distance_valid'] and samples[i]['raw_distance_cm']==0 for i in lost),
            'dynamic_following_verified':False,'distance_accuracy_verified_by_this_capture':False}
    (args.folder/'decoded.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
