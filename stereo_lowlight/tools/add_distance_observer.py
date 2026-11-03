from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'rtl/top_dual_ov5640_lcd.v'
b=p.read_bytes().replace(b'\r\n',b'\n')
for old,new in [
 ('wire [24:0] video_status;','wire [24:0] video_status;\nwire [95:0] video_extra;'),
 ('.diagnostic_status     (video_status),','.diagnostic_status     (video_status),\n    .diagnostic_extra      (video_extra),'),
 ('wire [383:0] diagnostic_bus;','wire [479:0] diagnostic_bus;'),
 ('assign diagnostic_bus={sensor_debug2','assign diagnostic_bus={video_extra,sensor_debug2')]:
 if old.encode() in b:b=b.replace(old.encode(),new.encode())
 elif new.encode() not in b:raise ValueError(old)
p.write_bytes(b)
for name,old,new in [
 ('tb_roi_accuracy.v','cm,dv,dom);','cm,dv,dom,roi_debug);'),
 ('tb_frames.v','cm,dv,dom);','cm,dv,dom,roi_debug);'),
 ('tb_stereo_scene.v','cm,dv,dominant);','cm,dv,dominant,roi_debug);'),
 ('tb_pipeline.v','disp,unused_metrics);','disp,unused_metrics,roi_debug);')]:
 p=root/'sim'/name;s=p.read_text()
 if old in s:s=s.replace(old,new).replace('module '+p.stem+';','module '+p.stem+';\n wire [63:0] roi_debug;')
 elif new not in s:raise ValueError(name)
 p.write_text(s)
print('Added diagnostic-only ROI and thumbnail taps')
