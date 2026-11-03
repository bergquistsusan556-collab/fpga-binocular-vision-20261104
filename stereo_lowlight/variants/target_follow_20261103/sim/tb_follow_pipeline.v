`timescale 1ns/1ps
// Real raster -> enhancement -> ID7 localization -> moving Census ROI -> OSD.
module tb_follow_pipeline;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sof=0,de=0;
 reg [10:0] x=0,y=0;reg [15:0] rgb=0;
 wire ode,dv,md,mv;wire [10:0] ox,oy;wire [15:0] output_rgb,cm;
 wire [5:0] dominant,disp;wire [95:0] metrics;wire [63:0] roi;
 fusion_pipeline dut(clk,rst,sof,de,x,y,11'd800,11'd480,rgb,3'd7,1'b0,9'd256,
   ode,ox,oy,output_rgb,cm,dv,dominant,md,mv,disp,metrics,roi,8'd0);
 reg images[0:767999];
 integer image_no=1,mark_x=80,mark_y=80,a,b,f;
 always @(negedge clk)if(dv&&!dut.position_consistent)
   $fatal(1,"Distance from outside the current target texture was displayed");
 function bit_at;
 input integer xx,yy;
 integer px,py;reg [31:0] z;
 begin
  bit_at=1;
  if(xx>=0&&xx<400&&yy>=0&&yy<480)begin
   px=xx/2;py=yy/2;bit_at=images[image_no*48000+py*200+px];
   if(image_no!=0&&px>=mark_x&&px<mark_x+48&&py>=mark_y+54&&py<mark_y+60)begin
    z=(px-mark_x+48*(py-mark_y-54)+1)*32'h45d9f3b;
    z=(z^(z>>16))*32'h45d9f3b;bit_at=^(z^(z>>16));
   end
  end
 end endfunction
 task pulse;
 begin @(negedge clk);sof=1;@(negedge clk);sof=0;end endtask
 task frame;
 begin
  pulse;
  for(b=0;b<480;b=b+1)begin
   for(a=0;a<800;a=a+1)begin
    @(negedge clk);de=1;x=a;y=b;
    rgb=(a<400?bit_at(a-12,b):bit_at(a-400,b))?16'hffff:0;
   end
   @(negedge clk);de=0;
  end
  repeat(180000)@(negedge clk);
 end endtask
 task check;
 input integer xx,yy;
 begin
  if(!dut.target_valid||dut.tx!=xx||dut.ty!=yy||dut.tw!=48||dut.th!=48)
   $fatal(1,"Full pipeline target not localized %b %d,%d %dx%d",dut.target_valid,dut.tx,dut.ty,dut.tw,dut.th);
  if(dut.rcx!=2*xx+48||dut.rcy!=2*yy+114)
   $fatal(1,"Texture ROI did not follow target %d,%d",dut.rcx,dut.rcy);
  if(!dv||cm<97||cm>99)$fatal(1,"Followed metric distance invalid %b %d; ROI %h",dv,cm,roi);
 end endtask
 initial begin
  $readmemh("marker_frames.hex",images);
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<4;f=f+1)frame;
  check(80,80);
  image_no=2;mark_x=39;mark_y=51;
  for(f=0;f<4;f=f+1)frame;
  check(39,51);
  image_no=0;frame;pulse;repeat(200)@(negedge clk);
  if(dut.target_valid||dv||cm!=0)$fatal(1,"Full pipeline retained distance after marker loss");
  $display("PASS real enhanced stereo raster, ID7 nongrid movement, auxiliary texture ROI and Census distance stay linked, disappearance clears range");$finish;
 end
 initial begin #120000000;$fatal(1,"Following integration timeout");end
endmodule
