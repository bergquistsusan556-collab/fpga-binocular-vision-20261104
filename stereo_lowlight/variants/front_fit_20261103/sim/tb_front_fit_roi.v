`timescale 1ns/1ps
// Numerical/validity verification only; synthetic data is not a range accuracy test.
module tb_front_fit_roi;
 reg clk=0; always #5 clk=~clk;
 reg rst=0,sof=0,de=0,valid=1;
 reg [5:0] disparity=0;
 reg [8:0] scale=256;
 wire [15:0] cm; wire dv; wire [5:0] dom; wire [63:0] debug;
 depth_roi dut(clk,rst,sof,de,valid,11'd200,11'd240,11'd800,11'd480,
               disparity,scale,cm,dv,dom,debug);
 integer i,k,z,lower,ones;
 real d;
 task finish_frame;
 begin
  @(negedge clk);de=0;sof=1;
  @(negedge clk);sof=0;repeat(210)@(negedge clk);
 end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(k=0;k<6;k=k+1)begin
   case(k)0:z=30;1:z=50;2:z=100;3:z=150;4:z=190;5:z=200;endcase
   d=2194.859375/z-10.45703125;lower=$rtoi(d);
   ones=$rtoi((d-lower)*1600+0.5);
   for(i=0;i<1600;i=i+1)begin
    @(negedge clk);de=1;disparity=i<ones?lower+1:lower;
   end
   finish_frame;
   if(!dv || cm<z-1 || cm>z+1)$fatal(1,"Synthetic arithmetic z=%0d got=%0d valid=%b",z,cm,dv);
   if(debug[3:0]!=6 || debug[27:16]!=1600)$fatal(1,"ROI accounting incorrect");
  end
  for(i=0;i<1600;i=i+1)begin @(negedge clk);de=1;disparity=0;end
  finish_frame;
  if(!dv || cm!=210 || dom!=0)$fatal(1,"Unique valid zero disparity was lost");
  finish_frame;
  if(dv || cm!=0 || debug[3:0]!=1)$fatal(1,"Empty ROI reused old valid distance");
  for(i=0;i<1600;i=i+1)begin @(negedge clk);de=1;disparity=i%64;end
  finish_frame;if(dv || debug[3:0]!=3)$fatal(1,"Dispersed disparity accepted");
  for(i=0;i<15;i=i+1)begin @(negedge clk);de=1;disparity=0;end
  finish_frame;if(dv || debug[3:0]!=2)$fatal(1,"Sparse zero disparity accepted");
  scale=128;
  for(i=0;i<1600;i=i+1)begin @(negedge clk);de=1;disparity=0;end
  finish_frame;if(!dv || cm!=105)$fatal(1,"Existing scale control changed");
  $display("PASS provisional ROI arithmetic 30/50/100/150/190/200cm; valid zero, empty, sparse, dispersed, scale");
  $finish;
 end
endmodule
