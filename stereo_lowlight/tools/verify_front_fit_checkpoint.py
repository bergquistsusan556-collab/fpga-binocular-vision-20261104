"""Record tested sources and all 200cm outcomes without claiming full-range accuracy."""
from pathlib import Path
import datetime
import hashlib
import json

root = Path(__file__).resolve().parents[1]
variant = root / 'variants/front_fit_20261103'
build = root / 'build/front_fit_20261103'
data = root / 'calibration/frontal_20261103'
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
manifest = json.loads((variant / 'source_manifest.json').read_text(encoding='utf-8'))
for name, expected in manifest['production_rtl_sha256'].items():
    assert digest(root / name) == expected, f'Production source changed: {name}'
for name, expected in manifest['overrides_sha256'].items():
    assert digest(variant / 'rtl' / name) == expected, f'Override changed: {name}'
tests = []
for filename in ['test_summary.json', 'integration_test_summary.json']:
    record = json.loads((variant / 'sim' / filename).read_text(encoding='utf-8'))
    for test in record['tests']:
        assert test['passed']
        for name, expected in test['source_sha256'].items():
            assert digest(root / name) == expected, f'Stale simulation: {name}'
        tests.append(test['test'])
program_log = (root / 'build/front_fit_200cm_retest_console.log').read_text(encoding='utf-8', errors='replace')
assert 'DONE_PIN=1' in program_log and 'FRONTAL_RANGE_CAPTURE_OK=' in program_log
groups = {}
for name in ['r200_v1', 'r200_fit_v1', 'r200_fit_settled_v2']:
    group = json.loads((data / name / 'group.json').read_text(encoding='utf-8'))
    for sample in group['samples']:
        assert digest(data / name / sample['file']) == sample['sha256']
    groups[name] = {key: group[key] for key in ['reference_distance_cm',
        'raw_register_readings_cm', 'display_valid_count', 'median_cm',
        'median_error_cm', 'max_abs_error_cm', 'group_all_three_within_2cm']}
result = {
    'created': datetime.datetime.now().astimezone().isoformat(),
    'current_board_build': 'front_fit_20261103', 'jtag_done_verified': True,
    'programming': 'JTAG RAM only; no Flash', 'vio': 219,
    'production_files_unchanged': len(manifest['production_rtl_sha256']),
    'tested_candidate_sources_unchanged': True, 'fresh_passed_simulations': tests,
    'timing': (build / 'timing_pass.txt').read_text().strip(),
    'artifact_sha256': {name: digest(build / name) for name in ['fusion.bit', 'fusion.ltx', 'synthesized.dcp', 'timing_pass.txt']},
    'all_200cm_groups': groups,
    'median_200cm_error_goal_met_in_later_batch': True,
    'all_200cm_reads_within_2cm': False,
    'startup_and_long_term_stability_verified': False,
    'whole_30_to_200cm_accuracy_verified': False,
    'observer_experiment': '352-bit build failed BRAM 101/100; never programmed',
    'next_step': 'User fixes frontal target at 150cm; collect three reads without reprogramming.'
}
(data / 'front_fit_checkpoint.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
