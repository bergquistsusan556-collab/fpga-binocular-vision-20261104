`timescale 1ns/1ps
module tb_video_alg_top;
    reg clk = 0;
    reg rst_n = 0;
    reg de = 0;
    reg [10:0] x = 0;
    reg [10:0] y = 0;
    reg [2:0] mode = 0;
    reg [10:0] h_disp = 11'd480;
    reg [10:0] v_disp = 11'd272;
    reg [8:0] cal_scale = 9'd256;
    reg [15:0] din = 0;
    wire [15:0] dout;

    video_alg_top dut(
        .clk(clk), .rst_n(rst_n), .de(de), .x(x), .y(y), .h_disp(h_disp), .v_disp(v_disp), .mode(mode), .din(din), .cal_scale(cal_scale), .filter_enable(1'b1), .dout(dout)
    );

    always #5 clk = ~clk;

    initial begin
        #20 rst_n = 1;
        de = 1; x = 11'd100; y = 11'd100;

        mode = 3'd0; din = 16'hF800; #10;
        if (dout !== 16'hF800) $fatal(1, "RAW failed: %h", dout);

        mode = 3'd6; din = 16'hF800; #10;
        if (dout !== ~16'hF800) $fatal(1, "INVERT failed: %h", dout);

        mode = 3'd1; din = 16'hFFFF; #10;
        if (dout !== 16'hFFFF) $fatal(1, "GRAY white failed: %h", dout);
        din = 16'h0000; #10;
        if (dout !== 16'h0000) $fatal(1, "GRAY black failed: %h", dout);

        mode = 3'd2; din = 16'hFFFF; #10;
        if (dout !== 16'hFFFF) $fatal(1, "BINARY white failed: %h", dout);
        din = 16'h0000; #10;
        if (dout !== 16'h0000) $fatal(1, "BINARY black failed: %h", dout);

        mode = 3'd4; din = 16'hFFFF; x = 11'd0; y = 11'd0; #10;
        #10;
        if (dout !== 16'hF800) $fatal(1, "FRAME_DIFF first frame failed: %h", dout);

        $display("VIDEO_ALG_TB_PASS");
        $finish;
    end
endmodule


