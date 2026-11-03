`timescale 1ns/1ps
module tb_calibration_capture;
 reg pc=0,rc=0;always #20 pc=~pc;always #10 rc=~rc;
 reg rst=0,sof=0,de=0;reg [10:0] x=0,y=0;reg [15:0] rgb=0,control=0;
 wire [31:0] sample;
 calibration_capture dut(pc,rc,rst,sof,de,x,y,rgb,control,sample);
 integer mode,k,xx,yy,n,a,prev,orig_x,orig_y,ox,oy;
 reg [3:0] prior_epoch;
 function [15:0] color;input integer px,py;
 begin color=((px*37+py*173)^16'h9c12);end endfunction
 function [7:0] gray;input [15:0] c;integer r,g,b;
 begin r=((c>>11)<<3)|((c>>13)&7);g=(((c>>5)&63)<<2)|((c>>9)&3);
 b=((c&31)<<3)|((c>>2)&7);gray=(77*r+150*g+29*b)/256;end endfunction
 task boundary;begin @(negedge pc);de=0;sof=1;@(negedge pc);sof=0;end endtask
 initial begin
  repeat(4)@(negedge pc);rst=1;
  // Partial frame is never marked valid and requires explicit rearm.
  control=16'h4001;boundary;
  @(negedge pc);de=1;x=0;y=0;rgb=color(0,0);
  boundary;repeat(5)@(negedge rc);
  if(dut.done||!dut.bad||sample[29])$fatal(1,"Partial frame accepted");
  boundary;if(dut.active)$fatal(1,"Failed frame automatically restarted");
  for(k=0;k<4;k=k+1)begin
   @(negedge pc);control=0;de=0;repeat(4)@(negedge pc);
   mode=k==0;ox=k==1?0:(k==2?100:200);oy=k==1?0:(k==2?120:240);
   prior_epoch=dut.epoch;
   control=16'h4000|mode|((ox/100)<<2)|((oy/120)<<4);
   repeat(3)@(negedge pc);
   if(dut.active||dut.done)$fatal(1,"Started outside frame boundary");
   boundary;
   // Every active pixel is offered in raster order, not just selected ones.
   for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<800;xx=xx+1)begin
    @(negedge pc);de=1;x=xx;y=yy;rgb=color(xx,yy);
   end
   boundary;repeat(6)@(negedge rc);
   if(!dut.done||dut.bad||dut.count!=96000||dut.epoch!=prior_epoch+1'b1)
    $fatal(1,"Complete raster rejected k=%0d count=%0d",k,dut.count);
   // Offer a different next frame while verifying every frozen address.
   @(negedge pc);de=1;x=0;y=0;rgb=16'hffff;
   prev=-1;
   for(n=0;n<96010;n=n+1)begin
    @(negedge rc);a=sample[24:8];
    if(sample[31:30]!==3||!sample[29]||sample[28:25]!==dut.epoch||a>=96000)
     $fatal(1,"Bad metadata");
    if(prev!=-1&&a!=(prev+1)%96000)$fatal(1,"Read address discontinuity");prev=a;
    orig_x=mode?(a%400)*2:((a%400)>=200?400:0)+(a%200)+ox;
    orig_y=mode?(a/400)*2:(a/400)+oy;
    if(sample[7:0]!==gray(color(orig_x,orig_y)))
     $fatal(1,"Data/tag/freeze mismatch mode %0d address %0d",k,a);
   end
  end
  // Abort in mid-raster, then reset. No stale done is allowed.
  @(negedge pc);control=0;de=0;repeat(3)@(negedge pc);
  control=16'h4001;boundary;@(negedge pc);control=0;
  repeat(5)@(negedge rc);if(sample[29])$fatal(1,"Abort kept stale valid");
  rst=0;repeat(4)@(negedge rc);if(sample[29])$fatal(1,"Reset kept stale valid");
  $display("PASS full-field and 3 crop positions: all 96000 pixels, address/data alignment, freeze, partial rejection, rearm, abort/reset");
  $finish;
 end
 initial begin #100000000;$fatal(1,"Timeout");end
endmodule
