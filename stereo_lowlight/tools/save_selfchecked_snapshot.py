from pathlib import Path
import shutil,json,zipfile
root=Path(__file__).resolve().parents[1]
out=root/'build/fusion'
dest=root/'baseline/fusion_selfchecked_20261024_2051'
dest.mkdir(exist_ok=False)
for name in ('fusion.bit','fusion.ltx','manifest.json','timing_pass.txt','decoded.json','hardware_verification.json',
             'timing.rpt','utilization.rpt','drc.rpt'):
    shutil.copy2(out/name,dest/name)
for name in ('SELF_VERIFICATION.md','STATUS.md','README.md'):
    shutil.copy2(root/name,dest/name)
shutil.copy2(root/'sim/test_summary.json',dest/'test_summary.json')
if (out/'watch/hardware_verification.json').exists():
    (dest/'watch').mkdir()
    for name in ('hardware_verification.json','decoded.json'):
        shutil.copy2(out/'watch'/name,dest/'watch'/name)
manifest=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
sources={root/p for p in manifest['files_sha256'] if not p.startswith('build/')}
sources.update((root/'tools').glob('*.py'));sources.update((root/'tools').glob('*.tcl'))
sources.update(root/'sim'/name for name in ('lowlight_reference.txt','reference_summary.json'))
sources.update(root/name for name in ('README.md','STATUS.md','SELF_VERIFICATION.md'))
with zipfile.ZipFile(dest/'source.zip','x',compression=zipfile.ZIP_DEFLATED) as z:
    for p in sorted(sources):
        if p.is_file():z.write(p,p.relative_to(root).as_posix())
print(dest)
