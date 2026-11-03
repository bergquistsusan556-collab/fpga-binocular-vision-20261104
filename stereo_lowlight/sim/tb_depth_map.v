`timescale 1ns/1ps
module tb_depth_map;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0,valid=0;
 reg [10:0] wx=0,wy=0,dx=0,dy=0;
 reg [5:0] disparity=0;
 wire [6:0] sample;wire ready;
 depth_frame dut(clk,rst,sof,de,valid,wx,wy,disparity,dx,dy,sample,ready);
 integer xx,yy,phase,count=0;
 reg [6:0] expected;
 task swap;
 begin @(negedge clk);de=0;sof=1;@(negedge clk);sof=0;repeat(2)@(negedge clk);end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;swap;
  for(phase=0;phase<2;phase=phase+1)begin
   for(yy=0;yy<480;yy=yy+2)for(xx=0;xx<400;xx=xx+2)begin
    @(negedge clk);de=1;wx=xx;wy=yy;
    valid=phase==0 && (((xx/2)+(yy/2))%11!=0);
    disparity=1+((xx/2)*3+(yy/2)*5)%63;
   end
   swap;
   if(!ready)$fatal(1,"Completed depth frame unavailable");
   for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<800;xx=xx+1)begin
    @(negedge clk);dx=xx;dy=yy;
    @(negedge clk);
    if(phase==0 && (((xx/4)+(yy/2))%11!=0))expected={1'b1,6'd0}|(1+((xx/4)*3+(yy/2)*5)%63);
    else expected=0;
    if(sample!==expected)$fatal(1,"Depth map bank/address/scaling mismatch phase=%0d at %0d,%0d: %h/%h",phase,xx,yy,sample,expected);
    count=count+1;
   end
  end
  @(negedge clk);dx=800;dy=480;repeat(2)@(negedge clk);
  if(sample!=0)$fatal(1,"Out-of-field depth read not masked");
  $display("PASS whole 800x480 disparity display, two banks, every one of 768000 output cells, invalid overwrite and field boundaries");$finish;
 end
endmodule
