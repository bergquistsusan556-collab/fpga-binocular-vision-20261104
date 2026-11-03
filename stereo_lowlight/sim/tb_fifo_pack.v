`timescale 1ns/1ps
module tb_fifo_pack;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,we=0,wrload=0;
 reg [15:0] pixel=0;
 wire [127:0] dout;wire [9:0] rc,wc;wire [15:0] rd;
 ddr3_fifo_ctrl dut(.rst_n(rst),.wr_clk(clk),.rd_clk(clk),.ui_clk(clk),
 .wr_en(we),.wrdata(pixel),.rfifo_din(128'd0),.rdata_req(1'b0),
 .rfifo_wren(1'b0),.wfifo_rden(1'b0),.rd_load(1'b0),.wr_load(wrload),
 .rfifo_wcount(rc),.wfifo_rcount(wc),.wfifo_dout(dout),.rddata(rd));
 integer i,j,packets=0;
 reg check=0;
 reg [127:0] expected;
 reg [15:0] expected_pixel;
 always @(posedge clk)if(check&&dut.u_wr_fifo.wr_en)begin
  expected=0;
  for(j=0;j<8;j=j+1)begin expected_pixel=16'h4000+packets*8+j;expected={expected[111:0],expected_pixel};end
  if(dut.u_wr_fifo.din!==expected)$fatal(1,"Bad pack %d got=%h expected=%h",packets,dut.u_wr_fifo.din,expected);
  packets=packets+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(i=0;i<5;i=i+1)begin @(negedge clk);we=1;pixel=i;end
  @(negedge clk);we=0;wrload=1;
  repeat(24)@(negedge clk);wrload=0;
  repeat(24)@(negedge clk);check=1;
  for(i=0;i<32;i=i+1)begin @(negedge clk);we=1;pixel=16'h4000+i;end
  @(negedge clk);we=0;
  repeat(5)@(negedge clk);
  if(packets!=4)$fatal(1,"Missing packets %d",packets);
  $display("PASS FIFO partial-frame discard and 32-pixel packing");$finish;
 end
endmodule
module wr_fifo(input rst,wr_clk,rd_clk,input [127:0]din,input wr_en,rd_en,
 output [127:0]dout,output full,empty,output [9:0]rd_data_count,wr_data_count,
 output wr_rst_busy,rd_rst_busy);
 assign dout=0;assign full=0;assign empty=0;assign rd_data_count=0;assign wr_data_count=0;
 assign wr_rst_busy=0;assign rd_rst_busy=0;
endmodule
module rd_fifo(input rst,wr_clk,rd_clk,input [127:0]din,input wr_en,rd_en,
 output [127:0]dout,output full,empty,output [9:0]rd_data_count,wr_data_count,
 output wr_rst_busy,rd_rst_busy);
 assign dout=0;assign full=0;assign empty=0;assign rd_data_count=0;assign wr_data_count=0;
 assign wr_rst_busy=0;assign rd_rst_busy=0;
endmodule
