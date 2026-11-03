from pathlib import Path
import shutil,json,zipfile,hashlib
r=Path(__file__).resolve().parents[1];out=r/'build/row_alignment'
m=json.loads((out/'manifest.json').read_text())
assert all(hashlib.sha256((r/n).read_bytes()).hexdigest()==h for n,h in m['files_sha256'].items())
d=r/'baseline/row_alignment_diagnostic_20261024_2251';d.mkdir(exist_ok=False)
for n in ('fusion.bit','fusion.ltx','manifest.json','timing_pass.txt'):shutil.copy2(out/n,d/n)
with zipfile.ZipFile(d/'source.zip','x',zipfile.ZIP_DEFLATED) as z:
 for n in m['files_sha256']:
  if not n.startswith('build/') or n.endswith('.xci'):z.write(r/n,n)
print('Exact diagnostic source/bit snapshot verified and saved',d)
