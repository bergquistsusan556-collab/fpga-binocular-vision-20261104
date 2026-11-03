"""Run isolated numerical and correspondence tests before candidate implementation."""
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
tests = [('tb_front_fit_roi', ['depth_roi'], ['tb_front_fit_roi.v']),
         ('tb_front_fit_match', ['stereo_census'], ['tb_front_fit_match.v']),
         ('tb_front_fit_reverse', ['stereo_census'], ['tb_front_fit_match.v'])]
results = []
for name, modules, benches in tests:
    sources = [variant / 'rtl' / f'{m}.v' for m in modules] + [sim / b for b in benches]
    commands = [('xvlog', [str(s) for s in sources]),
                ('xelab', [name, '-s', name + '_sim', '-timescale', '1ns/1ps']),
                ('xsim', [name + '_sim', '-runall'])]
    for tool, args in commands:
        p = subprocess.run([str(binpath / (tool + '.bat')), *args], cwd=sim,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log = p.stdout.decode('utf-8', errors='replace')
        (sim / f'{name}_{tool}.log').write_text(log, encoding='utf-8')
        if p.returncode or 'FATAL' in log or 'ERROR:' in log:
            print(log);sys.exit(1)
        if tool == 'xsim':
            if 'PASS ' not in log:
                print(log);sys.exit(1)
            print(next(line for line in log.splitlines() if 'PASS ' in line), flush=True)
    results.append({'test': name, 'passed': True,
                    'source_sha256': {str(s.relative_to(root)): hashlib.sha256(s.read_bytes()).hexdigest()
                                      for s in sources}})
(sim / 'test_summary.json').write_text(json.dumps({'created': datetime.datetime.now().isoformat(),
    'tests': results, 'physical_accuracy_verified': False}, indent=2), encoding='utf-8')
