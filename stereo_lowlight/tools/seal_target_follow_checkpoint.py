"""Save the exact checked tracking bitstream, sources and evidence references."""
from pathlib import Path
import datetime
import hashlib
import json
import shutil
import zipfile

root=Path(__file__).resolve().parents[1]
out=root/'build/target_follow_20261103'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
verified=json.loads((out/'verified_sources.json').read_text(encoding='utf-8'))
for name,digest in verified['artifact_sha256'].items():assert sha(out/name)==digest
for name,digest in verified['rtl_sha256'].items():assert sha(root/'variants/target_follow_20261103/rtl'/name)==digest
folder=root/'checkpoints'/('target_follow_checked_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'))
folder.mkdir()
for name in ['fusion.bit','fusion.ltx','verified_sources.json','timing_pass.txt','timing.rpt','utilization.rpt','drc.rpt']:
    shutil.copy2(out/name,folder/name)
physical=out/'physical_verification.json'
if physical.exists():shutil.copy2(physical,folder/physical.name)
files=set((root/'rtl').glob('*.v'))|set((root/'sim').glob('*.v'))|set((root/'constraints').glob('*'))
files|=set((root/'variants/target_follow_20261103/rtl').glob('*.v'))
files|=set((root/'variants/front_fit_20261103/rtl').glob('*.v'))
files|=set((root/'variants/target_follow_20261103/sim').glob('tb_*.v'))
files|=set((root/'variants/target_follow_20261103/sim').glob('*_result.json'))
files|=set((root/'tools').glob('*target_follow*'))
files|={root/'tools/build_front_fit.tcl',root/'tools/implement_front_fit.tcl',
        root/'variants/target_follow_20261103/source_manifest.json',
        root/'variants/target_follow_20261103/sim/marker_frames.hex',
        root/'calibration/frontal_20261103/provisional_fit.json',
        root/'TARGET_FOLLOW.md',root/'STATUS.md'}
with zipfile.ZipFile(folder/'source_snapshot.zip','w',zipfile.ZIP_DEFLATED) as archive:
    for p in sorted(files):
        if p.is_file():archive.write(p,str(p.relative_to(root)))
manifest={'created':datetime.datetime.now().astimezone().isoformat(),
          'variant':'target_follow_20261103','jtag_ram_only':True,
          'default_mode':7,'vio_base_control':219,
          'ip_dependencies':'Rebuild uses the preserved project ip/ directory; this zip is a source snapshot.',
          'files':{p.name:sha(p) for p in folder.iterdir() if p.is_file()},
          'hardware_evidence':{str(p.relative_to(root)):sha(p) for p in sorted((out/'hardware').glob('*/decoded.json'))}}
(folder/'checkpoint.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(folder)
