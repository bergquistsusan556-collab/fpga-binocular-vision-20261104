`timescale 1ns/1ps
// RGB input, three textured depth regions. No precomputed Census codes.
module tb_stereo_degraded;
 reg [15:0] observed[0:383999];
 wire [63:0] roi_debug;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0;
 reg [10:0] x=0,y=0;
 reg [15:0] rgb=0;
 wire fv,tex;wire [10:0] fx,fy;wire [15:0] frgb;
 wire [7:0] lum,code;wire [11:0] sum;wire [3:0] weight;
 stream_features features(clk,rst,de,x,y,11'd800,rgb,fv,fx,fy,frgb,lum,code,tex,sum,weight);
 wire md,mv;wire [10:0] mx,my;wire [5:0] disparity;
 stereo_census match(clk,rst,fv,fx,fy,11'd800,code,tex,1'b0,md,mv,mx,my,disparity);
 wire [15:0] cm;wire dv;wire [5:0] dominant;
 depth_roi roi(clk,rst,sof,md,mv,mx,my,11'd800,11'd480,disparity,9'd256,cm,dv,dominant,roi_debug);
 function integer truth;
 input integer xx;
 begin truth=xx<133?4:(xx<267?12:22);end
 endfunction
 function [15:0] pixel;
 input integer xx,yy;
 reg [31:0] hash;
 reg [7:0] a;
 begin
  hash=(xx+1)*32'h45d9f3b ^ (yy+1)*32'h119de1f3;
  hash=hash^(hash>>16);hash=hash*32'h45d9f3b;hash=hash^(hash>>16);
  a=8'd16+{1'b0,hash[6:0]};pixel={a[7:3],a[7:2],a[7:3]};
 end
 endfunction
 integer i,j,checked=0,accepted=0,correct=0,region;
 integer per_total[0:2],per_good[0:2];
 always @(negedge clk)if(md&&my>=4&&mx>=16&&mx<360&&
  !(mx>=120&&mx<=150)&&!(mx>=254&&mx<=284))begin
   checked=checked+1;
   if(mv)begin
    accepted=accepted+1;
    region=mx<133?0:(mx<267?1:2);per_total[region]=per_total[region]+1;
    if(disparity==truth(mx))begin correct=correct+1;per_good[region]=per_good[region]+1;end
   end
 end
 initial begin
  $readmemh("degraded_rgb565.hex",observed);
  for(i=0;i<3;i=i+1)begin per_total[i]=0;per_good[i]=0;end
  repeat(4)@(negedge clk);rst=1;sof=1;@(negedge clk);sof=0;
  repeat(2000)@(negedge clk);
  for(j=0;j<480;j=j+1)begin
   for(i=0;i<800;i=i+1)begin
    @(negedge clk);de=1;x=i;y=j;
    rgb=observed[j*800+i];
   end
   @(negedge clk);de=0;repeat(32)@(negedge clk);
  end
  repeat(30)@(negedge clk);sof=1;@(negedge clk);sof=0;
  repeat(300)@(negedge clk);
  if(accepted<1000 || correct*100<accepted*95)
   $fatal(1,"RGB stereo scene insufficient coverage/accuracy: %0d/%0d accepted, %0d correct",accepted,checked,correct);
  for(i=0;i<3;i=i+1)begin
   if(per_total[i]<100 || per_good[i]*100<per_total[i]*95)$fatal(1,"Depth region %0d failed",i);
  end

  $display("PASS observed blurry text + gain/bias/noise, disparities 4/12/22, accepted=%0d/%0d correct=%0d center=%0dcm",accepted,checked,correct,cm);
  $finish;
 end
endmodule
