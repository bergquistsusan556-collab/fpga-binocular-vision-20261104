`timescale 1ns/1ps
// Right-reference disparity: match R(x) to L(x+d), d=0..63.
// 3x3 Census + fifteen-column rolling cost; fully pipelined top-two tree.
// Border, low texture, high cost and ambiguous matches are explicitly invalid.
module stereo_census(
 input wire clk,rst_n,de,
 input wire [10:0] x,y,width,
 input wire [7:0] census,
 input wire textured,
 input wire reverse,
 output wire out_de,out_valid,
 output wire [10:0] out_x,out_y,
 output wire [5:0] disparity
);
 (* ram_style="distributed" *) reg [7:0] left_row[0:511];
 reg [7:0] win[0:63];
 wire [10:0] half=width>>1;
 wire right=(x>=half);
 wire [10:0] rx=x-half;
 function [3:0] pop8;
 input [7:0] a;
 begin pop8={3'b0,a[0]}+a[1]+a[2]+a[3]+a[4]+a[5]+a[6]+a[7];end
 endfunction
 wire [3:0] pc[0:63];
 reg [6:0] best[0:126],second[0:126];
 reg [5:0] index[0:126];
 reg [6:0] vp,good;
 reg [10:0] xp[0:6],yp[0:6];
 integer i;
 genvar d,n;
 generate for(d=0;d<64;d=d+1) begin:cost
  assign pc[d]=pop8(census^win[d]);
  // No reset on the delay line permits SRL inference. At each row start the
  // accumulator restarts and ignores old history until fifteen samples arrive.
  reg [3:0] history[0:14];
  reg [6:0] running;
  wire [7:0] next_cost=rx==0?{4'd0,pc[d]}:
       ({1'b0,running}+{4'd0,pc[d]}-(rx>=15?{4'd0,history[14]}:8'd0));
  integer h;
  always @(posedge clk) begin
    if(de&&right) begin
      history[0]<=pc[d];
      for(h=1;h<15;h=h+1)history[h]<=history[h-1];
      running<=next_cost[6:0];
      best[63+d]<=((reverse ? rx<d+16 : rx+d>=half)||(rx<16)||(y<2))?7'd127:next_cost[6:0];
      second[63+d]<=127;index[63+d]<=d;
    end
  end
 end
 for(n=0;n<63;n=n+1) begin:tree
  wire [6:0] a=best[2*n+1],b=best[2*n+2];
  always @(posedge clk) begin
    if(a<=b) begin
      best[n]<=a;index[n]<=index[2*n+1];
      second[n]<=(second[2*n+1]<b)?second[2*n+1]:b;
    end else begin
      best[n]<=b;index[n]<=index[2*n+2];
      second[n]<=(second[2*n+2]<a)?second[2*n+2]:a;
    end
  end
 end endgenerate
 always @(posedge clk) begin
  if(de&&!right) begin
    left_row[x]<=census;
    if(reverse) begin
      if(x==0)win[0]<=census;
    end else if(x<64) begin
      for(i=0;i<63;i=i+1)win[i]<=win[i+1];
      win[63]<=census;
    end
  end else if(de&&right) begin
    if(reverse)begin
      for(i=1;i<64;i=i+1)win[i]<=win[i-1];
      win[0]<=(rx+1<half)?left_row[rx+1]:8'd0;
    end else begin
      for(i=0;i<63;i=i+1)win[i]<=win[i+1];
      win[63]<=(rx+64<half)?left_row[rx+64]:8'd0;
    end
  end
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    vp<=0;good<=0;
    for(i=0;i<7;i=i+1)begin xp[i]<=0;yp[i]<=0;end
  end else begin
    vp<={vp[5:0],de&&right};
    good<={good[5:0],textured&&(rx>=16)&&(y>=2)};
    xp[0]<=rx;yp[0]<=y;
    for(i=1;i<7;i=i+1)begin xp[i]<=xp[i-1];yp[i]<=yp[i-1];end
  end
 end
 assign out_de=vp[6];
 assign out_valid=vp[6]&&good[6]&&(best[0]<=45)&&
                   ({1'b0,second[0]}>={1'b0,best[0]}+8'd6);
 assign out_x=xp[6];assign out_y=yp[6];assign disparity=index[0];
endmodule
