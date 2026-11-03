`timescale 1ns/1ps
module tb_front_roi;
 wire [63:0] roi_debug;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0,valid=1;
 reg [5:0] disparity=1;
 reg [8:0] scale=256;
 wire [15:0] cm;wire dv;wire [5:0] dom;
 depth_roi dut(clk,rst,sof,de,valid,11'd200,11'd240,11'd800,11'd480,disparity,scale,cm,dv,dom,roi_debug);
 integer i,k,expected,lower,upper_count;real true_d;
 task finish_frame;
 begin @(negedge clk);de=0;sof=1;@(negedge clk);sof=0;repeat(200)@(negedge clk);end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(k=0;k<6;k=k+1)begin
   case(k)0:expected=30;1:expected=50;2:expected=75;3:expected=100;4:expected=150;5:expected=200;endcase
   true_d=346.0*32.0/(10.0*expected);lower=$rtoi(true_d);
   upper_count=$rtoi((true_d-lower)*1600.0+0.5);
   for(i=0;i<1600;i=i+1)begin @(negedge clk);de=1;disparity=i<upper_count?lower+1:lower;end
   finish_frame;
   if(!dv || cm<expected-1 || cm>expected+1)$fatal(1,"Distance arithmetic at %0d cm: got=%0d valid=%b",expected,cm,dv);
   if(roi_debug[3:0]!=6 || roi_debug[15:4]!=1600 || roi_debug[27:16]!=1600)
    $fatal(1,"Accepted ROI diagnostic counters/status incorrect");
  end
  for(i=0;i<1600;i=i+1)begin @(negedge clk);de=1;disparity=1+i%63;end
  finish_frame;if(dv || roi_debug[3:0]!=3)$fatal(1,"Ambiguous mixed-depth ROI accepted or misdiagnosed");
  finish_frame;if(dv || roi_debug[3:0]!=1)$fatal(1,"Empty ROI retained distance or wrong status");
  for(i=0;i<1600;i=i+1)begin @(negedge clk);de=1;disparity=3;end
  finish_frame;if(dv || roi_debug[3:0]!=5)$fatal(1,"Beyond guard ROI accepted or wrong status");
  for(i=0;i<1600;i=i+1)begin @(negedge clk);de=1;disparity=50;end
  finish_frame;if(dv || roi_debug[3:0]!=4)$fatal(1,"Below guard ROI accepted or wrong status");
  for(i=0;i<15;i=i+1)begin @(negedge clk);de=1;disparity=10;end
  finish_frame;if(dv || roi_debug[3:0]!=2)$fatal(1,"Insufficient ROI accepted or wrong status");
  $display("PASS ROI arithmetic 0.3/0.5/0.75/1/1.5/2m, <=1cm numerical error; diagnostic counts, mixed/empty/near/far/sparse rejection");$finish;
 end
endmodule
