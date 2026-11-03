`timescale 1ns/1ps
// Shared binocular CDF avoids independent left/right colour and brightness drift.
// 64 bins, one completed frame's LUT applied to the following frame.
module luma_histogram(
 input wire clk,rst_n,de,sof,
 input wire [7:0] lum,
 output wire [7:0] mapped
);
 reg [19:0] bins[0:63];
 reg [7:0] lut[0:63];
 reg [19:0] count,total,cdf;
 reg [5:0] idx;
 reg busy,have_frame;
 reg [27:0] numerator;
 reg [19:0] accum;
 integer i;
 // Per-frame constant normalization (computed once, sequentially below).
 // Scanning one bin costs 29 clocks; vertical blank is >1800 clocks.
 reg [5:0] bitpos;
 reg [28:0] remn;
 reg [27:0] quotient,dividend;
 reg [1:0] state;
 wire [28:0] trial={remn[27:0],dividend[27]};
 assign mapped=lut[lum[7:2]];
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    count<=0;total<=0;cdf<=0;idx<=0;busy<=0;have_frame<=0;state<=0;
    numerator<=0;accum<=0;bitpos<=0;remn<=0;quotient<=0;dividend<=0;
    for(i=0;i<64;i=i+1) begin bins[i]<=0;lut[i]<=i*4+2;end
  end else begin
    if(de&&!busy) begin bins[lum[7:2]]<=bins[lum[7:2]]+1'b1;count<=count+1'b1;end
    // sof is the vertical-blank pulse, not the first active pixel.
    if(sof&&!busy) begin
      total<=count;count<=0;cdf<=0;idx<=0;busy<=1;state<=0;
    end else if(busy) begin
      case(state)
       0: begin
         accum=cdf+bins[idx];
         cdf<=accum;bins[idx]<=0;
         dividend<=accum*8'd255;quotient<=0;remn<=0;bitpos<=27;state<=1;
       end
       1: begin
         dividend<=dividend<<1;
         if(trial>={9'b0,total} && total!=0) begin remn<=trial-total;quotient<={quotient[26:0],1'b1};end
         else begin remn<=trial;quotient<={quotient[26:0],1'b0};end
         if(bitpos==0) state<=2;else bitpos<=bitpos-1'b1;
       end
       2: begin
         if(total!=0) lut[idx]<=quotient[7:0];
         if(idx==63) begin busy<=0;have_frame<=1;end
         else begin idx<=idx+1'b1;state<=0;end
       end
      endcase
    end
  end
 end
endmodule
