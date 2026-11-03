from pathlib import Path
import json
import statistics
import sys
from decode_target_follow import decode

folder=Path(sys.argv[1]);rows=[]
for directory in sorted(folder.glob('row_*'),key=lambda p:int(p.name.split('_')[1])):
    samples=[decode(p) for p in sorted(directory.glob('capture_*.csv'))]
    good=[s for s in samples if s['target_valid']]
    internal=[s for s in good if s['roi_internal_valid']]
    rows.append({'row':int(directory.name.split('_')[1]),'target_found':len(good),
                 'internal_valid':len(internal),'display_valid':sum(s['distance_valid'] for s in samples),
                 'raw_cm':[s['raw_distance_cm'] for s in samples],
                 'reasons':[s['roi_reason'] for s in samples],
                 'boxes':[s['box_right_analysis'] for s in samples],
                 'peaks':[s['roi_peak'] for s in samples],
                 'cluster_fraction':[round(s['roi_cluster']/s['roi_population'],3) if s['roi_population'] else 0 for s in samples],
                 'samples':samples})
report={'original_control_restored_by_capture_script':True,
        'scope':'Temporary row diagnostic, same unknown fixed target distance; no new range fit or acceptance.',
        'rows':rows}
(folder/'summary.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps([{k:v for k,v in r.items() if k!='samples'} for r in rows],indent=2))
