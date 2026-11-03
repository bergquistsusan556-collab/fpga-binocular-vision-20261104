from pathlib import Path
import hashlib,json,shutil,zipfile,datetime
dest=Path(__file__).resolve().parent
r=dest.parents[1]
archive=r/'baseline/video_fusion_checked_20261028'
m=json.loads((archive/'manifest.json').read_text())
for name,digest in m['files_sha256'].items():
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest,name
with zipfile.ZipFile(archive/'source.zip') as z:
 for name in z.namelist():assert hashlib.sha256(z.read(name)).hexdigest()==m['files_sha256'][name],name
for name in ('README.md','STATUS.md','VIDEO_FUSION.md'):
 shutil.copy2(r/name,dest/name)
for name in ('captures','selected'):
 shutil.copytree(r/'build/video_fusion'/name,dest/name)
shutil.copy2(r/'sim/test_summary.json',dest/'test_summary.json')
for name in ('video_fusion_program_checked.log','video_fusion_restore_alignment.log'):
 shutil.copy2(r/'build'/name,dest/name)
for name in ('tb_video_tools','tb_template32','tb_video_pipeline','tb_pipeline','tb_lcd_system'):
 shutil.copy2(r/'sim'/f'{name}_xsim.log',dest/f'{name}_xsim.log')
state=dict(created=datetime.datetime.now().isoformat(),variant='video_fusion',programmed=True,
 flash_written=False,vio_control=219,default_mode=1,test_count=21,
 wns_ns=.994,whs_ns=.052,luts=18214,bram_tiles=46,
 new_modes_visually_verified=False,physical_accuracy_verified=False,
 archive=str(archive.relative_to(r)))
(dest/'state.json').write_text(json.dumps(state,indent=2),encoding='utf-8')
hashes={str(p.relative_to(dest)):hashlib.sha256(p.read_bytes()).hexdigest()
        for p in dest.rglob('*') if p.is_file() and p.name!='evidence_sha256.json'}
(dest/'evidence_sha256.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
print('SOURCE_ARCHIVE_AND_EVIDENCE_VERIFIED',len(hashes),'files')
