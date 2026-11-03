"""Verify unchanged video modes using the isolated calibrated RTL overrides."""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
variant = root / 'variants/front_fit_20261103'
sim = variant / 'sim'
binpath = Path('C:/Xilinx/Vivado/2019.1/bin')
pipeline = ['binary_template32', 'video_tools', 'stream_features', 'luma_histogram',
            'lowlight_fixed', 'stereo_row_align', 'stereo_census', 'depth_frame',
            'depth_roi', 'distance_osd', 'video_diagnostics', 'fusion_pipeline']
tests = {'tb_pipeline': pipeline, 'tb_video_pipeline': pipeline,
         'tb_lcd_system': pipeline + ['stereo_observer', 'lcd_clock_800',
                                      'lcd_driver', 'rd_id', 'lcd_rgb_top']}
results = []
for name, modules in tests.items():
    sources = []
    for module in modules:
        override = variant / 'rtl' / f'{module}.v'
        sources.append(override if override.exists() else root / 'rtl' / f'{module}.v')
    sources.append(root / 'sim' / f'{name}.v')
    for tool, args in [('xvlog', [str(s) for s in sources]),
                       ('xelab', [name, '-s', name + '_fit_sim', '-timescale', '1ns/1ps']),
                       ('xsim', [name + '_fit_sim', '-runall'])]:
        p = subprocess.run([str(binpath / (tool + '.bat')), *args], cwd=sim,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log = p.stdout.decode('utf-8', errors='replace')
        (sim / f'{name}_fit_{tool}.log').write_text(log, encoding='utf-8')
        if p.returncode or 'FATAL' in log.upper() or 'ERROR:' in log:
            print(log); sys.exit(1)
        if tool == 'xsim':
            if 'PASS ' not in log:
                print(log); sys.exit(1)
            print(next(line for line in log.splitlines() if 'PASS ' in line), flush=True)
    results.append({'test': name, 'passed': True,
                    'source_sha256': {str(s.relative_to(root)): hashlib.sha256(s.read_bytes()).hexdigest()
                                      for s in sources}})
(sim / 'integration_test_summary.json').write_text(json.dumps({
    'created': datetime.datetime.now().isoformat(), 'tests': results,
    'physical_accuracy_verified': False}, indent=2), encoding='utf-8')
