// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
// Date        : Tue Nov  3 17:34:30 2026
// Host        : LAPTOP-AHK905FP running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub {c:/Users/Li
//               Jiahao/Documents/ChatGPT/fpga/stereo_lowlight/build/front_fit_20261103/generated_ip/stereo_control/stereo_control_stub.v}
// Design      : stereo_control
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35tfgg484-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "vio,Vivado 2019.1" *)
module stereo_control(clk, probe_out0)
/* synthesis syn_black_box black_box_pad_pin="clk,probe_out0[15:0]" */;
  input clk;
  output [15:0]probe_out0;
endmodule
