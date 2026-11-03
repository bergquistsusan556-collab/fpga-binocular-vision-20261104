`timescale 1ns/1ps
module tb_frames;
 wire [63:0] roi_debug;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0,valid=0;
 reg [10:0] x=0,y=0,dx=0,dy=0;
 reg [5:0] d=20;
 wire [15:0] cm;wire dv;wire [5:0] dom;
 wire [6:0] sample;wire ready;
 depth_roi roi(clk,rst,sof,de,valid,x,y,11'd800,11'd480,d,9'd256,cm,dv,dom,roi_debug);
 depth_frame frame(clk,rst,sof,de,valid,x,y,d,dx,dy,sample,ready);
 wire [7:0] mapped;
 luma_histogram hist(clk,rst,de,sof,8'd32,mapped);
 integer i;
 task blank;
 begin @(negedge clk);de=0;sof=1;@(negedge clk);sof=0;repeat(2000)@(negedge clk);end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;blank;
  // One valid sample cell at logical (200,240), displayed at (800,480) /2:
  // read coordinate (400,240) maps to stored (200,240).
  for(i=0;i<100;i=i+1)begin
   @(negedge clk);de=1;valid=1;x=200;y=240;d=20;
  end
  blank;
  if(!dv||cm!=55||dom!=20)$fatal(1,"ROI calibration arithmetic: valid=%b cm=%0d dom=%0d",dv,cm,dom);
  if(mapped!=255)$fatal(1,"CDF cumulative normalization failed: %0d",mapped);
  dx=400;dy=240;repeat(3)@(negedge clk);
  if(!ready||sample!={1'b1,6'd20})$fatal(1,"Completed frame bank/address mismatch: %h",sample);
  // Overwrite same cell invalid in next bank. Invalid data must not persist.
  @(negedge clk);de=1;valid=0;x=200;y=240;
  @(negedge clk);de=0;blank;
  repeat(3)@(negedge clk);
  if(dv||sample!=0)$fatal(1,"Empty ROI or invalid depth cell retained stale valid data");
  $display("PASS histogram normalization, ROI distance arithmetic, depth bank swap and invalid clearing");$finish;
 end
endmodule
