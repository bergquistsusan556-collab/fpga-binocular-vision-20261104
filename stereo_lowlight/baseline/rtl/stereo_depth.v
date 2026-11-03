`timescale 1ns/1ps
//------------------------------------------------------------------------------
// stereo_depth
//   Red-target stereo disparity / distance for the dual-OV5640 LCD.
//
// Input stream layout (one LCD pixel per de cycle):
//   x =   0..511 : left camera
//   x = 512..1023: right camera, local right coordinate xr = x-512
//
// Algorithm:
//   - The left row is stored as 8-bit luma.
//   - A 66-pixel sliding window provides L[xr+d-1 .. xr+d+1].
//   - A 3x1 SAD is evaluated in parallel for d=0..63.
//   - A small tournament tree finds the minimum SAD.
//   - Only red Cr/Cb pixels inside a fixed central box are accumulated.
//   - At the end of a frame the histogram mode is converted to cm using
//     distance = focal_px * baseline_mm / 10 / disparity.
//
// IMPORTANT CALIBRATION:
//   FOCAL_PX and BASELINE_MM are defaults, not camera-specific calibration.
//------------------------------------------------------------------------------
module stereo_depth #(
    parameter integer FOCAL_PX    = 443,
    parameter integer BASELINE_MM = 60
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        de,
    input  wire [10:0] x,
    input  wire [10:0] y,
    input  wire [10:0] h_disp,
    input  wire [10:0] v_disp,
    input  wire [15:0] din,
    output reg  [15:0] dout,
    output reg  [15:0] distance_cm,
    output reg         distance_valid,
    output reg  [5:0]  disparity_locked
);

    localparam [10:0] ROI_HALF_W    = 11'd160;
    localparam [10:0] ROI_HALF_H    = 11'd200;
    localparam [7:0]  COST_THRESH   = 8'd96;
    localparam [7:0]  TEXTURE_THRESH= 8'd10;
    localparam [15:0] MIN_RED_PIX   = 16'd2;
    localparam integer DIST_CONST_CM = (FOCAL_PX * BASELINE_MM + 5) / 10;

    wire [4:0] r5 = din[15:11];
    wire [5:0] g6 = din[10:5];
    wire [4:0] b5 = din[4:0];
    wire [7:0] r8 = {r5, r5[4:2]};
    wire [7:0] g8 = {g6, g6[5:4]};
    wire [7:0] b8 = {b5, b5[4:2]};
    wire [9:0] lum_sum = {1'b0, r8} + {g8, 1'b0} + {1'b0, b8};
    wire [7:0] lum = lum_sum[9:2];

    // Approximate YCbCr red/orange detector with proper clamping.
    wire signed [11:0] cb_calc = 12'sd128
        - $signed({4'b0, r8[7:1]})
        - $signed({4'b0, g8[7:2]})
        + $signed({4'b0, b8[7:1]});
    wire signed [11:0] cr_calc = 12'sd128
        + $signed({4'b0, r8[7:1]})
        - $signed({4'b0, g8[7:3]})
        - $signed({4'b0, b8[7:4]});
    wire [7:0] cb8 = (cb_calc < 0) ? 8'd0 :
                     ((cb_calc > 12'sd255) ? 8'd255 : cb_calc[7:0]);
    wire [7:0] cr8 = (cr_calc < 0) ? 8'd0 :
                     ((cr_calc > 12'sd255) ? 8'd255 : cr_calc[7:0]);
    wire [8:0] rg_diff = {1'b0, r8} - {1'b0, g8};
    wire [8:0] rb_diff = {1'b0, r8} - {1'b0, b8};
    wire red_pix = (r8 > 8'd150) && (g8 < 8'd110) && (b8 < 8'd110) &&
                   (rg_diff > 9'd60) && (rb_diff > 9'd60) &&
                   (cr8 > 8'd160) && (cb8 < 8'd110) &&
                   (cr8 > (cb8 + 8'd60));

    wire [10:0] half_x = h_disp >> 1;
    wire [10:0] xr = x - half_x;
    wire        right_half = (x >= half_x);
    wire        stereo_pixel = de && right_half && (xr >= 11'd3) &&
                              (xr <= (half_x - 11'd65));

    // Fixed central aiming box (240x160 on the current 800x480 LCD).
    wire [11:0] cur_local_x  = {1'b0, x} - {1'b0, half_x};
    wire [11:0] cur_center_x = {1'b0, half_x} >> 1;
    wire [11:0] cur_center_y = {1'b0, v_disp} >> 1;
    wire [11:0] cur_roi_l = cur_center_x - ROI_HALF_W;
    wire [11:0] cur_roi_r = cur_center_x + ROI_HALF_W;
    wire [11:0] cur_roi_t = cur_center_y - ROI_HALF_H;
    wire [11:0] cur_roi_b = cur_center_y + ROI_HALF_H;
    wire cur_in_roi = de && (x >= half_x) &&
                      (cur_local_x >= cur_roi_l) && (cur_local_x <= cur_roi_r) &&
                      ({1'b0, y} >= cur_roi_t) && ({1'b0, y} <= cur_roi_b);
    wire cur_left_in_roi = de && (x < half_x) &&
                           ({1'b0, x} >= cur_roi_l) && ({1'b0, x} <= cur_roi_r) &&
                           ({1'b0, y} >= cur_roi_t) && ({1'b0, y} <= cur_roi_b);
    wire red_left_pix  = cur_left_in_roi  && red_pix;
    wire red_right_pix = cur_in_roi       && red_pix;

    function [7:0] absdiff8;
        input [7:0] a;
        input [7:0] b;
        begin
            if (a > b)
                absdiff8 = a - b;
            else
                absdiff8 = b - a;
        end
    endfunction

    function [15:0] gray565;
        input [7:0] l;
        begin
            gray565 = {l[7:3], l[7:2], l[7:3]};
        end
    endfunction

    function [15:0] depth_color;
        input [5:0] d;
        begin
            if (d >= 6'd48)
                depth_color = 16'hF800;       // red: near
            else if (d >= 6'd32)
                depth_color = 16'hFFE0;       // yellow
            else if (d >= 6'd16)
                depth_color = 16'h07E0;       // green
            else
                depth_color = 16'h001F;       // blue: far
        end
    endfunction

    //------------------------------------------------------------------
    // Left row buffer and 66-tap sliding window.
    //------------------------------------------------------------------
    reg [7:0] left_row [0:511];
    reg [7:0] left_win [0:65];
    integer wi;
    integer ri;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (wi = 0; wi < 66; wi = wi + 1)
                left_win[wi] <= 8'd0;
        end
        else if (de) begin
            if (x < half_x) begin
                left_row[x[8:0]] <= lum;

                // Preload the window with three invalid pixels followed by
                // L[0..62]. At xr=3 it contains exactly L[0..65].
                if (x < 11'd66) begin
                    for (wi = 0; wi < 65; wi = wi + 1)
                        left_win[wi] <= left_win[wi+1];
                    if (x >= 11'd3)
                        left_win[65] <= lum;
                    else
                        left_win[65] <= 8'd0;
                end
            end
            else begin
                // Slide the window through the previously captured left row.
                // At xr=0 it shifts in L[63]; by xr=3 the window is L[0..65].
                if (xr <= (half_x - 11'd64)) begin
                    for (wi = 0; wi < 65; wi = wi + 1)
                        left_win[wi] <= left_win[wi+1];
                    left_win[65] <= left_row[xr[8:0] + 6'd63];
                end
            end
        end
    end

    // Right-row 3-pixel history. At valid center xr-2:
    //   r_prev=R[xr-3], r_curr=R[xr-2], r_next=R[xr-1].
    reg [7:0] r_prev, r_curr, r_next;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_prev <= 8'd0;
            r_curr <= 8'd0;
            r_next <= 8'd0;
        end
        else if (de && right_half) begin
            r_next <= lum;
            r_curr <= r_next;
            r_prev <= r_curr;
        end
    end

    // Texture gate: ignore flat 3-pixel windows where SAD is ambiguous.
    wire [7:0] max_r = (r_prev > r_curr) ?
                       ((r_prev > r_next) ? r_prev : r_next) :
                       ((r_curr > r_next) ? r_curr : r_next);
    wire [7:0] min_r = (r_prev < r_curr) ?
                       ((r_prev < r_next) ? r_prev : r_next) :
                       ((r_curr < r_next) ? r_curr : r_next);
    wire       textured = (max_r - min_r) > TEXTURE_THRESH;

    //------------------------------------------------------------------
    // Parallel 3x1 SAD for 64 disparities.
    //------------------------------------------------------------------
    reg [11:0] cost0 [0:63];
    integer ci;
    always @(*) begin
        for (ci = 0; ci < 64; ci = ci + 1) begin
            cost0[ci] = {4'b0, absdiff8(r_prev, left_win[ci])} +
                        {4'b0, absdiff8(r_curr, left_win[ci+1])} +
                        {4'b0, absdiff8(r_next, left_win[ci+2])};
        end
    end

    // Balanced minimum tournament. SAD costs are first registered, then the
    // six-level tree is registered again, giving two pipeline stages.
    reg [11:0] cost0_pipe [0:63];

    reg [11:0] c_l1 [0:31];
    reg [5:0]  i_l1 [0:31];
    reg [11:0] c_l2 [0:15];
    reg [5:0]  i_l2 [0:15];
    reg [11:0] c_l3 [0:7];
    reg [5:0]  i_l3 [0:7];
    reg [11:0] c_l4 [0:3];
    reg [5:0]  i_l4 [0:3];
    reg [11:0] c_l5 [0:1];
    reg [5:0]  i_l5 [0:1];
    reg [11:0] c_l6 [0:0];
    reg [5:0]  i_l6 [0:0];

    integer ti;
    always @(*) begin
        for (ti = 0; ti < 32; ti = ti + 1) begin
            if (cost0_pipe[2*ti] <= cost0_pipe[2*ti+1]) begin
                c_l1[ti] = cost0_pipe[2*ti];
                i_l1[ti] = 2*ti;
            end
            else begin
                c_l1[ti] = cost0_pipe[2*ti+1];
                i_l1[ti] = 2*ti+1;
            end
        end
    end

    always @(*) begin
        for (ti = 0; ti < 16; ti = ti + 1) begin
            if (c_l1[2*ti] <= c_l1[2*ti+1]) begin
                c_l2[ti] = c_l1[2*ti];
                i_l2[ti] = i_l1[2*ti];
            end
            else begin
                c_l2[ti] = c_l1[2*ti+1];
                i_l2[ti] = i_l1[2*ti+1];
            end
        end
    end

    always @(*) begin
        for (ti = 0; ti < 8; ti = ti + 1) begin
            if (c_l2[2*ti] <= c_l2[2*ti+1]) begin
                c_l3[ti] = c_l2[2*ti];
                i_l3[ti] = i_l2[2*ti];
            end
            else begin
                c_l3[ti] = c_l2[2*ti+1];
                i_l3[ti] = i_l2[2*ti+1];
            end
        end
    end

    always @(*) begin
        for (ti = 0; ti < 4; ti = ti + 1) begin
            if (c_l3[2*ti] <= c_l3[2*ti+1]) begin
                c_l4[ti] = c_l3[2*ti];
                i_l4[ti] = i_l3[2*ti];
            end
            else begin
                c_l4[ti] = c_l3[2*ti+1];
                i_l4[ti] = i_l3[2*ti+1];
            end
        end
    end

    always @(*) begin
        for (ti = 0; ti < 2; ti = ti + 1) begin
            if (c_l4[2*ti] <= c_l4[2*ti+1]) begin
                c_l5[ti] = c_l4[2*ti];
                i_l5[ti] = i_l4[2*ti];
            end
            else begin
                c_l5[ti] = c_l4[2*ti+1];
                i_l5[ti] = i_l4[2*ti+1];
            end
        end
    end

    always @(*) begin
        if (c_l5[0] <= c_l5[1]) begin
            c_l6[0] = c_l5[0];
            i_l6[0] = i_l5[0];
        end
        else begin
            c_l6[0] = c_l5[1];
            i_l6[0] = i_l5[1];
        end
    end

    // Two-stage pixel pipeline: first register all 64 SAD costs, then
    // register the minimum-tree result. This keeps the 50 MHz path shallow.
    reg [10:0] x_p0, y_p0;
    reg [15:0] din_p0;
    reg        de_p0;
    reg        valid_p0;
    reg        red_left_p0, red_right_p0;
    integer pi;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (pi = 0; pi < 64; pi = pi + 1)
                cost0_pipe[pi] <= 12'd0;
            x_p0 <= 11'd0;
            y_p0 <= 11'd0;
            din_p0 <= 16'd0;
            de_p0 <= 1'b0;
            valid_p0 <= 1'b0;
            red_left_p0 <= 1'b0;
            red_right_p0 <= 1'b0;
        end
        else if (de) begin
            for (pi = 0; pi < 64; pi = pi + 1)
                cost0_pipe[pi] <= cost0[pi];
            x_p0 <= x;
            y_p0 <= y;
            din_p0 <= din;
            de_p0 <= 1'b1;
            valid_p0 <= stereo_pixel && textured && red_pix && cur_in_roi;
            red_left_p0  <= red_left_pix;
            red_right_p0 <= red_right_pix;
        end
        else begin
            de_p0 <= 1'b0;
            valid_p0 <= 1'b0;
        end
    end

    reg [10:0] x_o, y_o;
    reg [15:0] din_o;
    reg        de_o;
    reg        map_valid_o;
    reg [5:0]  disp_o;
    reg        red_left_o, red_right_o;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_o <= 11'd0;
            y_o <= 11'd0;
            din_o <= 16'd0;
            de_o <= 1'b0;
            map_valid_o <= 1'b0;
            disp_o <= 6'd0;
            red_left_o <= 1'b0;
            red_right_o <= 1'b0;
        end
        else begin
            x_o <= x_p0;
            y_o <= y_p0;
            din_o <= din_p0;
            de_o <= de_p0;
            if (de_p0) begin
                map_valid_o <= valid_p0 && (c_l6[0] < COST_THRESH);
            red_left_o  <= red_left_p0;
            red_right_o <= red_right_p0;
                disp_o <= i_l6[0];
            end
            else begin
                map_valid_o <= 1'b0;
            end
        end
    end
    // Central aiming box shown in green on the right-half disparity image.
    wire [11:0] roi_local_x = {1'b0, x_o} - {1'b0, half_x};
    wire [11:0] roi_center_x = {1'b0, half_x} >> 1;
    wire [11:0] roi_center_y = {1'b0, v_disp} >> 1;
    wire [11:0] roi_left = roi_center_x - ROI_HALF_W;
    wire [11:0] roi_right = roi_center_x + ROI_HALF_W;
    wire [11:0] roi_top = roi_center_y - ROI_HALF_H;
    wire [11:0] roi_bottom = roi_center_y + ROI_HALF_H;

    wire in_roi = de_o && (x_o >= half_x) &&
                  (roi_local_x >= roi_left) &&
                  (roi_local_x <= roi_right) &&
                  ({1'b0, y_o} >= roi_top) &&
                  ({1'b0, y_o} <= roi_bottom);
    wire roi_border = de_o && (x_o >= half_x) &&
                      (roi_local_x >= roi_left) && (roi_local_x <= roi_right) &&
                      ({1'b0, y_o} >= roi_top) && ({1'b0, y_o} <= roi_bottom) &&
                      ((roi_local_x == roi_left) || (roi_local_x == roi_right) ||
                       ({1'b0, y_o} == roi_top) || ({1'b0, y_o} == roi_bottom));
    wire roi_left_border = de_o && (x_o < half_x) &&
                           ({1'b0, x_o} >= roi_left) && ({1'b0, x_o} <= roi_right) &&
                           ({1'b0, y_o} >= roi_top) && ({1'b0, y_o} <= roi_bottom) &&
                           (({1'b0, x_o} == roi_left) || ({1'b0, x_o} == roi_right) ||
                            ({1'b0, y_o} == roi_top) || ({1'b0, y_o} == roi_bottom));
    wire [7:0] lum_o = {din_o[10:5], din_o[9:8]}; // 8-bit green proxy for dim background
    wire [15:0] gray_o = gray565(lum_o);
    wire [15:0] dim_o = {gray_o[15:11] >> 1, gray_o[10:5] >> 1, gray_o[4:0] >> 1};

    always @(*) begin
        if (de_o) begin
            dout = din_o;
            if (roi_border || roi_left_border)
                dout = 16'h07E0;
            if (red_left_o || red_right_o)
                dout = 16'hFFFF;
        end
        else
            dout = din_o;
    end

    //------------------------------------------------------------------
    // Fixed-box red target centroid disparity and distance lock.
    //------------------------------------------------------------------
    reg [10:0] l_minx, l_maxx, r_minx, r_maxx;
    reg [10:0] y_prev;
    reg [15:0] l_count, r_count;
    reg        l_seen, r_seen;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            y_prev <= 11'd0;
        else if (de)
            y_prev <= y;
    end

    wire frame_start = de && (y < y_prev);
    wire frame_end   = de_o && (x_o == (h_disp - 11'd1)) &&
                       (y_o == (v_disp - 11'd1));

    // 64-entry reciprocal/distance ROM, constant-folded during elaboration.
    reg [15:0] dist_rom [0:63];
    genvar dg;
    generate
        for (dg = 0; dg < 64; dg = dg + 1) begin : g_dist_rom
            initial begin
                if (dg == 0)
                    dist_rom[dg] = 16'd0;
                else
                    dist_rom[dg] = DIST_CONST_CM / dg;
            end
        end
    endgenerate

    wire [11:0] l_center = ({1'b0, l_minx} + {1'b0, l_maxx}) >> 1;
    wire [11:0] r_center = ({1'b0, r_minx} + {1'b0, r_maxx}) >> 1;
    wire [11:0] red_diff = (l_center >= r_center) ?
                           (l_center - r_center) : (r_center - l_center);
    wire [5:0]  red_disp = (red_diff == 0) ? 6'd1 :
                           ((red_diff > 63) ? 6'd63 : red_diff[5:0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l_minx <= 11'd0;
            l_maxx <= 11'd0;
            r_minx <= 11'd0;
            r_maxx <= 11'd0;
            l_count <= 16'd0;
            r_count <= 16'd0;
            l_seen <= 1'b0;
            r_seen <= 1'b0;
            distance_cm <= 16'd0;
            distance_valid <= 1'b0;
            disparity_locked <= 6'd0;
        end
        else begin
            if (frame_start) begin
                l_minx <= 11'h7FF;
                l_maxx <= 11'd0;
                r_minx <= 11'h7FF;
                r_maxx <= 11'd0;
                l_count <= 16'd0;
                r_count <= 16'd0;
                l_seen <= 1'b0;
                r_seen <= 1'b0;
                distance_cm <= 16'd0;
                distance_valid <= 1'b0;
                disparity_locked <= 6'd0;
            end

            if (de) begin
                if (red_left_pix) begin
                    l_count <= l_count + 16'd1;
                    if (!l_seen) begin
                        l_minx <= x;
                        l_maxx <= x;
                        l_seen <= 1'b1;
                    end
                    else begin
                        if (x < l_minx) l_minx <= x;
                        if (x > l_maxx) l_maxx <= x;
                    end
                end

                if (red_right_pix) begin
                    r_count <= r_count + 16'd1;
                    if (!r_seen) begin
                        r_minx <= cur_local_x[10:0];
                        r_maxx <= cur_local_x[10:0];
                        r_seen <= 1'b1;
                    end
                    else begin
                        if (cur_local_x[10:0] < r_minx) r_minx <= cur_local_x[10:0];
                        if (cur_local_x[10:0] > r_maxx) r_maxx <= cur_local_x[10:0];
                    end
                end
            end

            if (frame_end) begin
                if (l_seen && r_seen &&
                    (l_count >= MIN_RED_PIX) && (r_count >= MIN_RED_PIX)) begin
                    disparity_locked <= red_disp;
                    distance_cm <= dist_rom[red_disp];
                    distance_valid <= 1'b1;
                end
                else begin
                    disparity_locked <= 6'd0;
                    distance_cm <= 16'd0;
                    distance_valid <= 1'b0;
                end
            end
        end
    end
endmodule































