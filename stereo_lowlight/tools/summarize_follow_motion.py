"""Explain each displayed invalid result using captured hardware gates."""
from pathlib import Path
from collections import Counter
import json
import sys
import numpy as np
from decode_target_follow import decode

folder=Path(sys.argv[1]);files=sorted(folder.glob('capture_*.csv'),key=lambda p:int(p.stem.split('_')[-1]))
samples=[decode(p) for p in files]
reasons=Counter();timeline=[]
for s in samples:
    if s['distance_valid']:reason='valid'
    elif not s['target_valid']:reason='tag_not_detected'
    elif not s['follow_roi_in_frame']:reason='texture_roi_outside_frame'
    elif not s['roi_internal_valid']:reason=f"matcher_or_histogram_{s['roi_reason']}"
    elif not s['measured_roi_on_target']:reason='old_roi_outside_current_texture'
    elif not s['alignment_ready']:reason='alignment_search_or_settle'
    else:reason='other'
    reasons[reason]+=1
    timeline.append({'file':s['file'],'reason':reason,'box':s['box_right_analysis'],
                     'cm':s['raw_distance_cm'],'row':s['effective_alignment_row'],
                     'peak':s['roi_peak'],'population':s['roi_population']})
valid=[s for s in samples if s['target_valid'] and s['distance_valid']]
distances=[s['raw_distance_cm'] for s in valid]
inverse_sizes=[1/np.sqrt(s['box_right_analysis'][2]*s['box_right_analysis'][3]) for s in valid]
correlation=None
if len(valid)>=3 and np.std(distances)>0 and np.std(inverse_sizes)>0:
    correlation=float(np.corrcoef(distances,inverse_sizes)[0,1])
result={'scope':'Hardware behavior evidence only; no ruler ground truth, no dynamic accuracy claim.',
        'count':len(samples),'gate_counts':dict(reasons),
        'valid_distance_range_cm':[min(distances),max(distances)] if distances else None,
        'range_vs_inverse_marker_size_correlation':correlation,'timeline':timeline}
(folder/'motion_summary.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='timeline'},indent=2))
for s in timeline:print(f"{s['file']}: {s['reason']}; box={s['box']}; cm={s['cm']}; row={s['row']}")
