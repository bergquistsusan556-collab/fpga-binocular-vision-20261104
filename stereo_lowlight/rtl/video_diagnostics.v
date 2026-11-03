`timescale 1ns/1ps
// Frame-level sums compare the same raw and enhanced pixels before overlays.
module video_diagnostics(
 input wire clk,rst_n,sof,raw_de,enhanced_de,match_de,match_valid,
 input wire [7:0] raw_y,
 input wire [15:0] enhanced_rgb,
 output reg [95:0] snapshot
);
 wire [7:0] r={enhanced_rgb[15:11],enhanced_rgb[15:13]};
 wire [7:0] g={enhanced_rgb[10:5],enhanced_rgb[10:9]};
 wire [7:0] b={enhanced_rgb[4:0],enhanced_rgb[4:2]};
 wire [15:0] ys=77*r+150*g+29*b;
 reg [26:0] raw_sum,enhanced_sum;
 reg [19:0] pixels;
 reg [17:0] matches;
 reg [3:0] frames;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin raw_sum<=0;enhanced_sum<=0;pixels<=0;matches<=0;frames<=0;snapshot<=0;end
  else if(sof)begin
   snapshot<={frames,matches,pixels,enhanced_sum,raw_sum};
   frames<=frames+1'b1;raw_sum<=0;enhanced_sum<=0;pixels<=0;matches<=0;
  end else begin
   if(raw_de)raw_sum<=raw_sum+raw_y;
   if(enhanced_de)begin enhanced_sum<=enhanced_sum+ys[15:8];pixels<=pixels+1'b1;end
   if(match_de&&match_valid)matches<=matches+1'b1;
  end
 end
endmodule
