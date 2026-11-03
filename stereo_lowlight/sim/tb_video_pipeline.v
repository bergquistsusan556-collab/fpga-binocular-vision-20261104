`timescale 1ns/1ps
module tb_video_pipeline;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0;reg [10:0] x=0,y=0;reg [15:0] rgb=0;
 reg [2:0] mode=4;
 wire ode,dv,md,mv;wire [10:0] ox,oy;wire [15:0] out_rgb,cm;
 wire [5:0] dominant,disp;wire [95:0] metrics;wire [63:0] roi;
 fusion_pipeline dut(clk,rst,sof,de,x,y,11'd800,11'd480,rgb,mode,1'b0,9'd256,
   ode,ox,oy,out_rgb,cm,dv,dominant,md,mv,disp,metrics,roi,8'd0);
 integer a,b,m,count=0;
 reg [15:0] expected;
 always @(negedge clk)if(ode)begin
   if(ox!=count%800||oy!=count/800)$fatal(1,"New mode changed pixel cadence");
   case(mode)
    4:expected=ox[0]?16'hffff:0;
    5:expected=0;
    6:expected=16'h7bef;
    default:expected=16'hffff;
   endcase
   if(out_rgb!==expected)$fatal(1,"Mode %d RGB misaligned at %d,%d got %h expected %h",mode,ox,oy,out_rgb,expected);
   count=count+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(m=4;m<=7;m=m+1)begin
   mode=m;sof=1;@(negedge clk);sof=0;count=0;
   repeat(2000)@(negedge clk);
   for(b=0;b<4;b=b+1)begin
    for(a=0;a<800;a=a+1)begin @(negedge clk);de=1;x=a;y=b;rgb=(m==4&&!a[0])?0:16'hffff;end
    @(negedge clk);de=0;repeat(256)@(negedge clk);
   end
   repeat(30)@(negedge clk);
   if(count!=3200)$fatal(1,"Missing output in new mode %d",m);
  end
  $display("PASS all four new modes through complete fusion latency, exact RGB/DE and coordinates");$finish;
 end
endmodule
