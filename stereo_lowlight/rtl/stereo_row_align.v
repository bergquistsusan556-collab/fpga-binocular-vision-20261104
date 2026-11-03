`timescale 1ns/1ps
// Limited translational row compensation before matching, not lens rectification.
// Delay either eye by 0..31 rows. 400-pixel stride avoids padding RAM to 512.
// Each memory word includes the texture validity of the stored Census code.
module stereo_row_align(
 input wire clk,rst_n,de,
 input wire [10:0] x,y,width,
 input wire [7:0] code,
 input wire textured,
 input wire [7:0] control,
 output reg out_de,
 output reg [10:0] out_x,out_y,
 output reg [7:0] out_code,
 output reg out_textured
);
 wire right=x>=(width>>1);
 wire [10:0] local_x=right?x-(width>>1):x;
 wire selected=right==control[5];
 wire [4:0] read_row=y[4:0]-control[4:0];
 wire [13:0] wa=y[4:0]*14'd400+local_x;
 wire [13:0] ra=read_row*14'd400+local_x;
 (* ram_style="block" *) reg [8:0] rows[0:12799];
 reg [8:0] q;
 always @(posedge clk)if(de&&selected&&local_x<400)begin
  rows[wa]<={textured,code};q<=rows[ra];
 end
 reg v1,tex1,use1,ready1;
 reg [7:0] code1;
 reg [10:0] x1,y1;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   v1<=0;tex1<=0;use1<=0;ready1<=0;code1<=0;x1<=0;y1<=0;
   out_de<=0;out_x<=0;out_y<=0;out_code<=0;out_textured<=0;
  end else begin
   v1<=de;x1<=x;y1<=y;code1<=code;tex1<=textured;
   use1<=control[7]&&selected&&control[4:0]!=0;
   ready1<=!(control[7]&&control[4:0]!=0)||y>={6'd0,control[4:0]}+11'd2;
   out_de<=v1;out_x<=x1;out_y<=y1;
   out_code<=use1?q[7:0]:code1;
   // Both eyes must reject the rows with no corresponding shifted sample.
   out_textured<=ready1&&(use1?q[8]:tex1);
  end
 end
endmodule
