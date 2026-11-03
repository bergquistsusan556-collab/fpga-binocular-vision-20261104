`timescale 1ns/1ps
module tb_follow_roi;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0,valid=0,en=1;
 reg [10:0] x=0,y=0,cx=100,cy=100;
 reg [5:0] disp=12;
 wire [15:0] cm;wire dv;wire [5:0] dominant;wire [63:0] diag;wire [33:0] measured;
 depth_roi_follow dut(clk,rst,sof,de,valid,x,y,11'd800,11'd480,disp,9'd256,
   cm,dv,dominant,diag,en,cx,cy,6'd4,6'd3,measured);
 integer a,b;
 task pulse;
 begin @(negedge clk);sof=1;@(negedge clk);sof=0;repeat(200)@(negedge clk);end endtask
 task measurement;
 input integer xx,yy,dd,expected;
 begin
  cx=xx;cy=yy;pulse;
  // A contrasting fixed-center background must never set the followed distance.
  for(b=220;b<=260;b=b+1)for(a=180;a<=220;a=a+1)begin
   @(negedge clk);de=1;valid=1;x=a;y=b;disp=1;
  end
  for(b=yy-3;b<=yy+3;b=b+1)for(a=xx-4;a<=xx+4;a=a+1)begin
   @(negedge clk);de=1;valid=1;x=a;y=b;disp=dd;
  end
  @(negedge clk);de=0;valid=0;pulse;
  if(!dv||cm!=expected)$fatal(1,"Moving ROI output=%d valid=%b expected=%d diag=%h",cm,dv,expected,diag);
  if(measured!={6'd4,6'd3,cx,cy})$fatal(1,"Range was associated with a different ROI frame");
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  measurement(100,100,12,98);
  measurement(300,330,32,52);
  en=0;@(negedge clk);
  if(dv||cm!=0)$fatal(1,"Lost marker retained distance");
  pulse;en=1;
  repeat(10)@(negedge clk);
  if(dv)$fatal(1,"Reacquisition reused stale distance");
  measurement(260,180,0,210);
  $display("PASS moving texture ROI excludes fixed background, accepted calibration unchanged, loss clears distance and zero-disparity reacquisition");$finish;
 end
endmodule
