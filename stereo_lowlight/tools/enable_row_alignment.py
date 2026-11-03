from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=r/'rtl/top_dual_ov5640_lcd.v';b=p.read_bytes().replace(b'\r\n',b'\n')
for a,c in [
 ('wire [95:0] video_extra;','wire [95:0] video_extra;\nwire [15:0] diagnostic_control;\nstereo_control u_stereo_control(.clk(clk_50m),.probe_out0(diagnostic_control));'),
 ('.diagnostic_extra      (video_extra),','.diagnostic_extra      (video_extra),\n    .diagnostic_control    (diagnostic_control),')]:
 if a.encode() in b:b=b.replace(a.encode(),c.encode())
 elif c.encode() not in b:raise ValueError(a)
p.write_bytes(b)
p=r/'sim/tb_pipeline.v';s=p.read_text().replace('disp,unused_metrics,roi_debug);',"disp,unused_metrics,roi_debug,8'd0);");p.write_text(s)
p=r/'sim/tb_lcd_system.v';s=p.read_text().replace('.diagnostic_metrics(metrics),',".diagnostic_control(16'd0),.diagnostic_metrics(metrics),");p.write_text(s)
print('Enabled frame-latched row alignment and JTAG diagnostic control')
