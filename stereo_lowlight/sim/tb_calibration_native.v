`timescale 1ns/1ps
module tb_calibration_native;
 reg pc=0,rc=0;always #20 pc=~pc;always #10 rc=~rc;
 reg rst=0,sof=0,de=0;reg [10:0] x=0,y=0;reg [15:0] rgb=0,control=0;
 wire [47:0] sample;
 calibration_native_capture dut(pc,rc,rst,sof,de,x,y,rgb,control,sample);
 integer k,xx,yy,n,a,p,idx,px,py,previous;reg [5:0] expected;
 function [15:0] color;input integer cx,cy;begin color=((cx*37+cy*173)^16'h9c12);end endfunction
 function [5:0] gray;input [15:0] c;integer r,g,b;
 begin r=((c>>11)<<3)|((c>>13)&7);g=(((c>>5)&63)<<2)|((c>>9)&3);
 b=((c&31)<<3)|((c>>2)&7);gray=(77*r+150*g+29*b)/1024;end endfunction
 task boundary;begin @(negedge pc);de=0;sof=1;@(negedge pc);sof=0;end endtask
 initial begin
  repeat(4)@(negedge pc);rst=1;control=16'h4000;boundary;
  @(negedge pc);de=1;x=0;y=0;rgb=0;boundary;
  if(dut.done||!dut.bad)$fatal(1,"Incomplete raster accepted");
  for(k=0;k<2;k=k+1)begin
   @(negedge pc);control=0;de=0;repeat(4)@(negedge pc);
   control=16'h4000|k;boundary;
   for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<800;xx=xx+1)begin
    @(negedge pc);de=1;x=xx;y=yy;rgb=color(xx,yy);
   end
   boundary;repeat(6)@(negedge rc);
   if(!dut.done||dut.bad||dut.count!=192000||dut.phase!=0||dut.eye!=k)$fatal(1,"Complete raster invalid");
   @(negedge pc);de=1;x=400*k;y=0;rgb=16'hffff;
   previous=-1;
   for(n=0;n<64010;n=n+1)begin
    @(negedge rc);a=sample[33:18];
    if(sample[47:45]!==6||!sample[44]||sample[39]!==k[0]||a>=64000)$fatal(1,"Bad metadata");
    if(previous!=-1&&a!=(previous+1)%64000)$fatal(1,"Discontinuous address");previous=a;
    for(p=0;p<3;p=p+1)begin
     idx=a*3+p;px=idx%400+400*k;py=idx/400;expected=gray(color(px,py));
     if(((sample>>(p*6))&63)!==expected)$fatal(1,"Packed pixel mismatch eye=%0d addr=%0d pixel=%0d",k,a,p);
    end
   end
  end
  @(negedge pc);control=0;de=0;repeat(6)@(negedge rc);
  if(sample[44])$fatal(1,"Rearm kept stale done");
  control=16'h4000;boundary;@(negedge pc);rst=0;repeat(4)@(negedge rc);
  if(sample[44])$fatal(1,"Reset kept stale done");
  $display("PASS both native 400x480 eyes: 384000 6-bit pixels, 3-pixel packing across rows, partial rejection, read alignment, freeze, rearm/reset");$finish;
 end
 initial begin #60000000;$fatal(1,"Timeout");end
endmodule
