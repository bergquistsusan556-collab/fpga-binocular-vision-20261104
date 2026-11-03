"""Build a separate raw-video diagnostic variant; never overwrite known-good RTL/bit."""
from pathlib import Path
import re,zipfile
root=Path(__file__).resolve().parents[1]
dst=root/'variants'/'brightness'/'rtl'
dst.mkdir(parents=True,exist_ok=True)
# Once exposure fixes are in the fusion tree, reconstruct the diagnostic variant
# from the user-confirmed source snapshot rather than applying the fixes twice.
archive=root/'baseline/confirmed_brightness_20261024/source.zip'
if archive.exists() and b'sensor_debug' in (root/'rtl/i2c_ov5640_rgb565_cfg.v').read_bytes():
    with zipfile.ZipFile(archive) as z:
        for entry in z.infolist():
            parts=Path(entry.filename).parts
            if len(parts)==2 and parts[0]=='rtl' and parts[1].endswith('.v'):
                (dst/parts[1]).write_bytes(z.read(entry))
    build=(root/'tools/build.tcl').read_text().replace('build fusion','build brightness')
    build=build.replace('[file join $root rtl *.v]','[file join $root variants brightness rtl *.v]')
    build=build.replace('set skip {','set skip {fusion_pipeline.v stream_features.v luma_histogram.v lowlight_fixed.v stereo_census.v depth_frame.v depth_roi.v distance_osd.v ')
    build=build.replace('source [file join $root tools implement.tcl]','source [file join $root variants brightness implement.tcl]')
    (root/'tools/build_brightness.tcl').write_text(build)
    impl=(root/'tools/implement.tcl').read_text().replace('fusion.ltx','brightness.ltx').replace('fusion.bit','brightness.bit')
    (dst.parent/'implement.tcl').write_text(impl)
    print(f'Restored confirmed diagnostic sources: {dst}')
    raise SystemExit(0)
for p in (root/'rtl').glob('*.v'):
    (dst/p.name).write_bytes(p.read_bytes())
(dst/'lcd_rgb_top.v').write_bytes((root/'baseline'/'lcd_rgb_top_diagnostic.v').read_bytes())
def edit(name,old,new):
    p=dst/name;b=p.read_bytes().replace(b'\r\n',b'\n')
    a=old.encode('ascii');c=new.encode('ascii')
    if a not in b:raise RuntimeError(f'{name}: missing {old[:60]}')
    p.write_bytes(b.replace(a,c))
edit('lcd_rgb_top.v','clk_div divider(sys_clk,sys_rst_n,lcd_id,lcd_clk);','lcd_clock_800 divider(sys_clk,sys_rst_n,lcd_clk);')
edit('top_dual_ov5640_lcd.v',"mode_50m <= 3'd1;","mode_50m <= 3'd0;")
edit('top_dual_ov5640_lcd.v',"mode_50m <= mode_50m==3 ? 0 : mode_50m+1'b1;","mode_50m <= {2'b0,~mode_50m[0]};")
edit('i2c_ov5640_rgb565_cfg.v','output reg [15:0] sensor_id,','output reg [15:0] sensor_id,\n    output reg [63:0] sensor_debug,')
edit('i2c_ov5640_rgb565_cfg.v',"REG_NUM = 8'd250","REG_NUM = 8'd251")
edit('i2c_ov5640_rgb565_cfg.v','reg   [12:0]   start_init_cnt;','reg   [14:0]   start_init_cnt;')
edit('i2c_ov5640_rgb565_cfg.v',"13'd5000","15'd20000")
edit('i2c_ov5640_rgb565_cfg.v',"13'd4999","15'd19999")
# Dri_clk is 1 MHz (SCL 250 kHz). Wait 20 ms on power-up and 2 ms
# after software reset; the old table immediately sent the wake-up command.
p=dst/'i2c_ov5640_rgb565_cfg.v';b=p.read_bytes()
first=b.index(b'always @(posedge clk')
last=b.index(b'//parameter define',first)
id_block=b[first:last]
b=b[:first]+b[last:]
pos=b.index(b'//*****************************************************',b.index(b'//reg define'))
b=b[:pos]+id_block+b'''// SCCB readback: bytes LSB first = manual, exp[19:16], exp[15:8],
// exp[7:0], gain[9:8], gain[7:0], average luminance, AEC target high.
reg [11:0] reset_wait;
reg [16:0] poll_timer;
reg polling;
reg poll_launch;
reg [2:0] poll_index;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n)begin reset_wait<=0;poll_timer<=0;polling<=0;poll_launch<=0;poll_index<=0;sensor_debug<=0;end
 else begin
  poll_launch<=init_done && polling && i2c_done && poll_index<7;
  if(i2c_done && init_reg_cnt==3 && !init_done)reset_wait<=2000;
  else if(reset_wait!=0)reset_wait<=reset_wait-1'b1;
  if(init_done && !polling)begin
   if(poll_timer==99999)begin poll_timer<=0;polling<=1;poll_index<=0;end
   else poll_timer<=poll_timer+1'b1;
  end
  if(init_done && polling && i2c_done)begin
   sensor_debug[poll_index*8+:8]<=i2c_data_r;
   if(poll_index==7)begin polling<=0;poll_index<=0;end
   else poll_index<=poll_index+1'b1;
  end
 end
end
''' +b[pos:]
p.write_bytes(b)
edit('i2c_ov5640_rgb565_cfg.v','else if(i2c_exec)   ','else if(i2c_exec && !init_done)   ')
edit('i2c_ov5640_rgb565_cfg.v','else if(i2c_done && (init_reg_cnt < REG_NUM))', '''else if(init_done && ((!polling && poll_timer==99999) || poll_launch))
        i2c_exec <= 1'b1;
    else if(reset_wait==1)
        i2c_exec <= 1'b1;
    else if(i2c_done && (init_reg_cnt < REG_NUM) && init_reg_cnt!=3 && !init_done)''')
