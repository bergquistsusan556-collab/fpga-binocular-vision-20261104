`timescale 1ns/1ps
module tb_raw_detection;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0;reg [10:0] x=0,y=0;
 reg [7:0] lum=90;
 wire [15:0] rgb;wire found;wire [7:0] tx,ty,tw,th,epoch;wire [1:0] rotation;
 video_tools dut(clk,rst,sof,de,x,y,16'hffff,3'd7,rgb,found,tx,ty,tw,th,rotation,epoch,de,x,y,lum);
 reg images[0:767999];integer a,b,f;
 initial begin
  $readmemh("marker_frames.hex",images);
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<3;f=f+1)begin
   sof=1;@(negedge clk);sof=0;
   for(b=0;b<240;b=b+1)for(a=0;a<200;a=a+1)begin
    @(negedge clk);de=1;x=400+2*a;y=2*b;lum=images[48000+b*200+a]?90:20;
   end
   @(negedge clk);de=0;repeat(230000)@(negedge clk);
  end
  if(!found||tx!=80||ty!=80||tw!=48||th!=48)$fatal(1,"Raw low-light marker not detected independently of enhanced display, threshold=%d",dut.threshold);
  if(dut.threshold!=55)$fatal(1,"Threshold did not follow raw dynamic range");
  $display("PASS original low-light luminance detection with adaptive threshold while enhanced display is completely white");$finish;
 end
endmodule
