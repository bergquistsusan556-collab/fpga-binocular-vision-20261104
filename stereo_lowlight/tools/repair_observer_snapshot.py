"""Recover the exact pre-alignment sources in the 21:13 snapshot, hash checked."""
from pathlib import Path
import zipfile,json,hashlib
r=Path(__file__).resolve().parents[1];d=r/'baseline/distance_observer_20261024_2113'
m=json.loads((d/'manifest.json').read_text())
with zipfile.ZipFile(d/'source.zip') as z:files={n:z.read(n) for n in z.namelist()}
observer='''`timescale 1ns/1ps
// Read-only diagnostic tap: live 100x60 RGB565 thumbnail of both LCD inputs.
// Independent read clock, registered address/data; no back-pressure on video.
module stereo_observer(
 input wire pixel_clk,read_clk,rst_n,de,
 input wire [10:0] x,y,
 input wire [15:0] rgb,
 output wire [31:0] sample
);
 (* ram_style="block" *) reg [15:0] image[0:5999];
 wire [12:0] wa=(y>>3)*13'd100+(x>>3);
 always @(posedge pixel_clk)
  if(de&&x<800&&y<480&&x[2:0]==0&&y[2:0]==0)image[wa]<=rgb;
 reg [12:0] ra,addr;
 reg [15:0] pixel;
 always @(posedge read_clk)pixel<=image[ra];
 always @(posedge read_clk or negedge rst_n)
  if(!rst_n)begin ra<=0;addr<=0;end
  else begin ra<=ra==5999?13'd0:ra+1'b1;addr<=ra;end
 assign sample={3'b101,addr,pixel};
endmodule
'''
files['rtl/stereo_observer.v']=observer.encode()
s=files['rtl/fusion_pipeline.v'].decode().replace('\r\n','\n')
s=s.replace('output wire [63:0] diagnostic_roi,\n input wire [7:0] alignment_control','output wire [63:0] diagnostic_roi')
s=s.replace(' wire av,atex;wire [10:0] ax,ay;wire [7:0] acode;\n stereo_row_align align(clk,rst_n,fv,fx,fy,width,code,tex,alignment_control,av,ax,ay,acode,atex);\n stereo_census matcher(clk,rst_n,av,ax,ay,width,acode,atex,reverse,',
            ' stereo_census matcher(clk,rst_n,fv,fx,fy,width,code,tex,reverse,')
files['rtl/fusion_pipeline.v']=s.encode()
s=files['rtl/lcd_rgb_top.v'].decode().replace('\r\n','\n')
for old,new in [
 ('output wire [95:0] diagnostic_extra,\n input wire [15:0] diagnostic_control','output wire [95:0] diagnostic_extra'),
 (' (* ASYNC_REG="TRUE" *) reg [15:0] cs1,cs2;\n reg [15:0] frame_control;\n',''),
 ('   cs1<=0;cs2<=0;frame_control<=0;\n',''),
 ('   cs1<=diagnostic_control;cs2<=cs1;\n',''),
 ('frame_reverse<=rs2^cs2[6];frame_scale<=ss2;frame_control<=cs2;','frame_reverse<=rs2;frame_scale<=ss2;'),
 ('diagnostic_metrics,roi_diagnostic,frame_control[7:0]);','diagnostic_metrics,roi_diagnostic);'),
 ('data_in,frame_control[13:8],diagnostic_extra[95:64]);','data_in,diagnostic_extra[95:64]);')]:s=s.replace(old,new)
files['rtl/lcd_rgb_top.v']=s.encode()
for name,want in m['files_sha256'].items():
 if name.startswith('build/'):continue
 b=files[name]
 variants=[b,b.replace(b'\r\n',b'\n'),b.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')]
 good=next((v for v in variants if hashlib.sha256(v).hexdigest()==want),None)
 assert good is not None,name
 files[name]=good
with zipfile.ZipFile(d/'source.repaired.zip','x',zipfile.ZIP_DEFLATED) as z:
 for name,b in files.items():z.writestr(name,b)
(d/'source.repaired.zip').replace(d/'source.zip')
print('Snapshot pre-alignment source hashes all verified')
