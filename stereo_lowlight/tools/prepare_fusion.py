from pathlib import Path
root=Path(__file__).resolve().parents[1]
def edit(name,pairs):
 p=root/name;b=p.read_bytes().replace(b'\r\n',b'\n')
 for a,c in pairs:
  a=a.encode('ascii');c=c.encode('ascii')
  if a in b:b=b.replace(a,c)
  elif c not in b:raise RuntimeError(f'Anchor missing: {name}: {a!r}')
 p.write_bytes(b)
edit('rtl/top_dual_ov5640_lcd.v',[
 ('mode_50m <= 3\'d0;',"mode_50m <= 3'd1;"),
 ("mode_50m <= {2'b0,~mode_50m[0]};","mode_50m <= mode_50m==3 ? 0 : mode_50m+1'b1;"),
 ('// Saved default 212/256 is the calibrated scale for this camera module.',
  '// Default 256/256 is UNCALIBRATED. KEY3 reverses the disparity search direction.'),
 ("filter_enable <= 1'b1;","filter_enable <= 1'b0;"),
 ("cal_scale <= 9'd212;","cal_scale <= 9'd256;"),
 ("cal_scale < 9'd256","cal_scale < 9'd508")])
edit('rtl/ddr3_fifo_ctrl.v',[
 ('if(!rst_n || wr_load) begin\n        wrdata_t <= 128\'d0;\n        byte_cnt <= 4\'d0;\n    end',
  "if(!rst_n) begin\n        wrdata_t <= 0; byte_cnt <= 0;\n    end\n    else if(wr_load || wfifo_rst_h) begin\n        wrdata_t <= 0; byte_cnt <= 0;\n    end"),
 ("if(!rst_n || wr_load || wfifo_rst_h)\n        wfifo_wren <= 1'b0;",
  "if(!rst_n)\n        wfifo_wren <= 1'b0;\n    else if(wr_load || wfifo_rst_h)\n        wfifo_wren <= 1'b0;")])
edit('constraints/pin.xdc',[
 ('create_clock -period 40.000 -name cmos_pclk_1','create_clock -period 20.833 -name cmos_pclk_1'),
 ('create_clock -period 40.000 -name cmos_pclk_2','create_clock -period 20.833 -name cmos_pclk_2')])
edit('rtl/distance_osd.v',[
 ("wire        osd_large = (h_disp >= 11'd600);","wire        osd_large = 1'b0;"),
 ("wire [4:0] fy_small = y[4:0] - 5'd2;","wire [4:0] fy_small = y[4:0] - OSD_Y - 5'd2;")])
print('Fusion controls and reset/clock fixes applied')
