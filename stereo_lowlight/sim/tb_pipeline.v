`timescale 1ns/1ps
module tb_pipeline;
 wire [63:0] roi_debug;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0;reg [10:0] x=0,y=0;reg [15:0] rgb=0;
 wire [95:0] unused_metrics;wire ode,dv,md,mv;wire [10:0] ox,oy;wire [15:0] out_rgb,cm;wire [5:0] dominant,disp;
 fusion_pipeline dut(clk,rst,sof,de,x,y,11'd800,11'd480,rgb,3'd0,1'b0,9'd256,
   ode,ox,oy,out_rgb,cm,dv,dominant,md,mv,disp,unused_metrics,roi_debug,8'd0);
 function [15:0] pixel;
 input integer xx,yy;
 begin pixel=(xx*37+yy*119)^16'h37b2;end
 endfunction
 integer i,j,count=0;
 always @(negedge clk)if(ode)begin
   if(out_rgb!==pixel(ox,oy))$fatal(1,"Pipeline RGB/DE misalignment: %0d,%0d %h/%h",ox,oy,out_rgb,pixel(ox,oy));
   if(ox!=count%800||oy!=count/800)$fatal(1,"Lost/repeated coordinate at output");
   count=count+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=1;sof=1;@(negedge clk);sof=0;
  repeat(2000)@(negedge clk);
  for(j=0;j<4;j=j+1)begin
   for(i=0;i<800;i=i+1)begin @(negedge clk);de=1;x=i;y=j;rgb=pixel(i,j);end
   @(negedge clk);de=0;repeat(256)@(negedge clk);
  end
  repeat(30)@(negedge clk);
  if(count!=3200)$fatal(1,"Incomplete full-width video pipeline: %0d",count);
  $display("PASS integrated full-width video pipeline, every bypass RGB pixel/DE/coordinate aligned");$finish;
 end
endmodule
