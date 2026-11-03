"""Save an exact immutable build with hash-checked sources before further edits."""
from pathlib import Path
import hashlib,json,shutil,sys,zipfile
r=Path(__file__).resolve().parents[1]
variant,name=sys.argv[1:]
assert variant.replace('_','').isalnum() and name.replace('_','').isalnum()
out=r/'build'/variant;dest=r/'baseline'/name
m=json.loads((out/'manifest.json').read_text())
for n,h in m['files_sha256'].items():
 assert hashlib.sha256((r/n).read_bytes()).hexdigest()==h,n
dest.mkdir(exist_ok=False)
for n in ('fusion.bit','fusion.ltx','manifest.json','timing_pass.txt','timing.rpt','utilization.rpt','drc.rpt'):
 shutil.copy2(out/n,dest/n)
with zipfile.ZipFile(dest/'source.zip','x',zipfile.ZIP_DEFLATED) as z:
 for n in m['files_sha256']:
  if not n.startswith('build/') or n.endswith('.xci'):z.write(r/n,n)
with zipfile.ZipFile(dest/'source.zip') as z:
 for n in z.namelist():assert hashlib.sha256(z.read(n)).hexdigest()==m['files_sha256'][n],n
print('Verified immutable source and bitstream archive:',dest)
