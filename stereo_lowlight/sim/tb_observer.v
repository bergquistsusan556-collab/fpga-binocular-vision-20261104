`timescale 1ns/1ps
module tb_observer;
 reg pc=0,rc=0;always #20 pc=~pc;always #10 rc=~rc;
 reg rst=0,de=0;reg [10:0] x=0,y=0;reg [15:0] rgb=0;reg [5:0] phase=0;
 wire [31:0] sample;
 reg sof=0,snapshot=0;
 stereo_observer dut(pc,rc,rst,de,x,y,rgb,phase,sample,sof,snapshot);
 integer xx,yy,n=0,addr,previous,k;
 function [15:0] color;
 input integer a;
 begin color=(a*37)^16'h9c12;end
 endfunction
 function [7:0] expected;
 input integer a;
 reg [15:0] c;integer rr,gg,bb;
 begin c=color(a);
 rr=((c>>11)<<3)|((c>>13)&7);gg=(((c>>5)&63)<<2)|((c>>9)&3);bb=((c&31)<<3)|((c>>2)&7);
 expected=(77*rr+150*gg+29*bb)/256;end
 endfunction
 initial begin
  repeat(4)@(negedge pc);rst=1;
  for(k=0;k<2;k=k+1)begin
   phase=k==0?0:63;
   for(yy=0;yy<60;yy=yy+1)for(xx=0;xx<100;xx=xx+1)begin
    @(negedge pc);de=1;x=xx*8+phase[2:0];y=yy*8+phase[5:3];rgb=color(yy*100+xx);
   end
   @(negedge pc);de=0;previous=-1;
   for(n=0;n<6200;n=n+1)begin
    @(negedge rc);addr=sample[28:16];
    if(sample[31:29]!==3'b110||sample[15:10]!==phase||sample[9:8]!=1||addr>=6000||sample[7:0]!==expected(addr))
     $fatal(1,"Observer phase/address/data mismatch at %0d got %h",addr,sample);
    if(previous!=-1&&addr!=(previous+1)%6000)$fatal(1,"Observer read discontinuity");previous=addr;
   end
  end
  @(negedge pc);snapshot=1;de=1;x=128;y=192;rgb=16'hf800;
  repeat(4)@(negedge pc);
  if(dut.active||dut.done)$fatal(1,"Snapshot started without frame boundary");
  de=0;sof=1;@(negedge pc);sof=0;
  for(yy=0;yy<32;yy=yy+1)for(xx=0;xx<128;xx=xx+1)begin
   @(negedge pc);de=1;x=128+xx;y=192+yy;rgb=color(yy*128+xx);
  end
  for(yy=0;yy<28;yy=yy+1)for(xx=0;xx<64;xx=xx+1)begin
   @(negedge pc);de=1;x=576+xx;y=224+yy;rgb=color(4096+yy*64+xx);
  end
  @(negedge pc);de=0;sof=1;@(negedge pc);sof=0;
  repeat(6)@(negedge rc);
  if(!dut.done||dut.active)$fatal(1,"Snapshot did not finish on next frame");
  // Later live video must not alter the saved pixels.
  @(negedge pc);de=1;x=128;y=192;rgb=16'hffff;
  for(n=0;n<6200;n=n+1)begin
   @(negedge rc);addr=sample[28:16];
   if(sample[31:29]!==6||sample[15:10]!==1||sample[9:8]!==2)$fatal(1,"Snapshot tag invalid");
   if(addr<5888&&sample[7:0]!==expected(addr))$fatal(1,"Frozen ROI mismatch at %0d",addr);
  end
  @(negedge pc);de=0;snapshot=0;repeat(4)@(negedge pc);
  if(dut.done||dut.active)$fatal(1,"Snapshot rearm failed");
  $display("PASS luminance tap 6000 pixels, phase tags, and 5888 full-resolution single-frame ROI pixels frozen/rearmed");$finish;
 end
endmodule
