`timescale 1ns/1ps
// Camera-domain measurements; Gray counters cross to the diagnostic clock.
// Pixel counts/checksum are latched for a whole frame, not used as control.
module camera_activity(
 input wire pclk,rst_n,vsync,valid,
 input wire [15:0] data,
 output reg [7:0] frame_gray,
 output reg [15:0] clock_gray,
 output reg [19:0] frame_pixels,
 output reg [15:0] frame_hash
);
 reg vd;
 reg [7:0] frames;
 reg [15:0] clocks,hash;
 reg [19:0] pixels;
 always @(posedge pclk or negedge rst_n)begin
  if(!rst_n)begin
   vd<=0;frames<=0;clocks<=0;hash<=0;pixels<=0;
   frame_gray<=0;clock_gray<=0;frame_pixels<=0;frame_hash<=0;
  end else begin
   vd<=vsync;clocks<=clocks+1'b1;
   clock_gray<=((clocks+16'd1)>>1)^(clocks+16'd1);
   if(vsync&&!vd)begin
    frames<=frames+1'b1;
    frame_gray<=((frames+8'd1)>>1)^(frames+8'd1);
    frame_pixels<=pixels;frame_hash<=hash;pixels<=0;hash<=0;
   end else if(valid)begin
    pixels<=pixels+1'b1;hash<={hash[14:0],hash[15]}^data;
   end
  end
 end
endmodule
