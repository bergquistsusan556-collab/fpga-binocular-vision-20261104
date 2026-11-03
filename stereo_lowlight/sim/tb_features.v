`timescale 1ns/1ps
module tb_features;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0;reg [10:0] x=0,y=0;reg [15:0] rgb=0;
 wire fv,tex;wire [10:0] fx,fy;wire [15:0] frgb;
 wire [7:0] lum,code;wire [11:0] sum;wire [3:0] weight;
 stream_features dut(clk,rst,de,x,y,11'd16,rgb,fv,fx,fy,frgb,lum,code,tex,sum,weight);
 function [15:0] pixel;
 input integer xx,yy;
 reg [4:0] r,b;reg [5:0] g;
 begin r=xx+yy;g=xx*3+yy;b=yy*4+xx;pixel={r,g,b};end
 endfunction
 integer i,j,count=0;
 always @(negedge clk)if(fv)begin
  if(frgb!==pixel(fx,fy))$fatal(1,"Feature RGB/coordinate misalignment %0d,%0d",fx,fy);
  if(fx==8 && fy==0 && (tex||sum!=lum*12||weight!=12||code!=0))
    $fatal(1,"Camera boundary leaked left-eye history: sum=%0d lum=%0d code=%h",sum,lum,code);
  count=count+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(j=0;j<4;j=j+1)begin
   for(i=0;i<16;i=i+1)begin
    @(negedge clk);de=1;x=i;y=j;rgb=pixel(i,j);
    if(i==5)begin @(negedge clk);de=0;repeat(3)@(negedge clk);end
   end
   @(negedge clk);de=0;repeat(12)@(negedge clk);
  end
  repeat(10)@(negedge clk);
  if(count!=64)$fatal(1,"Feature pipeline lost pixels %0d",count);
  $display("PASS feature coordinates, blanking bubbles and binocular boundary isolation");$finish;
 end
endmodule
