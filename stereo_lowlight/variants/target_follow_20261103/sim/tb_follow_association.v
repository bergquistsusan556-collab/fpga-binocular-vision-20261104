`timescale 1ns/1ps
// Check sample ownership independently of the matcher that produces a sample.
module tb_follow_association;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg [2:0] mode=7;
 wire ode,dv,md,mv;wire [10:0] ox,oy;wire [15:0] rgb,cm;
 wire [5:0] dom,disp;wire [95:0] metrics;wire [63:0] diagnostic;
 fusion_pipeline dut(clk,rst,1'b0,1'b0,11'd0,11'd0,11'd800,11'd480,16'd0,mode,1'b0,9'd256,
  ode,ox,oy,rgb,cm,dv,dom,md,mv,disp,metrics,diagnostic,8'd0);
 task expect_valid;
 input expected;
 begin
  #20;
  if(dv!==expected)$fatal(1,"Completed sample ownership wrong, expected %b got %b",expected,dv);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  force dut.target_valid=1;force dut.tx=8'd80;force dut.ty=8'd80;
  force dut.tw=8'd48;force dut.th=8'd48;force dut.trot=2'd0;
  force dut.roi_valid=1;force dut.roi_cm=16'd100;
  force dut.measured_roi={6'd36,6'd4,11'd208,11'd274};
  expect_valid(1);
  // Two native pixels of vertical jitter, eight horizontal: still on texture.
  force dut.ty=8'd81;force dut.tx=8'd84;expect_valid(1);
  // Four vertical pixels leave the narrow texture; do not retain its old range.
  force dut.ty=8'd82;expect_valid(0);
  force dut.ty=8'd80;force dut.tx=8'd87;expect_valid(0);
  // A new measurement at the new position restores the reading.
  force dut.measured_roi={6'd36,6'd4,11'd222,11'd274};expect_valid(1);
  force dut.target_valid=0;expect_valid(0);
  if(cm!==0)$fatal(1,"Lost target retained a distance");
  force dut.target_valid=1;force dut.roi_valid=0;expect_valid(0);
  force dut.roi_valid=1;force dut.ty=8'd190;expect_valid(0);
  // Rotation swaps the narrow and wide ownership directions.
  force dut.tx=8'd80;force dut.ty=8'd80;force dut.trot=2'd1;
  force dut.measured_roi={6'd4,6'd36,11'd142,11'd208};expect_valid(1);
  force dut.tx=8'd81;expect_valid(1);
  force dut.tx=8'd82;expect_valid(0);
  // Unchanged fixed center modes require the exact fixed measurement stamp.
  mode=0;expect_valid(0);
  force dut.measured_roi={6'd20,6'd20,11'd200,11'd240};expect_valid(1);
  force dut.measured_roi={6'd20,6'd20,11'd201,11'd240};expect_valid(0);
  $display("PASS small bbox jitter retains samples only within texture, jumps/loss/invalid/outside reject, rotated and fixed ROI ownership");$finish;
 end
 initial begin #10000;$fatal(1,"Ownership test timeout");end
endmodule
