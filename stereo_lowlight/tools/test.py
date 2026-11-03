from pathlib import Path
import subprocess, sys, json, datetime
root=Path(__file__).resolve().parents[1]
sim=root/'sim'
bin=Path(r'C:\Xilinx\Vivado\2019.1\bin')
tests={
 'tb_video_tools':['binary_template32','video_tools'],
 'tb_template32':['binary_template32'],
 'tb_observer':['stereo_observer'],
 'tb_row_align':['stereo_row_align'],
 'tb_alignment_scene':['stream_features','stereo_row_align','stereo_census','depth_roi'],
 'tb_sensor_brightness':['i2c_ov5640_rgb565_cfg'],
 'tb_lowlight':['lowlight_fixed'],
 'tb_lowlight_reference':['lowlight_fixed'],
 'tb_algorithms':['stereo_census'],
 'tb_reverse':['stereo_census'],
 'tb_features':['stream_features'],
 'tb_stereo_scene':['stream_features','stereo_census','depth_roi'],
 'tb_stereo_degraded':['stream_features','stereo_census','depth_roi'],
 'tb_frames':['luma_histogram','depth_frame','depth_roi'],
 'tb_depth_map':['depth_frame'],
 'tb_roi_accuracy':['depth_roi'],
 'tb_fifo_pack':['ddr3_fifo_ctrl'],
 'tb_frame_cdc':['ddr3_rw'],
 'tb_pipeline':['stream_features','luma_histogram','lowlight_fixed','stereo_row_align','stereo_census','depth_frame','depth_roi','distance_osd','video_diagnostics','fusion_pipeline'],
 'tb_lcd_system':['stream_features','luma_histogram','lowlight_fixed','stereo_row_align','stereo_census','depth_frame','depth_roi','distance_osd','video_diagnostics','fusion_pipeline','stereo_observer','lcd_clock_800','lcd_driver','rd_id','lcd_rgb_top'],
}
selected=sys.argv[1:] or list(tests)
for tb in ('tb_pipeline','tb_lcd_system'):
 tests[tb]=['binary_template32','video_tools']+tests[tb]
tests['tb_video_pipeline']=tests['tb_pipeline']
# Default selection must include the integration case registered above.
if not sys.argv[1:]:selected=list(tests)
if any(tb not in tests for tb in selected):raise SystemExit('Unknown test name')
for tb in selected:
 modules=tests[tb]
 cmds=[['xvlog',*[str(root/'rtl'/f'{m}.v') for m in modules],f'{tb}.v'],
       ['xelab',tb,'-s',tb+'_sim','-timescale','1ns/1ps'],['xsim',tb+'_sim','-runall']]
 for name,*args in cmds:
  p=subprocess.run([str(bin/f'{name}.bat'),*args],cwd=sim,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  log=p.stdout.decode('utf-8',errors='replace')
  (sim/f'{tb}_{name}.log').write_text(log,encoding='utf-8')
  if p.returncode or 'FATAL' in log.upper() or 'ERROR:' in log:
   print(log);sys.exit(1)
  if name=='xsim':
   if 'PASS' not in log:print(log);sys.exit(1)
   print(next(line for line in log.splitlines() if 'PASS' in line),flush=True)
results=[]
for tb,modules in tests.items():
 path=sim/f'{tb}_xsim.log'
 sources=[sim/f'{tb}.v',*[root/'rtl'/f'{m}.v' for m in modules]]
 if tb=='tb_stereo_degraded':sources += [sim/'degraded_rgb565.hex',sim/'degraded_texture.png',root/'tools/generate_degraded_scene.py']
 log=path.read_text(encoding='utf-8') if path.exists() else ''
 fresh=path.exists() and all(p.stat().st_mtime<=path.stat().st_mtime for p in sources)
 results.append({'name':tb,'fresh':fresh,'passed':fresh and 'PASS' in log and 'FATAL' not in log.upper(),
                 'result':next((s for s in log.splitlines() if 'PASS' in s),'')})
(sim/'test_summary.json').write_text(json.dumps({'created':datetime.datetime.now().isoformat(),
 'all_passed':all(r['passed'] for r in results),'tests':results},indent=2),encoding='utf-8')
print('ALL_TESTS_PASS' if all(r['passed'] for r in results) else 'SELECTED_TESTS_PASS; other results need refresh')
