`timescale 1ns/1ps
module tb_stereo_depth;
    reg clk = 0;
    reg rst_n = 0;
    reg de = 0;
    reg [10:0] x = 0;
    reg [10:0] y = 0;
    reg [10:0] h_disp = 11'd800;
    reg [10:0] v_disp = 11'd480;
    reg [15:0] din = 0;
    reg red_mask = 0;
    wire [15:0] dout;
    wire [15:0] distance_cm;
    wire distance_valid;
    wire [5:0] disparity_locked;

    stereo_red_ruler #(.FOCAL_PX(346), .BASELINE_MM(60), .UPDATE_FRAMES(1)) dut (
        .clk(clk), .rst_n(rst_n), .de(de), .x(x), .y(y),
        .h_disp(h_disp), .v_disp(v_disp), .cal_scale(9'd256), .filter_enable(1'b1), .red_mask(red_mask), .din(din),
        .l_roi_cx(11'd0), .l_roi_cy(11'd0), .r_roi_cx(11'd0), .r_roi_cy(11'd0), .l_roi_valid(1'b0), .r_roi_valid(1'b0),
        .dout(dout), .distance_cm(distance_cm),
        .distance_valid(distance_valid), .disparity_locked(disparity_locked)
    );

    always #5 clk = ~clk;

    function [7:0] luma_at;
        input integer idx;
        integer v;
        begin
            v = (idx * 37 + (idx >> 3) * 13 + 29) & 255;
            luma_at = v[7:0];
        end
    endfunction

    function [15:0] rgb565_gray;
        input [7:0] l;
        begin
            rgb565_gray = {l[7:3], l[7:2], l[7:3]};
        end
    endfunction

    function [15:0] rgb565_red;
        input integer idx;
        integer r, g, b;
        begin
            r = 180 + (idx & 63);
            g = 20 + (idx & 15);
            b = 10 + (idx & 7);
            rgb565_red = {r[7:3], g[7:2], b[7:3]};
        end
    endfunction

    function [15:0] rgb565_scene;
        input integer idx;
        integer v;
        begin
            if ((idx >= 180) && (idx <= 240))
                rgb565_scene = rgb565_red(idx);
            else begin
                v = 30 + (idx & 31);
                rgb565_scene = {v[7:3], v[7:2], v[7:3]};
            end
        end
    endfunction
    integer xx, yy, local_x, left_x;
    initial begin
        #20 rst_n = 1;

        // One textured ROI row is enough for the histogram. The right image
        // is the left image shifted by 24 pixels, so disparity locks at 24.
        yy = 240;
        for (xx = 0; xx < 800; xx = xx + 1) begin
            de = 1;
            x = xx[10:0];
            y = yy[10:0];
            if (xx < 400) begin
                din = rgb565_scene(xx); red_mask = (xx >= 180) && (xx <= 240);
            end
            else begin
                local_x = xx - 400;
                left_x = local_x + 24;
                if (left_x > 399)
                    left_x = 399;
                din = rgb565_scene(left_x); red_mask = (left_x >= 180) && (left_x <= 240);
            end
            #10;
        end
        de = 0;
        #30;

        // Move y to the last line, then wrap to the first line. The
        // simplified module locks distance from the completed previous frame.
        de = 1; x = 11'd0; y = 11'd479; din = 16'h0000; red_mask = 1'b0; #10;
        de = 1; x = 11'd0; y = 11'd0;   din = 16'h0000; red_mask = 1'b0; #10;
        de = 0;
        #200;
        $display("DEBUG l_count=%0d r_count=%0d l_center=%0d r_center=%0d red_disp=%0d",
                 dut.l_count, dut.r_count, dut.l_center, dut.r_center, dut.red_disp);
        if (!distance_valid)
            $fatal(1, "distance_valid did not assert");
        if ((disparity_locked < 23) || (disparity_locked > 25))
            $fatal(1, "unexpected disparity: %0d (expected 24)", disparity_locked);
        if ((distance_cm < 82) || (distance_cm > 90))
            $fatal(1, "unexpected distance: %0d cm disparity %0d (expected ~86)", distance_cm, disparity_locked);

        $display("STEREO_TB_PASS disparity=%0d distance_cm=%0d", disparity_locked, distance_cm);

        // Cross two frame boundaries with no red target and verify reset.
        de = 1; x = 11'd0; y = 11'd479; din = 16'h0000; #10;
        de = 1; x = 11'd0; y = 11'd0;   din = 16'h0000; #10;
        de = 1; x = 11'd0; y = 11'd479; din = 16'h0000; #10;
        de = 1; x = 11'd0; y = 11'd0;   din = 16'h0000; #10;
        de = 0; #20;
        if (distance_valid || (distance_cm != 16'd0))
            $fatal(1, "distance did not reset without red target");
        $display("RESET_TB_PASS distance_cm=%0d", distance_cm);
        $finish;
    end
endmodule





















