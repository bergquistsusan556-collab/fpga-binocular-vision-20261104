"""Record measured-image evidence, without fitting or applying calibration."""
import argparse,hashlib,json
from pathlib import Path

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def record(folder):
    root=Path(__file__).resolve().parents[1]
    decoded=json.loads((folder/'decoded.json').read_text(encoding='utf-8'))
    archive=json.loads((root/'baseline/video_fusion_checked_20261028/manifest.json').read_text(encoding='utf-8'))
    checked={name:sha(root/name)==digest for name,digest in archive['files_sha256'].items()
             if name.startswith('rtl/') and (root/name).is_file()}
    if not checked or not all(checked.values()):raise ValueError('Production RTL changed relative to checked video baseline')
    checks={k:bool(v['checker_found'] and v['repeat_reads_identical']) for k,v in decoded['views'].items()}
    entry={'capture':str(folder.resolve()),'image_evidence':decoded,
           'native_checker_candidate':all(checks.values()) and decoded.get('stationarity',{}).get('passes_endpoint_check',False),
           'board':{'inner_corners':[8,5],'nominal_square_mm':20,'actual_print_scale_verified':False},
           'actual_range_mm':None,'baseline_nominal_mm':32,
           'calibration_fit_applied':False,'production_rtl_files_identical_to_checked_video_baseline':len(checked),
           'build_timing':(root/'build/calibration_native/timing_pass.txt').read_text().strip(),
           'sha256':{}}
    paths=[root/'build/calibration_native'/name for name in ('fusion.bit','fusion.ltx')]
    paths+=list((root/'variants/calibration_native/rtl').glob('*.v'))
    paths+=[root/'tools/calibration_native_hw.tcl',root/'tools/decode_calibration_native.py']
    entry['sha256']={str(path.relative_to(root)):sha(path) for path in paths}
    out=root/'calibration/target_v1/poses'/f'{folder.name}.json';out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(entry,indent=2,ensure_ascii=False),encoding='utf-8')
    print(json.dumps({'record':str(out),'candidate':entry['native_checker_candidate'],'production_rtl_verified':len(checked)},ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('folder',type=Path);record(p.parse_args().folder)
