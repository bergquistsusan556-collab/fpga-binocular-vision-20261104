`timescale 1ns/1ps
// This build targets the confirmed 0x4384, 800x480 RGB LCD only.
// A dedicated clock buffer replaces the legacy combinational clock mux.
module lcd_clock_800(input wire clk,rst_n,output wire pixel_clk);
 reg divide2;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)divide2<=0;else divide2<=~divide2;
 BUFG pixel_buffer(.I(divide2),.O(pixel_clk));
endmodule
