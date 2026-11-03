from pathlib import Path
root=Path(__file__).resolve().parents[1]
def edit(name,a,c):
 p=root/name;b=p.read_bytes().replace(b'\r\n',b'\n');a=a.encode();c=c.encode()
 if a not in b:
  if c in b:return
  raise RuntimeError(f'Missing {name}: {a[:60]}')
 p.write_bytes(b.replace(a,c))
edit('rtl/top_dual_ov5640_lcd.v','wire [15:0] chip_id1,chip_id2;','wire [15:0] chip_id1,chip_id2;\nwire [63:0] sensor_debug1,sensor_debug2;\nwire [95:0] video_metrics;\nwire [24:0] video_status;')
for n in (1,2):
 edit('rtl/top_dual_ov5640_lcd.v',f'.sensor_id         (chip_id{n}),',f'.sensor_id         (chip_id{n}),\n    .sensor_debug      (sensor_debug{n}),')
edit('rtl/top_dual_ov5640_lcd.v','.data_req              (rdata_req)', '.diagnostic_metrics    (video_metrics),\n    .diagnostic_status     (video_status),\n    .data_req              (rdata_req)')
edit('rtl/top_dual_ov5640_lcd.v','wire [255:0] diagnostic_bus;','wire [383:0] diagnostic_bus;')
edit('rtl/top_dual_ov5640_lcd.v',"assign diagnostic_bus={13'd0,u_ddr3_top.u_ddr3_rw.app_addr,\n u_ddr3_top.u_ddr3_rw.state_cnt,diag_ticks[31:16]", "assign diagnostic_bus={sensor_debug2[47:40],sensor_debug1[47:40],\n sensor_debug2[55:48],sensor_debug1[55:48],video_metrics,\n 3'd0,sensor_debug2[1:0],sensor_debug1[1:0],sensor_debug2[63:56],sensor_debug1[63:56],\n video_status,diag_ticks[31:16]")
edit('tools/implement.tcl','port_width 256','port_width 384')
edit('tools/implement.tcl','{$i<256}','{$i<384}')
edit('constraints/pin.xdc','IOB TRUE','IOB FALSE')
print('Merged verified exposure and frame diagnostics into fusion')
