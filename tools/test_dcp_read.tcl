set dcp1 [file normalize {.\Verilog\60_top_dual_ov5640_hdmi\prj\top_dual_ov5640_hdmi.srcs\sources_1\ip\clk_wiz_0_1\clk_wiz_0.dcp}]
set dcp2 [file normalize {.\Verilog\60_top_dual_ov5640_hdmi\prj\top_dual_ov5640_hdmi.srcs\sources_1\ip\rd_fifo\rd_fifo.dcp}]
set dcp3 [file normalize {.\Verilog\60_top_dual_ov5640_hdmi\prj\top_dual_ov5640_hdmi.srcs\sources_1\ip\wr_fifo\wr_fifo.dcp}]
puts "DCP1=$dcp1"
if {[catch {read_checkpoint -cell u_clk_wiz_0 $dcp1} e]} { puts "CLK_DCP_FAIL=$e" } else { puts "CLK_DCP_OK" }
if {[catch {read_checkpoint -cell u_rd_fifo $dcp2} e]} { puts "RD_DCP_FAIL=$e" } else { puts "RD_DCP_OK" }
if {[catch {read_checkpoint -cell u_wr_fifo $dcp3} e]} { puts "WR_DCP_FAIL=$e" } else { puts "WR_DCP_OK" }
exit 0
