"""Isolated near-range build: preserve production RTL and all display algorithms."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
variant = root / 'variants/front_range_20261103/rtl'
variant.mkdir(parents=True, exist_ok=True)
original = (root / 'rtl/depth_roi.v').read_text(encoding='utf-8')
# Leave margin around 30/200cm so endpoint error is observable, not censored.
edited = original.replace('rounded_distance>=50&&rounded_distance<=300',
                          'rounded_distance>=25&&rounded_distance<=250')
edited = edited.replace('rounded_distance<50?4\'d4:rounded_distance>300?4\'d5',
                        'rounded_distance<25?4\'d4:rounded_distance>250?4\'d5')
assert edited != original and 'rounded_distance>=50' not in edited
(variant / 'depth_roi.v').write_text(edited, encoding='utf-8')
build = (root / 'tools/build.tcl').read_text(encoding='utf-8')
start = build.index('set out [file join $root build fusion]')
end = build.index('file mkdir $out', start)
build = build[:start] + 'set out [file join $root build front_range_20261103]\n' + build[end:]
build = build.replace('set skip {', 'set skip {depth_roi.v ', 1)
needle = 'read_verilog [list [file join $ip clk_wiz_0_1'
build = build.replace(needle,
    'read_verilog [list [file join $root variants front_range_20261103 rtl depth_roi.v]]\n' + needle, 1)
build = build.replace('CONFIG.C_PROBE_OUT0_INIT_VAL {0x0000}',
                      'CONFIG.C_PROBE_OUT0_INIT_VAL {0x00DB}')
build = build.replace('source [file join $root tools implement.tcl]',
                      'source [file join $root tools implement_front_range.tcl]')
(root / 'tools/build_front_range.tcl').write_text(build, encoding='utf-8')
impl = (root / 'tools/implement.tcl').read_text(encoding='utf-8')
start = impl.index('set diagnostic_width 480')
end = impl.index('set_property port_width', start)
impl = impl[:start] + 'set diagnostic_width 320\n' + impl[end:]
# First 256 bits keep existing layout; extra 64 bits are full ROI statistics.
impl = impl.replace('[format {diagnostic_bus[%d]} $i]',
                     '[format {diagnostic_bus[%d]} [expr {$i<256?$i:$i+128}]]')
(root / 'tools/implement_front_range.tcl').write_text(impl, encoding='utf-8')
sim = root / 'variants/front_range_20261103/sim'
sim.mkdir(parents=True, exist_ok=True)
tb = (root / 'sim/tb_roi_accuracy.v').read_text(encoding='utf-8')
tb = tb.replace('tb_roi_accuracy', 'tb_front_roi')
tb = tb.replace('0:expected=50;1:expected=75;2:expected=100;3:expected=150;4:expected=200;5:expected=300;',
                '0:expected=30;1:expected=50;2:expected=75;3:expected=100;4:expected=150;5:expected=200;')
tb = tb.replace('disparity=30;', 'disparity=50;')
tb = tb.replace('Beyond 3m ROI', 'Beyond guard ROI').replace('Closer than 0.5m ROI', 'Below guard ROI')
tb = tb.replace('0.5/0.75/1/1.5/2/3m', '0.3/0.5/0.75/1/1.5/2m')
(sim / 'tb_front_roi.v').write_text(tb, encoding='utf-8')
manifest = {'variant': 'front_range_20261103', 'calibrated': False,
    'test_range_cm': [30, 200], 'display_guard_cm': [25, 250], 'vio_initial': 219,
    'changes': ['Distance range guard only; arithmetic and matcher unchanged',
                'ILA 320 bits: compact health plus ROI statistics',
                'Initial VIO restores previously used fixed alignment'],
    'production_rtl_sha256': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in sorted((root / 'rtl').glob('*.v'))},
    'overrides': {'depth_roi.v': hashlib.sha256((variant / 'depth_roi.v').read_bytes()).hexdigest()}}
(variant.parent / 'source_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print('PREPARED_FRONT_RANGE: production files unchanged; no calibration applied')
