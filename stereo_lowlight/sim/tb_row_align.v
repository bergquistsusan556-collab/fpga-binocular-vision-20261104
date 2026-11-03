`timescale 1ns/1ps
module tb_row_align;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0;reg [10:0] x=0,y=0;reg [7:0] code=0,control=0;reg tex=0;
 wire ode,ot;wire [10:0] ox,oy;wire [7:0] oc;
 stereo_row_align dut(clk,rst,de,x,y,11'd800,code,tex,control,ode,ox,oy,oc,ot);
 integer k,xx,yy,sy,eye,count=0,checked=0;
 function [7:0] pattern;
 input integer px,py,e;
 begin pattern=(py*53+px*17+e*29)^(py*7+px/3);end
 endfunction
 always @(negedge clk)if(ode)begin
  if(ox!=count%800||oy!=count/800)$fatal(1,"Alignment DE/coordinate mismatch");
  eye=ox>=400;sy=oy;
  if(control[7]&&eye==control[5]&&control[4:0]!=0)sy=oy-control[4:0];
  if(sy>=0&&oc!==pattern(ox%400,sy,eye))$fatal(1,"Row compensation mismatch config=%h x/y=%0d/%0d got=%h",control,ox,oy,oc);
  if(ot!==((!control[7]||control[4:0]==0||oy>=control[4:0]+2)&&((ox%400+sy)%5!=0)))$fatal(1,"Texture/border validity mismatch");
  count=count+1;checked=checked+1;
 end
 initial begin
  for(k=0;k<6;k=k+1)begin
   @(negedge clk);rst=0;de=0;repeat(3)@(negedge clk);count=0;rst=1;
   case(k)0:control=0;1:control=8'h80;2:control=8'h81;3:control=8'h98;4:control=8'h9f;5:control=8'hb8;endcase
   for(yy=0;yy<75;yy=yy+1)begin
    for(xx=0;xx<800;xx=xx+1)begin
     @(negedge clk);de=1;x=xx;y=yy;code=pattern(xx%400,yy,xx>=400);tex=(xx%400+yy)%5!=0;
    end
    @(negedge clk);de=0;repeat(4)@(negedge clk);
   end
   repeat(8)@(negedge clk);if(count!=60000)$fatal(1,"Missing aligned pixels");
  end
  $display("PASS row compensation: 360000 pixels, bypass/0/1/24/31 rows, either eye, ring wrap, borders, DE bubbles");$finish;
 end
endmodule
