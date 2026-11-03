`timescale 1ns/1ps
module tb_follow_alignment;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,en=0,target=1,in_frame=1,owned=1,scenario=0;
 reg [7:0] base=219;
 wire [7:0] control;wire ready,busy;wire [4:0] row;
 reg [4:0] sampled_row=27;
 wire qualified=scenario?(sampled_row==30):(sampled_row==28||sampled_row==29||sampled_row==31);
 wire [11:0] peak=sampled_row==24?900:scenario?(sampled_row==30?320:0):
   sampled_row==29?280:sampled_row==31?140:sampled_row==28?100:0;
 wire [63:0] diagnostic={24'd0,peak,28'd0};
 follow_row_tuner dut(clk,rst,sof,en,base,target,in_frame,owned,qualified,diagnostic,control,ready,busy,row);
 always @(posedge clk)if(sof)sampled_row<=row;
 task pulse;
 begin repeat(10)@(negedge clk);sof=1;@(negedge clk);sof=0;end endtask
 integer n;
 initial begin
  repeat(4)@(negedge clk);rst=1;repeat(3)@(negedge clk);
  if(control!=219||!ready||busy)$fatal(1,"Disabled tuner altered original alignment");
  en=1;
  for(n=0;n<90;n=n+1)pulse;
  if(!ready||busy||row!=29)$fatal(1,"Quality search selected wrong row %d ready=%b",row,ready);
  if(control[7:5]!=base[7:5])$fatal(1,"Alignment search altered eye/control flags");
  scenario=1;
  for(n=0;n<120;n=n+1)pulse;
  if(!ready||busy||row!=30)$fatal(1,"Quality loss did not trigger reacquisition %d",row);
  // The highest numerical peak is invalid and must never win.
  if(row==24)$fatal(1,"Invalid high population candidate was accepted");
  en=0;repeat(4)@(negedge clk);
  if(control!=219||!ready||busy)$fatal(1,"Leaving follow mode did not restore fixed control");
  en=1;target=0;
  for(n=0;n<10;n=n+1)pulse;
  if(ready||busy)$fatal(1,"No-target search falsely reported readiness");
  target=1;owned=0;
  for(n=0;n<90;n=n+1)pulse;
  if(ready)$fatal(1,"Measurements from outside the target were used for alignment");
  $display("PASS follow-only row search uses qualified texture peaks, flushes old frames, rejects invalid high scores, reacquires and restores fixed modes");$finish;
 end
 initial begin #1000000;$fatal(1,"Row tuner timeout");end
endmodule
