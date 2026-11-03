from pathlib import Path
import hashlib,json,datetime,sys
root=Path(__file__).resolve().parents[1]
variant=sys.argv[1] if len(sys.argv)>1 else 'fusion'
if variant not in ('fusion','brightness','distance_observer','row_alignment','row_alignment_final','roi_snapshot','robust_match','video_fusion'):raise SystemExit('Unknown build variant')
out=root/'build'/variant
if not (out/'timing_pass.txt').exists():raise SystemExit(f'No timing signoff for {variant} build')
source=root/'variants/brightness/rtl' if variant=='brightness' else root/'rtl'
bit_name='fusion' if variant in ('distance_observer','row_alignment','row_alignment_final','roi_snapshot','robust_match','video_fusion') else variant
paths=list(source.glob('*.v'))+list((root/'constraints').glob('*'))+[out/(bit_name+'.bit'),out/(bit_name+'.ltx')]
if variant in ('fusion','distance_observer','row_alignment','row_alignment_final','roi_snapshot','robust_match','video_fusion'):
 paths += [root/'tools/build.tcl',root/'tools/implement.tcl',root/'tools/test.py',root/'sim/test_summary.json',
           root/'tools/capture_fusion.tcl',root/'tools/decode_capture.py',root/'tools/verify_hardware_capture.py']
 paths += list((root/'sim').glob('tb_*.v'))+[root/'tools/generate_reference_vectors.py']
 paths += [root/'ip/rd_fifo/rd_fifo.xci',root/'ip/wr_fifo/wr_fifo.xci']
 paths += list((root/'ip/clk_wiz_0_1').glob('*.v'))
 paths += list((root/'ip/mig_7series_0/mig_7series_0/user_design/rtl').rglob('*.v'))
 paths += list((root/'ip/mig_7series_0/mig_7series_0/user_design/constraints').glob('*.xdc'))
 paths += list((root/'tools').glob('*.py'))+list((root/'tools').glob('*.tcl'))
 if variant.startswith('row_alignment') or variant in ('roi_snapshot','robust_match','video_fusion'):paths += list((out/'generated_ip').rglob('*.xci'))
 if variant in ('robust_match','video_fusion'):paths += [root/'sim/degraded_texture.png',root/'sim/degraded_rgb565.hex',root/'sim/degraded_scene_metadata.json']
if variant=='brightness':paths += [root/'tools/prepare_brightness.py',root/'tools/build_brightness.tcl',root/'variants/brightness/implement.tcl']
record={str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()}
(out/'manifest.json').write_text(json.dumps({'created':datetime.datetime.now().isoformat(),
 'variant':variant,'baseline_mm':32,'calibrated':False,'files_sha256':record},ensure_ascii=False,indent=2),encoding='utf-8')
print('Saved source/bitstream SHA256 manifest')
