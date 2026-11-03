"""Seal checked tracking sources and implementation before JTAG programming."""
from pathlib import Path
import datetime
import hashlib
import json
import re

root=Path(__file__).resolve().parents[1]
variant=root/'variants/target_follow_20261103'
out=root/'build/target_follow_20261103'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
manifest=json.loads((variant/'source_manifest.json').read_text(encoding='utf-8'))
for name,value in manifest['production_rtl_sha256'].items():
    assert sha(root/name)==value,f'Production source changed: {name}'
for name,value in manifest['overrides_sha256'].items():
    assert sha(variant/'rtl'/name)==value,f'Prepared override changed: {name}'
old=root/'variants/front_fit_20261103/rtl'
assert sha(variant/'rtl/stereo_census.v')==sha(old/'stereo_census.v')
assert sha(variant/'rtl/depth_roi.v')==sha(old/'depth_roi.v')
before=(old/'depth_roi.v').read_text()
after=(variant/'rtl/depth_roi_follow.v').read_text()
for parameter in ['CAL_A_Q8','CAL_B_Q8','MIN_SAMPLES']:
    assert re.search(parameter+r'=(\d+)',before).group(1)==re.search(parameter+r'=(\d+)',after).group(1)
tests=[]
for name in ['tb_marker7','tb_raw_detection','tb_follow_roi','tb_follow_alignment','tb_follow_association','tb_follow_pipeline','tb_pipeline','tb_video_pipeline','tb_video_tools','tb_lcd_system']:
    record=json.loads((variant/'sim'/f'{name}_result.json').read_text())
    assert record['passed']
    for source,value in record['source_sha256'].items():
        assert sha(root/source)==value,f'Stale test {name}: {source}'
    if 'fixture_sha256' in record:assert sha(variant/'sim/marker_frames.hex')==record['fixture_sha256']
    tests.append(name)
timing=(out/'timing_pass.txt').read_text().strip()
assert all(float(value)>=0 for value in re.findall(r'=(\S+)',timing))
result={'created':datetime.datetime.now().astimezone().isoformat(),
        'variant':'target_follow_20261103','range_coefficients_unchanged':True,
        'production_rtl_unchanged':len(manifest['production_rtl_sha256']),
        'tests':tests,'timing':timing,
        'rtl_sha256':{p.name:sha(p) for p in sorted((variant/'rtl').glob('*.v'))},
        'artifact_sha256':{p.name:sha(p) for p in [out/'fusion.bit',out/'fusion.ltx',out/'synthesized.dcp']},
        'physical_following_verified':False,'dynamic_distance_accuracy_verified':False}
(out/'verified_sources.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
