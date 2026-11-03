`timescale 1ns/1ps
module tb_lowlight_reference;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0,en=1;
 reg [10:0] x=0,y=0;
 reg [15:0] rgb;
 reg [7:0] lum,hist;
 reg [11:0] sum;
 reg [3:0] weight;
 wire ode;wire [10:0] ox,oy;wire [15:0] result;
 lowlight_fixed dut(clk,rst,de,en,x,y,rgb,lum,hist,sum,weight,ode,ox,oy,result);
 reg [15:0] expected[0:73727];
 integer f,ret,i=0,count=0,index;
 reg [15:0] gold;
 always @(negedge clk)if(ode)begin
   index=oy*1024+ox;
   if(result!==expected[index])$fatal(1,"Independent enhancement reference mismatch vector=%0d in=%h got=%h expected=%h",index,index[15:0],result,expected[index]);
   count=count+1;
 end
 initial begin
  rgb=0;lum=0;hist=0;sum=0;weight=4;
  f=$fopen("lowlight_reference.txt","r");if(!f)$fatal(1,"Missing reference vectors");
  repeat(4)@(negedge clk);rst=1;
  while(!$feof(f))begin
   @(negedge clk);
   ret=$fscanf(f,"%h %h %h %h %h %h\n",rgb,lum,sum,weight,hist,gold);
   if(ret==6)begin de=1;x=i%1024;y=i/1024;expected[i]=gold;i=i+1;end
   else de=0;
   if(i%97==0)begin @(negedge clk);de=0;repeat(2)@(negedge clk);end
  end
  @(negedge clk);de=0;repeat(10)@(negedge clk);
  if(count!=73728)$fatal(1,"Missing enhanced pixels %0d",count);
  $display("PASS 73728 independent enhanced RGB565 vectors, all colors, varied weights/history and blanking");$finish;
 end
endmodule
