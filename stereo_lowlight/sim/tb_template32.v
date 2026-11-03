`timescale 1ns/1ps
module tb_template32;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0,en=0,pixel=0;
 reg [10:0] x=0,y=0;
 reg drop_pixel=0; wire ready,valid;wire [7:0] mx,my;
 binary_template32 dut(clk,rst,sof,de,x,y,pixel,en,ready,valid,mx,my);
 function pattern;
 input integer a,b;
 reg [31:0] z;
 begin z=(a+32*b+1)*32'h45d9f3b;z=(z^(z>>16))*32'h45d9f3b;pattern=^(z^(z>>16));end
 endfunction
 task pulse_frame;
 begin @(negedge clk);sof=1;@(negedge clk);sof=0;end
 endtask
 task frame;
 input integer px,py,duplicate,empty;
 integer a,b;
 begin
  pulse_frame;
  for(b=0;b<240;b=b+1)for(a=0;a<200;a=a+1)begin
   @(negedge clk);de=!(drop_pixel && a==90 && b==110);x=400+2*a;y=2*b;pixel=0;
   if(!empty&&a>=px&&a<px+32&&b>=py&&b<py+32)pixel=pattern(a-px,b-py);
   if(duplicate&&a>=24&&a<56&&b>=40&&b<72)pixel=pattern(a-24,b-40);
  end
  @(negedge clk);de=0;
 end
 endtask
 task result;
 input integer expected_valid,px,py;
 integer cycles;
 begin
  cycles=0;
  while(dut.state!=4&&cycles<1300000)begin @(negedge clk);cycles=cycles+1;end
  if(cycles>=1300000)$fatal(1,"Template search stalled");
  pulse_frame;
  if(valid!==expected_valid)$fatal(1,"Acceptance mismatch valid=%b expected=%d best=%d second=%d",valid,expected_valid,dut.best,dut.second);
  if(expected_valid&&(mx!=px||my!=py))$fatal(1,"Wrong target position %d,%d",mx,my);
 end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;en=1;
  frame(80,104,0,1);
  repeat(3)@(negedge clk);
  if(ready||valid)$fatal(1,"Flat template accepted");
  frame(80,104,0,0);result(1,80,104);
  frame(128,160,0,0);result(1,128,160);
  frame(168,208,0,0);result(1,168,208);
  frame(128,160,1,0);result(0,0,0);
  frame(128,160,0,1);result(0,0,0);
  en=0;repeat(3)@(negedge clk);
  if(ready||valid)$fatal(1,"Stale template after mode exit");
  en=1;frame(80,104,0,0);result(1,80,104);
  // A missing sample must not publish a partly overwritten frame/template.
  en=0;repeat(3)@(negedge clk);en=1;drop_pixel=1;
  frame(80,104,0,0);repeat(3)@(negedge clk);
  if(ready||valid)$fatal(1,"Incomplete template frame accepted");
  drop_pixel=0;frame(80,104,0,0);result(1,80,104);
  // Leave the mode during an active search, not merely after a result.
  frame(128,160,0,0);repeat(200)@(negedge clk);
  if(dut.state!=2&&dut.state!=3)$fatal(1,"Expected active search before interruption");
  en=0;repeat(3)@(negedge clk);
  if(ready||valid)$fatal(1,"Interrupted search retained a stale target");
  en=1;frame(80,104,0,0);repeat(200)@(negedge clk);
  rst=0;repeat(3)@(negedge clk);rst=1;
  if(ready||valid)$fatal(1,"Reset retained a stale target");
  frame(80,104,0,0);result(1,80,104);
  $display("PASS 32x32 template capture, translated and last-grid target, ambiguity/absence/flat rejection, mode-exit/reset during search, incomplete-frame rejection and recapture");$finish;
 end
 initial begin #150000000;$fatal(1,"Template test timeout");end
endmodule

