`timescale 1ns/1ps
// One LCD raster is frozen. This is NOT a simultaneous sensor exposure.
// control[0]: full-field /2 sampling; otherwise full-resolution 200x240 crops.
// control[3:2]: crop x /100, [5:4]: crop y /120, both clamped at 2.
// control[14]: arm and hold; deassert to rearm. Only complete rasters are valid.
module calibration_capture(
 input wire pixel_clk,read_clk,rst_n,sof,de,
 input wire [10:0] x,y,
 input wire [15:0] rgb,control,
 output wire [31:0] sample
);
 localparam TOTAL=96000;
 (* ram_style="block" *) reg [7:0] image [0:TOTAL-1];
 reg active,done,bad;
 reg [16:0] count;
 reg [3:0] epoch;
 reg [5:0] capture_config;
 wire [10:0] local_x=x>=400?x-400:x;
 wire [10:0] ox=capture_config[3:2]>=2?200:capture_config[3:2]*100;
 wire [10:0] oy=capture_config[5:4]>=2?240:capture_config[5:4]*120;
 wire selected=de&&x<800&&y<480&&(capture_config[0]?
  (!x[0]&&!y[0]):(local_x>=ox&&local_x<ox+200&&y>=oy&&y<oy+240));
 wire [10:0] sx=capture_config[0]?(x>>1):((x>=400?200:0)+local_x-ox);
 wire [10:0] sy=capture_config[0]?(y>>1):(y-oy);
 wire [18:0] expected_address=sy*400+sx;
 wire [7:0] r={rgb[15:11],rgb[15:13]};
 wire [7:0] g={rgb[10:5],rgb[10:9]};
 wire [7:0] b={rgb[4:0],rgb[4:2]};
 wire [15:0] lum=r*16'd77+g*16'd150+b*16'd29;
 // Do not reset RAM; infer a true dual-clock simple dual-port block RAM.
 always @(posedge pixel_clk)begin
  if(rst_n&&active&&control[14]&&selected&&!bad&&count<TOTAL&&expected_address==count)
   image[count]<=lum[15:8];
 end
 always @(posedge pixel_clk or negedge rst_n)begin
  if(!rst_n)begin active<=0;done<=0;bad<=0;count<=0;epoch<=0;capture_config<=0;end
  else if(!control[14])begin active<=0;done<=0;bad<=0;count<=0;end
  else if(sof)begin
   if(active)begin active<=0;done<=!bad&&count==TOTAL;bad<=bad||count!=TOTAL;end
   else if(!done&&!bad)begin active<=1;count<=0;capture_config<=control[5:0];epoch<=epoch+1'b1;end
  end else if(active&&selected)begin
   if(count>=TOTAL||expected_address!=count)bad<=1;
   else count<=count+1'b1;
  end
 end
 (* ASYNC_REG="TRUE" *) reg ds1,ds2;
 (* ASYNC_REG="TRUE" *) reg [3:0] es1,es2;
 reg [16:0] rd_address,tag;
 reg [7:0] data;
 always @(posedge read_clk) data<=image[rd_address];
 always @(posedge read_clk or negedge rst_n)begin
  if(!rst_n)begin rd_address<=0;tag<=0;ds1<=0;ds2<=0;es1<=0;es2<=0;end
  else begin
   rd_address<=rd_address==TOTAL-1?0:rd_address+1'b1;
   tag<=rd_address;ds1<=done;ds2<=ds1;es1<=epoch;es2<=es1;
  end
 end
 assign sample={2'b11,ds2,es2,tag,data};
endmodule
