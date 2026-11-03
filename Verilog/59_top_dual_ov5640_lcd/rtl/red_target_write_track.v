`timescale 1ns/1ps
//------------------------------------------------------------------------------
// red_target_write_track
//   Write-side red target detector. It reuses the same YCrCb + 3x3 morphology
//   as the read-side pipeline, counts lines with cmos_frame_href, and emits
//   per-frame metadata {valid, cx, cy}.
//------------------------------------------------------------------------------
module red_target_write_track #(
    parameter integer MIN_RED_PIX = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        vsync,
    input  wire        href,
    input  wire        de,
    input  wire [15:0] din,
    input  wire [10:0] h_disp,
    input  wire [10:0] v_disp,
    output reg  [10:0] meta_cx,
    output reg  [10:0] meta_cy,
    output reg         meta_valid,
    output reg         meta_we,
    output reg         wr_page
);

    localparam [10:0] SEARCH_INIT_W = 11'd70;
    localparam [10:0] SEARCH_INIT_H = 11'd70;
    localparam [10:0] SEARCH_MIN_W  = 11'd50;
    localparam [10:0] SEARCH_MIN_H  = 11'd50;
    localparam [10:0] SEARCH_MAX_W  = 11'd120;
    localparam [10:0] SEARCH_MAX_H  = 11'd120;
    localparam [10:0] SEARCH_STEP   = 11'd8;

    reg        vsync_d;
    reg        href_d;
    wire       frame_start = vsync & ~vsync_d;
    wire       line_start  = href & ~href_d;
    wire       line_end    = ~href & href_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_d <= 1'b0;
            href_d  <= 1'b0;
        end
        else begin
            vsync_d <= vsync;
            href_d  <= href;
        end
    end

    reg  [10:0] x_cnt;
    reg  [10:0] y_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 11'd0;
            y_cnt <= 11'd0;
        end
        else if (frame_start) begin
            x_cnt <= 11'd0;
            y_cnt <= 11'd0;
        end
        else begin
            if (de)
                x_cnt <= x_cnt + 11'd1;
            if (line_start)
                x_cnt <= 11'd0;
            if (line_end) begin
                x_cnt <= 11'd0;
                y_cnt <= y_cnt + 11'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_page <= 1'b1;
        else if (frame_start)
            wr_page <= ~wr_page;
    end

    wire        morph_mask;
    wire        morph_de;
    wire [10:0] morph_x;
    wire [10:0] morph_y;

    red_ycbcr_morph u_morph (
        .clk           (clk),
        .rst_n         (rst_n),
        .de            (de),
        .x             (x_cnt),
        .y             (y_cnt),
        .h_disp        (h_disp),
        .v_disp        (v_disp),
        .din           (din),
        .red_mask_raw  (),
        .red_mask_open (morph_mask),
        .de_o          (morph_de),
        .x_o           (morph_x),
        .y_o           (morph_y)
    );

    reg [10:0] minx, maxx, miny, maxy;
    reg [15:0] pix_count;
    reg        seen;
    reg [10:0] prev_cx, prev_cy;
    reg [10:0] prev2_cx, prev2_cy;
    reg        have_prev;
    reg        have_vel;
    reg [2:0]  miss_count;
    reg [10:0] search_w, search_h;

    //--------------------------------------------------------------------------
    // (A) One-step velocity prediction.
    //   The search window is centred on where the target WAS, so a moving blob
    //   gets its leading edge clipped.  Because the reported centre is the
    //   bounding-box centre (minx+maxx)/2, that clipping drags the centre
    //   backwards, the window advances less than the target, and the error
    //   feeds itself: the box ends up moving slower than the target until the
    //   blob leaves the window entirely.  Extrapolating the centre by the last
    //   per-frame displacement cancels that trail.
    //--------------------------------------------------------------------------
    localparam signed [12:0] VEL_MAX = 13'sd80;   // px per frame, sanity clamp

    wire signed [12:0] vel_cx_raw = $signed({2'b0, prev_cx}) - $signed({2'b0, prev2_cx});
    wire signed [12:0] vel_cy_raw = $signed({2'b0, prev_cy}) - $signed({2'b0, prev2_cy});
    wire signed [12:0] vel_cx = (vel_cx_raw >  VEL_MAX) ?  VEL_MAX :
                                (vel_cx_raw < -VEL_MAX) ? -VEL_MAX : vel_cx_raw;
    wire signed [12:0] vel_cy = (vel_cy_raw >  VEL_MAX) ?  VEL_MAX :
                                (vel_cy_raw < -VEL_MAX) ? -VEL_MAX : vel_cy_raw;

    wire signed [12:0] pred_cx_raw = $signed({2'b0, prev_cx}) + vel_cx;
    wire signed [12:0] pred_cy_raw = $signed({2'b0, prev_cy}) + vel_cy;

    wire [10:0] pred_cx = (pred_cx_raw < 13'sd0) ? 11'd0 :
                          (pred_cx_raw > $signed({2'b0, h_disp})) ? h_disp : pred_cx_raw[10:0];
    wire [10:0] pred_cy = (pred_cy_raw < 13'sd0) ? 11'd0 :
                          (pred_cy_raw > $signed({2'b0, v_disp})) ? v_disp : pred_cy_raw[10:0];

    // Window centre: extrapolated once we have two detections, else last centre.
    wire [10:0] win_cx = have_vel ? pred_cx : prev_cx;
    wire [10:0] win_cy = have_vel ? pred_cy : prev_cy;

    wire [11:0] x12 = {1'b0, morph_x};
    wire [11:0] y12 = {1'b0, morph_y};
    wire [11:0] px12 = {1'b0, win_cx};
    wire [11:0] py12 = {1'b0, win_cy};
    wire [11:0] sw12 = {1'b0, search_w};
    wire [11:0] sh12 = {1'b0, search_h};
    wire [11:0] h12  = {1'b0, h_disp};
    wire [11:0] v12  = {1'b0, v_disp};

    wire [11:0] search_x0 = (px12 > sw12) ? (px12 - sw12) : 12'd0;
    wire [11:0] search_x1 = px12 + sw12;
    wire [11:0] search_y0 = (py12 > sh12) ? (py12 - sh12) : 12'd0;
    wire [11:0] search_y1 = py12 + sh12;
    wire        central_ok = (x12 >= (h12 >> 3)) &&
                             (x12 <= (h12 - (h12 >> 3))) &&
                             (y12 >= (v12 >> 3)) &&
                             (y12 <= (v12 - (v12 >> 3)));
    wire        in_search = have_prev ?
                            ((x12 >= search_x0) && (x12 <= search_x1) &&
                             (y12 >= search_y0) && (y12 <= search_y1)) :
                            central_ok;
    wire        accept_pixel = morph_de && morph_mask && in_search;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            minx <= 11'h7FF; maxx <= 11'd0;
            miny <= 11'h7FF; maxy <= 11'd0;
            pix_count <= 16'd0;
            seen <= 1'b0;
        end
        else if (frame_start) begin
            minx <= 11'h7FF; maxx <= 11'd0;
            miny <= 11'h7FF; maxy <= 11'd0;
            pix_count <= 16'd0;
            seen <= 1'b0;
        end
        else if (accept_pixel) begin
            pix_count <= pix_count + 16'd1;
            if (!seen) begin
                minx <= morph_x; maxx <= morph_x;
                miny <= morph_y; maxy <= morph_y;
                seen <= 1'b1;
            end
            else begin
                if (morph_x < minx) minx <= morph_x;
                if (morph_x > maxx) maxx <= morph_x;
                if (morph_y < miny) miny <= morph_y;
                if (morph_y > maxy) maxy <= morph_y;
            end
        end
    end

    wire [11:0] det_cx = ({1'b0, minx} + {1'b0, maxx}) >> 1;
    wire [11:0] det_cy = ({1'b0, miny} + {1'b0, maxy}) >> 1;
    wire        frame_last = morph_de &&
                             (morph_x == (h_disp - 11'd1)) &&
                             (morph_y == (v_disp - 11'd1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta_cx <= 11'd0;
            meta_cy <= 11'd0;
            meta_valid <= 1'b0;
            meta_we <= 1'b0;
            prev_cx <= 11'd0;
            prev_cy <= 11'd0;
            prev2_cx <= 11'd0;
            prev2_cy <= 11'd0;
            have_prev <= 1'b0;
            have_vel <= 1'b0;
            miss_count <= 3'd0;
            search_w <= SEARCH_INIT_W;
            search_h <= SEARCH_INIT_H;
        end
        else begin
            meta_we <= frame_last;

            if (frame_last) begin
                if (seen && (pix_count >= MIN_RED_PIX)) begin
                    //---- hit: publish the measured centre, tighten the window
                    meta_cx <= det_cx[10:0];
                    meta_cy <= det_cy[10:0];
                    meta_valid <= 1'b1;
                    prev2_cx <= prev_cx;
                    prev2_cy <= prev_cy;
                    prev_cx <= det_cx[10:0];
                    prev_cy <= det_cy[10:0];
                    have_prev <= 1'b1;
                    have_vel <= have_prev;
                    miss_count <= 3'd0;
                    if (search_w > SEARCH_MIN_W) search_w <= search_w - SEARCH_STEP;
                    if (search_h > SEARCH_MIN_H) search_h <= search_h - SEARCH_STEP;
                end
                else if (have_prev && (miss_count == 3'd0)) begin
                    //---- (D) first miss: coast one frame on the prediction and
                    //     open the window to its maximum immediately, so losing
                    //     the target costs one frame instead of three.
                    meta_cx <= win_cx;
                    meta_cy <= win_cy;
                    meta_valid <= 1'b1;
                    prev2_cx <= prev_cx;
                    prev2_cy <= prev_cy;
                    prev_cx <= win_cx;
                    prev_cy <= win_cy;
                    miss_count <= 3'd1;
                    search_w <= SEARCH_MAX_W;
                    search_h <= SEARCH_MAX_H;
                end
                else begin
                    //---- really lost: stop reporting, search the whole frame
                    meta_cx <= 11'd0;
                    meta_cy <= 11'd0;
                    meta_valid <= 1'b0;
                    have_prev <= 1'b0;
                    have_vel <= 1'b0;
                    miss_count <= 3'd0;
                    search_w <= SEARCH_MAX_W;
                    search_h <= SEARCH_MAX_H;
                end
            end
        end
    end

endmodule


module meta_dual_ram #(
    parameter integer WIDTH = 23
)(
    input  wire             wr_clk,
    input  wire             wr_en,
    input  wire [0:0]       wr_addr,
    input  wire [WIDTH-1:0] wr_data,
    input  wire             rd_clk,
    input  wire [0:0]       rd_addr,
    output reg  [WIDTH-1:0] rd_data
);

    reg [WIDTH-1:0] mem [0:1];
    integer i;

    initial begin
        for (i = 0; i < 2; i = i + 1)
            mem[i] = {WIDTH{1'b0}};
    end

    always @(posedge wr_clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    always @(posedge rd_clk) begin
        rd_data <= mem[rd_addr];
    end

endmodule