`timescale 1ns/1ps
// Native 400x480 single-eye raster, three 6-bit luminances per 18-bit word.
// The eye is latched at SOF (control[0], 0=left,1=right). Bit14 arms/holds.
// Two eyes are captured sequentially: use only with a stationary calibration board.
module calibration_native_capture(
 input wire pixel_clk,read_clk,rst_n,sof,de,
 input wire [10:0] x,y,
 input wire [15:0] rgb,control,
 output wire [47:0] sample
);
 (* ram_style="block" *) reg [17:0] image [0:63999];
 reg active,done,bad,eye;
 reg [17:0] count;
 reg [15:0] write_address;
 reg [1:0] phase;
 reg [11:0] partial;
 reg [3:0] epoch;
 wire [10:0] lx=x>=400?x-400:x;
 wire selected=de&&x<800&&y<480&&((x>=400)==eye);
 wire [18:0] expected_address=y*400+lx;
 wire [7:0] r={rgb[15:11],rgb[15:13]},g={rgb[10:5],rgb[10:9]},b={rgb[4:0],rgb[4:2]};
 wire [15:0] lum=r*16'd77+g*16'd150+b*16'd29;
 always @(posedge pixel_clk)begin
  if(rst_n&&control[14]&&active&&selected&&!bad&&count<192000&&expected_address==count&&phase==2)
   image[write_address]<={lum[15:10],partial};
 end
 always @(posedge pixel_clk or negedge rst_n)begin
  if(!rst_n)begin
   active<=0;done<=0;bad<=0;eye<=0;count<=0;write_address<=0;phase<=0;partial<=0;epoch<=0;
  end else if(!control[14])begin
   active<=0;done<=0;bad<=0;count<=0;write_address<=0;phase<=0;
  end else if(sof)begin
   if(active)begin active<=0;done<=!bad&&count==192000;bad<=bad||count!=192000;end
   else if(!done&&!bad)begin
    active<=1;eye<=control[0];count<=0;write_address<=0;phase<=0;epoch<=epoch+1'b1;
   end
  end else if(active&&selected)begin
   if(count>=192000||expected_address!=count)bad<=1;
   else begin
    count<=count+1'b1;
    if(phase==0)begin partial[5:0]<=lum[15:10];phase<=1;end
    else if(phase==1)begin partial[11:6]<=lum[15:10];phase<=2;end
    else begin phase<=0;write_address<=write_address+1'b1;end
   end
  end
 end
 (* ASYNC_REG="TRUE" *) reg ds1,ds2,eye1,eye2;
 (* ASYNC_REG="TRUE" *) reg [3:0] es1,es2;
 reg [15:0] rd_address,tag;
 reg [17:0] data;
 always @(posedge read_clk)data<=image[rd_address];
 always @(posedge read_clk or negedge rst_n)begin
  if(!rst_n)begin rd_address<=0;tag<=0;ds1<=0;ds2<=0;es1<=0;es2<=0;eye1<=0;eye2<=0;end
  else begin
   rd_address<=rd_address==63999?0:rd_address+1'b1;tag<=rd_address;
   ds1<=done;ds2<=ds1;es1<=epoch;es2<=es1;eye1<=eye;eye2<=eye1;
  end
 end
 assign sample={3'b110,ds2,es2,eye2,5'd0,tag,data};
endmodule
