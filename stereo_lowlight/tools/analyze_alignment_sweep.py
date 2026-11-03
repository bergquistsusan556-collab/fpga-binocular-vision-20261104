from pathlib import Path
import subprocess,sys,json,statistics,csv
r=Path(__file__).resolve().parents[1];sweep=r/'build/row_alignment/sweep';results=[]
for d in sorted(sweep.glob('control_*')):
 subprocess.run([sys.executable,'-X','utf8',str(r/'tools/decode_capture.py'),str(d.relative_to(r/'build'))],check=True,stdout=subprocess.DEVNULL)
 a=json.loads((d/'decoded.json').read_text());control=int(d.name.split('_')[1])
 results.append({'control':control,'rows':control&31,'reverse':bool(control&64),
  'valid_frames':sum(v['distance_valid'] for v in a),'frames':len(a),
  'median_population':statistics.median(v['roi_population'] for v in a),
  'median_samples':statistics.median(v['roi_cluster_samples'] for v in a),
  'median_cluster_fraction':round(statistics.median(v['roi_cluster_samples']/max(1,v['roi_population']) for v in a),3),
  'dominant':[v['dominant_disparity'] for v in a],'cm':[v['distance_cm'] for v in a],
  'reasons':[v['roi_reason'] for v in a]})
(sweep/'summary.json').write_text(json.dumps(results,indent=2))
for v in sorted(results,key=lambda v:-v['median_cluster_fraction']):print(v)
