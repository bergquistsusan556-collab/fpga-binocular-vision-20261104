`timescale 1ns/1ps
module tb_lowlight;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0,en=0;
 reg [10:0] x=0;
 reg [15:0] rgb=0;
 reg [7:0] lum=0,hist=0;
 reg [11:0] sum=0;
 wire ode;wire [10:0] ox,oy;wire [15:0] out_rgb;
 lowlight_fixed dut(clk,rst,de,en,x,11'd0,rgb,lum,hist,sum,4'd4,ode,ox,oy,out_rgb);
 reg [15:0] expected[0:31];
 integer i,count=0;
 always @(negedge clk)if(ode)begin
  if(ox<16 && out_rgb!==expected[ox])$fatal(1,"Bypass pixel/coordinate mismatch x=%0d rgb=%h expect=%h",ox,out_rgb,expected[ox]);
  if(ox==20 && out_rgb[15:11]<8)$fatal(1,"Dark grey did not brighten: %h",out_rgb);
  if(ox==21 && out_rgb!==16'hffff)$fatal(1,"White did not stay white: %h",out_rgb);
  count=count+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(i=0;i<16;i=i+1)begin
   @(negedge clk);de=1;en=0;x=i;rgb=16'h1234+i*119;expected[i]=rgb;lum=30;hist=30;sum=120;
  end
  @(negedge clk);de=0;
  repeat(10)@(negedge clk);
  de=1;en=1;x=20;rgb={5'd4,6'd8,5'd4};lum=32;hist=32;sum=128;
  @(negedge clk);x=21;rgb=16'hffff;lum=255;hist=255;sum=1020;
  @(negedge clk);de=0;
  repeat(12)@(negedge clk);
  if(count!=18)$fatal(1,"Lost valid pixels %0d",count);
  $display("PASS lowlight bypass alignment, dark lift and highlight saturation");$finish;
 end
endmodule
