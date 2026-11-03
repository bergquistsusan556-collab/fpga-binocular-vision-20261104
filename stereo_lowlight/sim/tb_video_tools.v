`timescale 1ns/1ps
module tb_video_tools;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0;
 reg [10:0] x=0,y=0;
 reg [15:0] rgb=0;
 reg [2:0] mode=0;
 wire [15:0] out;
 video_tools dut(clk,rst,sof,de,x,y,rgb,mode,out);
 integer a,b,f;
 reg patch;
 function [15:0] gray;
 input [7:0] value;
 begin gray={value[7:3],value[7:2],value[7:3]};end
 endfunction
 task tick;
 begin @(posedge clk);#1;end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  // Alternating bright/dark pixels detect even one-clock RGB/control skew.
  mode=4;
  for(a=0;a<800;a=a+1)begin
   @(negedge clk);de=1;x=a;y=0;rgb=a[0]?16'hffff:0;tick;
   if(out!==(a[0]?16'hffff:16'h0000))$fatal(1,"Binary pixel alignment");
  end
  mode=5;
  for(b=0;b<3;b=b+1)for(a=0;a<800;a=a+1)begin
   @(negedge clk);x=a;y=b;rgb=(a>=100&&a<400)?16'hffff:0;tick;
   if(b>0&&out!==((a==100)?16'hffff:16'h0000))$fatal(1,"Gradient or stereo seam x=%d y=%d",a,b);
  end
  @(negedge clk);de=0;rst=0;repeat(3)@(negedge clk);rst=1;mode=6;
  for(f=0;f<4;f=f+1)begin
   sof=1;@(negedge clk);sof=0;
   for(b=0;b<480;b=b+1)begin
    for(a=0;a<800;a=a+1)begin
     @(negedge clk);de=1;x=a;y=b;
     patch=a>=80&&a<144&&b>=80&&b<144;
     rgb=gray(f>=2&&patch?192:32);tick;
     if(f==2&&patch)begin if(out!==16'hf800)$fatal(1,"Motion missed x=%d y=%d",a,b);end
     else if(out==16'hf800)$fatal(1,"False/stale motion f=%d x=%d y=%d",f,a,b);
    end
    @(negedge clk);de=0;repeat(3)@(negedge clk);
   end
  end
  $display("PASS display-side binary alignment, edges/seam isolation, 4 full-frame motion initialization/move/stop and left/right separation");$finish;
 end
endmodule
