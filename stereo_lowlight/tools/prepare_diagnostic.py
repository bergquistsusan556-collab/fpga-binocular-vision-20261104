from pathlib import Path

root=Path(__file__).resolve().parents[1]
rtl=root/'rtl'
def edit(name,old,new):
 p=rtl/name
 b=p.read_bytes().replace(b'\r\n',b'\n');o=old.encode('ascii').replace(b'\r\n',b'\n');n=new.encode('ascii').replace(b'\r\n',b'\n')
 if n in b: return
 if o not in b: raise RuntimeError(f'Missing anchor {name}: {old[:60]}')
 p.write_bytes(b.replace(o,n))

# Save sensor identity read from SCCB during initialisation.
edit('i2c_ov5640_rgb565_cfg.v','output  reg          init_done',
     'output reg [15:0] sensor_id,\r\n    output  reg          init_done')
edit('i2c_ov5640_rgb565_cfg.v','//parameter define', '''always @(posedge clk or negedge rst_n) begin
 if(!rst_n) sensor_id<=0;
 else if(i2c_done && init_reg_cnt==1) sensor_id[15:8]<=i2c_data_r;
 else if(i2c_done && init_reg_cnt==2) sensor_id[7:0]<=i2c_data_r;
end
//parameter define''')
edit('ov5640_dri.v','output          cam_init_done',
     'output [15:0] sensor_id,\r\n    output          cam_init_done')
edit('ov5640_dri.v','.init_done          (cam_init_done)',
     '.sensor_id          (sensor_id),\r\n    .init_done          (cam_init_done)')
edit('ov5640_dri.v','assign  cam_rst_n = 1\'b1;', "assign  cam_rst_n = rst_n;")
edit('ov5640_dri.v','cmos_capture_data u_cmos_capture_data(', '''(* ASYNC_REG="TRUE" *) reg [1:0] capture_sync;
always @(posedge cam_pclk or negedge rst_n)
 if(!rst_n) capture_sync<=0;
 else capture_sync<={capture_sync[0],capture_start & cam_init_done};
cmos_capture_data u_cmos_capture_data(''')
edit('ov5640_dri.v','rst_n & capture_start','rst_n & capture_sync[1]')

# Reset byte packing on every frame, not just on FPGA reset.
edit('ddr3_fifo_ctrl.v','if(!rst_n) begin\r\n        wrdata_t',
     'if(!rst_n || wr_load) begin\r\n        wrdata_t')
edit('ddr3_fifo_ctrl.v',"if(!rst_n)\r\n        wfifo_wren <= 1'b0;",
     "if(!rst_n || wr_load || wfifo_rst_h)\r\n        wfifo_wren <= 1'b0;")
edit('ddr3_fifo_ctrl.v',"rd_load_d <= 1'b0;", "rd_load_d <= 16'd0;")

top=rtl/'top_dual_ov5640_lcd.v'
b=top.read_bytes()
b=b.replace(b'wire         lcd_de                    ;',b'wire         rd_vsync;\r\nwire [15:0] chip_id1,chip_id2;\r\nwire cfg_done1,cfg_done2;\r\nwire         lcd_de                    ;')
b=b.replace(b'.cmos_frame_href   (),',b'.cam_init_done     (cfg_done1),\r\n    .sensor_id         (chip_id1),\r\n    .cmos_frame_href   (),',1)
idx=b.find(b'.cmos_frame_href   (),',b.find(b'ov5640_dri u_ov5640_dri_2'))
b=b[:idx]+b[idx:].replace(b'.cmos_frame_href   (),',b'.cam_init_done     (cfg_done2),\r\n    .sensor_id         (chip_id2),\r\n    .cmos_frame_href   (),',1)
b=b.replace(b'mode_50m <= mode_50m + 1\'b1;',b'mode_50m <= {2\'b0,~mode_50m[0]};')
b=b.replace(b'.filter_enable         (filter_enable),',b'.filter_enable         (filter_enable),\r\n    .activity1             (fg1_s2),\r\n    .activity2             (fg2_s2),\r\n    .heartbeat             (diag_ticks[23]),')
monitor='''
wire [7:0] fg1,fg2;
wire [15:0] cg1,cg2,fh1,fh2;
wire [19:0] fp1,fp2;
camera_activity u_activity1(cam_pclk_1,rst_n,cam_vsync_1,cmos_frame_valid_1,wr_data_1,fg1,cg1,fp1,fh1);
camera_activity u_activity2(cam_pclk_2,rst_n,cam_vsync_2,cmos_frame_valid_2,wr_data_2,fg2,cg2,fp2,fh2);
(* ASYNC_REG="TRUE" *) reg [7:0] fg1_s1,fg1_s2,fg2_s1,fg2_s2;
(* ASYNC_REG="TRUE" *) reg [15:0] cg1_s1,cg1_s2,cg2_s1,cg2_s2;
(* ASYNC_REG="TRUE" *) reg [5:0] cam_io_s1,cam_io_s2;
reg [31:0] diag_ticks;
reg [15:0] read_hash;
always @(posedge clk_50m or negedge rst_n) begin
 if(!rst_n)begin
  fg1_s1<=0;fg1_s2<=0;fg2_s1<=0;fg2_s2<=0;
  cg1_s1<=0;cg1_s2<=0;cg2_s1<=0;cg2_s2<=0;
  cam_io_s1<=0;cam_io_s2<=0;diag_ticks<=0;
 end else begin
  fg1_s1<=fg1;fg1_s2<=fg1_s1;fg2_s1<=fg2;fg2_s2<=fg2_s1;
  cg1_s1<=cg1;cg1_s2<=cg1_s1;cg2_s1<=cg2;cg2_s2<=cg2_s1;
  cam_io_s1<={cam_href_2,cam_href_1,cam_vsync_2,cam_vsync_1,cfg_done2,cfg_done1};
  cam_io_s2<=cam_io_s1;diag_ticks<=diag_ticks+1'b1;
 end
end
always @(posedge lcd_clk or negedge rst_n)
 if(!rst_n)read_hash<=0;
 else if(rd_vsync)read_hash<=0;
 else if(rdata_req)read_hash<={read_hash[14:0],read_hash[15]}^rddata;
(* MARK_DEBUG="TRUE",KEEP="TRUE" *) wire [255:0] diagnostic_bus;
assign diagnostic_bus={13'd0,u_ddr3_top.u_ddr3_rw.app_addr,
 u_ddr3_top.u_ddr3_rw.state_cnt,diag_ticks[31:16],read_hash,fh2,fh1,fp2,fp1,
 cg2_s2,cg1_s2,fg2_s2,fg1_s2,lcd_id,chip_id2,chip_id1,
 cam_io_s2[5:2],rst_n,cam_io_s2[1:0],init_calib_complete};
'''
# Check hierarchy names before elaboration; the bus records diagnostic state only.
b=b.replace(b'\r\nendmodule',monitor.encode('ascii')+b'\r\nendmodule')
top.write_bytes(b)

# Two independent input clocks must have different names.
p=root/'constraints'/'pin.xdc';b=p.read_bytes()
b=b.replace(b'-name cmos_pclk [get_ports cam_pclk_1]',b'-name cmos_pclk_1 [get_ports cam_pclk_1]')
b=b.replace(b'-name cmos_pclk [get_ports cam_pclk_2]',b'-name cmos_pclk_2 [get_ports cam_pclk_2]')
p.write_bytes(b)
