from pathlib import Path
import shutil,json,zipfile,hashlib
r=Path(__file__).resolve().parents[1];out=r/'build/distance_observer'
m=json.loads((out/'manifest.json').read_text())
assert all(hashlib.sha256((r/n).read_bytes()).hexdigest()==h for n,h in m['files_sha256'].items()),'Sources changed since manifest'
d=r/'baseline/distance_observer_20261024_2113';d.mkdir(exist_ok=False)
for name in ('fusion.bit','fusion.ltx','manifest.json','timing_pass.txt','decoded.json','hardware_verification.json'):
 shutil.copy2(out/name,d/name)
m=json.loads((out/'manifest.json').read_text())
with zipfile.ZipFile(d/'source.zip','x',zipfile.ZIP_DEFLATED) as z:
 for name in m['files_sha256']:
  if not name.startswith('build/'):z.write(r/name,name)
 for name in ('STATUS.md','DISTANCE_DIAGNOSIS.md'):z.write(r/name,name)
print(d)
