`timescale 1ns/1ps
module tb_marker7;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0,en=0,pixel=1,drop=0;
 reg [10:0] x=0,y=0;
 wire ready,valid;wire [7:0] mx,my,mw,mh,epoch;wire [1:0] rotation;
 marker7_tracker dut(clk,rst,sof,de,x,y,pixel,en,ready,valid,mx,my,mw,mh,rotation,epoch);
 reg images[0:767999];
 integer a,b,waited;
 task pulse;
 begin @(negedge clk);sof=1;@(negedge clk);sof=0;end endtask
 task frame;
 input integer number;
 begin
  pulse;
  for(b=0;b<240;b=b+1)for(a=0;a<200;a=a+1)begin
   @(negedge clk);de=!(drop&&a==80&&b==100);x=400+2*a;y=2*b;pixel=images[number*48000+b*200+a];
  end
  @(negedge clk);de=0;
 end endtask
 task result;
 input integer expected,xx,yy,ww,hh,rot;
 begin
  waited=0;
  while(dut.state!=12&&waited<900000)begin @(negedge clk);waited=waited+1;end
  if(waited>=900000)$fatal(1,"Marker scan did not complete");
  pulse;
  if(valid!==expected)$fatal(1,"Marker validity expected %d got %b found=%b ambiguous=%b bbox=%d,%d %dx%d",expected,valid,dut.found,dut.ambiguous,mx,my,mw,mh);
  if(expected&&(mx!=xx||my!=yy||mw!=ww||mh!=hh||rotation!=rot))
   $fatal(1,"Wrong normalized marker %d,%d %dx%d rotation%0d",mx,my,mw,mh,rotation);
 end endtask
 initial begin
  $readmemh("marker_frames.hex",images);
  repeat(4)@(negedge clk);rst=1;en=1;
  frame(0);result(0,0,0,0,0,0);
  frame(1);result(1,80,80,48,48,0);
  frame(2);result(1,39,51,48,48,0);
  frame(3);result(1,20,21,132,156,0);
  frame(4);result(1,129,130,24,36,0);
  frame(5);result(1,50,60,36,24,1);
  frame(11);result(0,0,0,0,0,0);
  frame(12);result(0,0,0,0,0,0);
  frame(13);result(1,70,70,48,72,0);
  frame(14);result(1,101,82,45,96,0);
  frame(15);result(1,45,52,46,92,0);
  frame(6);result(0,0,0,0,0,0);
  frame(7);result(0,0,0,0,0,0);
  frame(8);result(0,0,0,0,0,0);
  frame(9);result(1,70,40,60,96,2);
  drop=1;frame(10);repeat(8)@(negedge clk);
  if(valid)$fatal(1,"Incomplete frame reused old target");
  drop=0;frame(10);result(1,30,45,48,60,3);
  frame(1);repeat(100)@(negedge clk);en=0;repeat(3)@(negedge clk);
  if(valid||ready)$fatal(1,"Mode exit did not clear target");
  en=1;frame(2);result(1,39,51,48,48,0);
  repeat(5)pulse;
  if(valid)$fatal(1,"Stale target survived incomplete frames");
  $display("PASS ID7 multiscale nongrid translation, rectangular projections, four rotations, wrong-ID/duplicate/absence rejection, loss/reacquisition, incomplete frame and stale clearing");$finish;
 end
 initial begin #100000000;$fatal(1,"Marker test timeout");end
endmodule