edit('i2c_ov5640_rgb565_cfg.v',"else if(init_reg_cnt == 8'd2)","else if(init_done)\n        i2c_rh_wl <= 1'b1;\n    else if(init_reg_cnt == 8'd2)")
edit('i2c_ov5640_rgb565_cfg.v','else begin\n        case(init_reg_cnt)', '''else if(init_done)begin
        case(poll_index)
         0:i2c_data<={16'h3503,8'd0}; 1:i2c_data<={16'h3500,8'd0};
         2:i2c_data<={16'h3501,8'd0}; 3:i2c_data<={16'h3502,8'd0};
         4:i2c_data<={16'h350a,8'd0}; 5:i2c_data<={16'h350b,8'd0};
         6:i2c_data<={16'h56a1,8'd0}; 7:i2c_data<={16'h3a0f,8'd0};
        endcase
    end else begin
        case(init_reg_cnt)''')
for addr,old,new in [('3a0f','30','58'),('3a10','28','50'),('3a1b','30','58'),('3a1e','26','4c'),('3a11','60','b0'),('3a1f','14','28')]:
    edit('i2c_ov5640_rgb565_cfg.v',f"16'h{addr},8'h{old}",f"16'h{addr},8'h{new}")
edit('i2c_ov5640_rgb565_cfg.v',"default : i2c_data <= {16'h300a,8'h00};", "8'd250: i2c_data <= {16'h3503,8'h00}; // Explicit auto exposure + auto gain\n            default : i2c_data <= {16'h300a,8'h00};")
edit('ov5640_dri.v','output [15:0] sensor_id,','output [15:0] sensor_id,\n    output [63:0] sensor_debug,')
edit('ov5640_dri.v','.sensor_id          (sensor_id),','.sensor_id          (sensor_id),\n    .sensor_debug       (sensor_debug),')
edit('top_dual_ov5640_lcd.v','wire [15:0] chip_id1,chip_id2;','wire [15:0] chip_id1,chip_id2;\nwire [63:0] sensor_debug1,sensor_debug2;')
for n in (1,2):
    edit('top_dual_ov5640_lcd.v',f'.sensor_id         (chip_id{n}),',f'.sensor_id         (chip_id{n}),\n    .sensor_debug      (sensor_debug{n}),')
edit('top_dual_ov5640_lcd.v','wire [255:0] diagnostic_bus;','wire [383:0] diagnostic_bus;')
edit('top_dual_ov5640_lcd.v',"assign diagnostic_bus={13'd0", "assign diagnostic_bus={sensor_debug2,sensor_debug1,13'd0")
build=(root/'tools'/'build.tcl').read_text()
build=build.replace('build fusion','build brightness').replace('[file join $root rtl *.v]','[file join $root variants brightness rtl *.v]')
build=build.replace('set skip {','set skip {fusion_pipeline.v stream_features.v luma_histogram.v lowlight_fixed.v stereo_census.v depth_frame.v depth_roi.v distance_osd.v ')
build=build.replace('source [file join $root tools implement.tcl]','source [file join $root variants brightness implement.tcl]')
(root/'tools'/'build_brightness.tcl').write_text(build)
impl=(root/'tools'/'implement.tcl').read_text().replace('256','384').replace('fusion.ltx','brightness.ltx').replace('fusion.bit','brightness.bit')
(dst.parent/'implement.tcl').write_text(impl)
print(dst)
