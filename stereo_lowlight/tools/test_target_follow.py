"""Run only relevant isolated tracker, range and video integration checks."""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
variant=root/'variants/target_follow_20261103'
sim=variant/'sim'
binpath=Path('C:/Xilinx/Vivado/2019.1/bin')
pipeline=['marker7_tracker','follow_row_tuner','video_tools','stream_features','luma_histogram','lowlight_fixed',
          'stereo_row_align','stereo_census','depth_frame','depth_roi_follow','distance_osd','video_diagnostics','fusion_pipeline']
tests={'tb_marker7':['marker7_tracker'],'tb_follow_roi':['depth_roi_follow'],'tb_follow_alignment':['follow_row_tuner'],
       'tb_raw_detection':['marker7_tracker','video_tools'],
       'tb_follow_pipeline':pipeline,'tb_follow_association':pipeline,
       'tb_video_tools':['marker7_tracker','video_tools'],'tb_pipeline':pipeline,'tb_video_pipeline':pipeline,
       'tb_lcd_system':pipeline+['stereo_observer','lcd_clock_800','lcd_driver','rd_id','lcd_rgb_top']}
selected=sys.argv[1:] or list(tests)
for name in selected:
    modules=tests[name]
    sources=[]
    for module in modules:
        override=variant/'rtl'/f'{module}.v'
        sources.append(override if override.exists() else root/'rtl'/f'{module}.v')
    bench=sim/f'{name}.v'
    sources.append(bench if bench.exists() else root/'sim'/f'{name}.v')
    before={str(s.relative_to(root)):hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
    fixture_before=hashlib.sha256((sim/'marker_frames.hex').read_bytes()).hexdigest()
    for tool,args in [('xvlog',[str(s) for s in sources]),
                      ('xelab',[name,'-s',name+'_follow_sim','-timescale','1ns/1ps']),
                      ('xsim',[name+'_follow_sim','-runall'])]:
        p=subprocess.run([str(binpath/(tool+'.bat')),*args],cwd=sim,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        log=p.stdout.decode('utf-8',errors='replace')
        (sim/f'{name}_{tool}.log').write_text(log,encoding='utf-8')
        if p.returncode or 'FATAL' in log.upper() or 'ERROR:' in log or (tool=='xsim' and 'PASS ' not in log):
            print(log);sys.exit(1)
        if tool=='xsim':print(next(line for line in log.splitlines() if 'PASS ' in line),flush=True)
    after={str(s.relative_to(root)):hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
    assert before==after,'RTL or bench changed during simulation; rerun required'
    record={'test':name,'passed':True,'created':datetime.datetime.now().astimezone().isoformat(),
            'source_sha256':before}
    if name in ['tb_marker7','tb_follow_pipeline','tb_raw_detection']:
        assert fixture_before==hashlib.sha256((sim/'marker_frames.hex').read_bytes()).hexdigest()
        record['fixture_sha256']=fixture_before
    (sim/f'{name}_result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
