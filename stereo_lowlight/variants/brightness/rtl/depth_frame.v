`timescale 1ns/1ps
// Two 256x256x7 banks: downsample 2x2, display whole field at 4x2 scaling.
// One completed display-frame latency; invalid cells explicitly stored as zero.
module depth_frame(
 input wire clk,rst_n,sof,
 input wire wr_de,wr_valid,
 input wire [10:0] wx,wy,
 input wire [5:0] disparity,
 input wire [10:0] dx,dy,
 output reg [6:0] sample,
 output reg ready
);
 (* ram_style="block" *) reg [6:0] mem[0:131071];
 reg bank,seen;
 wire [16:0] wa={bank,wy[8:1],wx[8:1]};
 wire [16:0] ra={~bank,dy[8:1],dx[9:2]};
 always @(posedge clk) begin
  if(wr_de&&!wx[0]&&!wy[0]&&wx<512&&wy<512)
    mem[wa]<=wr_valid?{1'b1,disparity}:7'd0;
  sample<=mem[ra];
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n)begin bank<=0;seen<=0;ready<=0;end
  else if(sof)begin bank<=~bank;ready<=seen;seen<=1;end
 end
endmodule
