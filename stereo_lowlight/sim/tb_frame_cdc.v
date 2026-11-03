`timescale 1ns/1ps
module tb_frame_cdc;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,a=0,b=0,c=0;
 integer ca=0,cb=0,cc=0;
 ddr3_rw dut(.ui_clk(clk),.ui_clk_sync_rst(reset),.init_calib_complete(1'b0),
  .app_rdy(1'b0),.app_wdf_rdy(1'b0),.app_rd_data_valid(1'b0),.app_rd_data(128'd0),
  .wfifo_rcount_1(11'd0),.wfifo_rcount_2(11'd0),.rfifo_wcount_1(11'd0),.rfifo_wcount_2(11'd0),
  .wr_load_1(a),.wr_load_2(b),.rd_load(c),.wr_clk_1(clk),.wr_clk_2(clk),
  .app_addr_rd_min(28'd0),.app_addr_rd_max(28'd192000),.rd_bust_len(8'd100),
  .app_addr_wr_min(28'd0),.app_addr_wr_max(28'd192000),.wr_bust_len(8'd100),
  .ddr3_read_valid(1'b1),.ddr3_pingpang_en(1'b1));
 always @(negedge clk)begin
  if(dut.wr_rst_1)ca=ca+1;
  if(dut.wr_rst_2)cb=cb+1;
  if(dut.rd_rst)cc=cc+1;
 end
 initial begin
  repeat(4)@(negedge clk);reset=0;
  #3;a=1;#7;b=1;#7;c=1;
  repeat(12)@(negedge clk);a=0;b=0;c=0;
  repeat(12)@(negedge clk);
  if(ca!=1||cb!=1||cc!=1)$fatal(1,"Frame CDC duplicated/lost event: %0d %0d %0d",ca,cb,cc);
  $display("PASS asynchronous frame pulse synchronization and single-event generation");$finish;
 end
endmodule
