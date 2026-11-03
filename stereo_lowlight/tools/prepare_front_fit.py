"""Fit measured frontal references and prepare an isolated provisional FPGA build."""
from pathlib import Path
import hashlib
import json
import statistics

root = Path(__file__).resolve().parents[1]
data = root / 'calibration/frontal_20261103'
points = []
for folder in ('r030_v1', 'r050_v1', 'r100_texture_v1', 'r150_v1', 'r200_v1'):
    path = data / folder / 'group.json'
    g = json.loads(path.read_text(encoding='utf-8'))
    points.append({'folder': folder, 'actual_cm': g['reference_distance_cm'],
                   'raw_cm': g['raw_register_readings_cm'],
                   'median_disparity_px': statistics.median(s['mean_disparity_px'] for s in g['samples']),
                   'fit_eligible': g['eligible_for_disparity_fit'],
                   'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
training = [p for p in points if p['fit_eligible']]
assert len(training) == 3
# Z = A / (d + B). Optimize the largest median range residual, in cm.
# B is searched on the actual Q8 lattice used by RTL. No target-specific LUT.
best = None
for b_q8 in range(1, 40 * 256 + 1):
    b = b_q8 / 256
    terms = [(p['actual_cm'], p['median_disparity_px'] + b) for p in training]
    error = max(abs(z * t - other_z * other_t) / (t + other_t)
                for z, t in terms for other_z, other_t in terms)
    low = max((z - error) * t for z, t in terms)
    high = min((z + error) * t for z, t in terms)
    a_q8 = round((low + high) * 128)
    residual = max(abs(a_q8 / 256 / t - z) for z, t in terms)
    candidate = (residual, a_q8, b_q8)
    if best is None or candidate < best:
        best = candidate
error, a_q8, b_q8 = best
for p in points:
    p['provisional_prediction_cm'] = a_q8 / (p['median_disparity_px'] * 256 + b_q8)
    p['provisional_residual_cm'] = p['provisional_prediction_cm'] - p['actual_cm']
    p['prediction_is_usable'] = p['fit_eligible']
fit = {'model': 'Z_cm = A_Q8 / (256*d + B_Q8)', 'A_Q8': a_q8, 'B_Q8': b_q8,
       'A_cm_px': a_q8 / 256, 'B_px': b_q8 / 256,
       'objective': 'minimax range residual on three group median disparities',
       'max_training_median_residual_cm': error, 'points': points,
       'independent_accuracy_verified': False, 'whole_range_verified': False,
       'notes': ['30cm reference retained; search-boundary disparity excluded from fitting',
                 '200cm reference retained; dispersed old matching excluded from fitting',
                 'Training residuals are not independent accuracy measurements']}
(data / 'provisional_fit.json').write_text(json.dumps(fit, ensure_ascii=False, indent=2), encoding='utf-8')

variant = root / 'variants/front_fit_20261103'
(variant / 'rtl').mkdir(parents=True, exist_ok=True)
roi = (root / 'variants/front_range_20261103/rtl/depth_roi.v').read_text(encoding='utf-8')
roi = roi.replace('parameter integer MIN_SAMPLES=24',
    f'parameter integer MIN_SAMPLES=24,\n parameter integer CAL_A_Q8={a_q8}, CAL_B_Q8={b_q8}')
roi = roi.replace('reg [19:0] divisor;', 'reg [31:0] divisor;')
roi = roi.replace('{14\'d0,divisor}', "{2'd0,divisor}")
roi = roi.replace('&&disp!=0&&hist[disp]!=4095', '&&hist[disp]!=4095')
roi = roi.replace('if(sof)begin pos<=1;', 'if(sof)begin pos<=0;')
roi = roi.replace('if(pos!=0 && (', 'if((')
roi = roi.replace('&&weighted!=0)begin', ')begin')
roi = roi.replace('samples*(FOCAL_PX*BASELINE_MM/10)*scale', 'samples*CAL_A_Q8*scale')
roi = roi.replace('divisor<=weighted;', 'divisor<=({12\'d0,weighted}<<8)+samples*CAL_B_Q8;')
roi = roi.replace('// ROI dominant disparity +/-1 bins; fractional mean via count/weighted sum.',
    '// Provisional frontal calibration: Z=A/(d+B); zero disparity may be valid.\n'
    '// Parameters derived from three ruler-reference groups; see provisional_fit.json.')
assert 'weighted!=0' not in roi and 'disp!=0' not in roi and 'if(pos!=0' not in roi
(variant / 'rtl/depth_roi.v').write_text(roi, encoding='utf-8')
matcher = (root / 'rtl/stereo_census.v').read_text(encoding='utf-8')
matcher = matcher.replace('d=1..63', 'd=0..63')
matcher = matcher.replace('((d==0)||(reverse ?', '((reverse ?')
matcher = matcher.replace('&&(index[0]!=0)', '')
assert '(d==0)' not in matcher and '(index[0]!=0)' not in matcher
(variant / 'rtl/stereo_census.v').write_text(matcher, encoding='utf-8')
build = (root / 'tools/build_front_range.tcl').read_text(encoding='utf-8')
build = build.replace('front_range_20261103', 'front_fit_20261103')
build = build.replace('set skip {depth_roi.v ', 'set skip {stereo_census.v depth_roi.v ')
build = build.replace('read_verilog [list [file join $root variants front_fit_20261103 rtl depth_roi.v]]',
    'foreach f [glob [file join $root variants front_fit_20261103 rtl *.v]] {read_verilog [list $f]}')
build = build.replace('implement_front_range.tcl', 'implement_front_fit.tcl')
(root / 'tools/build_front_fit.tcl').write_text(build, encoding='utf-8')
(root / 'tools/implement_front_fit.tcl').write_text(
    (root / 'tools/implement_front_range.tcl').read_text(encoding='utf-8'), encoding='utf-8')
manifest = {'variant': 'front_fit_20261103', 'calibration_status': 'provisional_three_point_fit',
            'fit': fit, 'vio_initial': 219,
            'production_rtl_sha256': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                                      for p in sorted((root / 'rtl').glob('*.v'))},
            'overrides_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in sorted((variant / 'rtl').glob('*.v'))}}
(variant / 'source_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'A_Q8': a_q8, 'B_Q8': b_q8, 'training_median_max_error_cm': error,
                  'independent_accuracy_verified': False}, ensure_ascii=False))
