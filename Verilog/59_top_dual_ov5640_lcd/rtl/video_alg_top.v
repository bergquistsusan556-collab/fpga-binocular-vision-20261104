`timescale 1ns/1ps
// Real-time video processing for the dual OV5640 LCD pipeline.
// Modes are selected by KEY0 and shown on LED[2:0].
//   0 RAW        原始图像
//   1 BINARY     二值化 (grayscale dual threshold, adjustable)
//   2 ERODE      腐蚀
//   3 OPEN       开运算
//   4 EMBOSS     浮雕效果
//   5 LAPLACIAN  拉普拉斯锐化
//   6 SOBEL      Sobel 边缘
//   7 DEPTH      双目测距
// The green follow box is an OVERLAY toggled by KEY3 (LED[3]), not a mode:
// it tracks the RED target and is drawn on top of the colour picture.
module video_alg_top(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        de,
    input  wire [10:0] x,
    input  wire [10:0] y,
    input  wire [10:0] h_disp,
    input  wire [10:0] v_disp,
    input  wire [2:0]  mode,
    input  wire [8:0]  cal_scale,
    input  wire        filter_enable,
    input  wire        follow_enable,
    input  wire [7:0]  thr_low,
    input  wire [7:0]  thr_high,
    input  wire [6:0]  cam_pos,
    input  wire [6:0]  lcd_pos,
    input  wire        ext_l_valid,
    input  wire [10:0] ext_l_cx,
    input  wire [10:0] ext_l_cy,
    input  wire        ext_r_valid,
    input  wire [10:0] ext_r_cx,
    input  wire [10:0] ext_r_cy,
    input  wire [15:0] din,
    output reg  [15:0] dout
);

    localparam MODE_RAW        = 3'd0;
    localparam MODE_BINARY     = 3'd1;
    localparam MODE_ERODE      = 3'd2;
    localparam MODE_OPEN       = 3'd3;
    localparam MODE_EMBOSS     = 3'd4;
    localparam MODE_LAPLACIAN  = 3'd5;
    localparam MODE_SOBEL      = 3'd6;
    localparam MODE_DEPTH      = 3'd7;

    // Follow box uses a fixed 40x40 size.
    localparam [10:0] FOLLOW_HALF_W = 11'd20;
    localparam [10:0] FOLLOW_HALF_H = 11'd20;
    localparam [10:0] SEARCH_INIT_W = 11'd70;
    localparam [10:0] SEARCH_INIT_H = 11'd70;
    localparam [10:0] SEARCH_MIN_W  = 11'd50;
    localparam [10:0] SEARCH_MIN_H  = 11'd50;
    localparam [10:0] SEARCH_MAX_W  = 11'd120;
    localparam [10:0] SEARCH_MAX_H  = 11'd120;
    localparam [10:0] SEARCH_STEP   = 11'd8;

    wire [4:0] r5 = din[15:11];
    wire [5:0] g6 = din[10:5];
    wire [4:0] b5 = din[4:0];
    wire [7:0] r8 = {r5, r5[4:2]};
    wire [7:0] g8 = {g6, g6[5:4]};
    wire [7:0] b8 = {b5, b5[4:2]};

    wire [10:0] half_x = {1'b0, h_disp[10:1]};

    // Dual-threshold binarisation + 3x3 morphology + emboss / Laplacian / Sobel.
    // This replaces the old 1-D edge and frame-difference experiments.
    wire [15:0] bin565, erode565, open565, emboss565, lap565, sobel565;

    img_filter_pack u_img_filter_pack (
        .clk       (clk),
        .rst_n     (rst_n),
        .de        (de),
        .x         (x),
        .thr_low   (thr_low),
        .thr_high  (thr_high),
        .din       (din),
        .bin565    (bin565),
        .erode565  (erode565),
        .open565   (open565),
        .emboss565 (emboss565),
        .lap565    (lap565),
        .sobel565  (sobel565)
    );

    // RGB565 -> YCrCb red mask -> 3x3 dilation -> 3x3 erosion.
    wire        red_mask_raw;
    wire        red_mask_open;
    wire        red_mask_dilate;
    wire        morph_de;
    wire [10:0] morph_x, morph_y;

    red_ycbcr_morph u_red_ycbcr_morph (
        .clk           (clk),
        .rst_n         (rst_n),
        .de            (de),
        .x             (x),
        .y             (y),
        .h_disp        (h_disp),
        .v_disp        (v_disp),
        .din           (din),
        .red_mask_raw    (red_mask_raw),
        .red_mask_dilate (red_mask_dilate),
        .red_mask_open   (red_mask_open),
        .de_o          (morph_de),
        .x_o           (morph_x),
        .y_o           (morph_y)
    );


    // Red-target detector.  Runs in the display pixel clock and accumulates a
    // bounding box over the displayed frame; the write-side tracker feeds it a
    // per-frame centre through the metadata RAM whenever that path is valid.
    wire red_pix = red_mask_open;
    wire [10:0] xr = x - half_x;
    wire [10:0] xr_m = morph_x - half_x;
    reg [10:0] l_minx, l_maxx, l_miny, l_maxy;
    reg [10:0] r_minx, r_maxx, r_miny, r_maxy;
    reg        l_seen, r_seen;
    reg [15:0] l_track_count, r_track_count;
    reg [10:0] l_box_x0, l_box_x1, l_box_y0, l_box_y1;
    reg [10:0] r_box_x0, r_box_x1, r_box_y0, r_box_y1;
    reg        l_box_valid, r_box_valid;
    reg [2:0]  l_miss, r_miss;
    reg [10:0] l_search_w, l_search_h, r_search_w, r_search_h;
    reg [10:0] y_prev_ext;
    reg        ext_l_valid_frame;
    reg        ext_r_valid_frame;

    // MARK_DEBUG keeps these alive so the VIO can read them over JTAG; the
    // attribute does not change any logic.
    (* MARK_DEBUG = "TRUE" *) wire [11:0] l_cur_cx = ({1'b0, l_box_x0} + {1'b0, l_box_x1}) >> 1;
    (* MARK_DEBUG = "TRUE" *) wire [11:0] l_cur_cy = ({1'b0, l_box_y0} + {1'b0, l_box_y1}) >> 1;
    wire [11:0] r_cur_cx = ({1'b0, r_box_x0} + {1'b0, r_box_x1}) >> 1;
    wire [11:0] r_cur_cy = ({1'b0, r_box_y0} + {1'b0, r_box_y1}) >> 1;

    wire [10:0] l_search_x0 = (l_cur_cx > l_search_w) ? (l_cur_cx[10:0] - l_search_w) : 11'd0;
    wire [10:0] l_search_x1 = ((l_cur_cx[10:0] + l_search_w) < half_x) ? (l_cur_cx[10:0] + l_search_w) : (half_x - 11'd1);
    wire [10:0] l_search_y0 = (l_cur_cy > l_search_h) ? (l_cur_cy[10:0] - l_search_h) : 11'd0;
    wire [10:0] l_search_y1 = ((l_cur_cy[10:0] + l_search_h) < v_disp) ? (l_cur_cy[10:0] + l_search_h) : (v_disp - 11'd1);
    wire [10:0] r_search_x0 = (r_cur_cx > r_search_w) ? (r_cur_cx[10:0] - r_search_w) : 11'd0;
    wire [10:0] r_search_x1 = ((r_cur_cx[10:0] + r_search_w) < half_x) ? (r_cur_cx[10:0] + r_search_w) : (half_x - 11'd1);
    wire [10:0] r_search_y0 = (r_cur_cy > r_search_h) ? (r_cur_cy[10:0] - r_search_h) : 11'd0;
    wire [10:0] r_search_y1 = ((r_cur_cy[10:0] + r_search_h) < v_disp) ? (r_cur_cy[10:0] + r_search_h) : (v_disp - 11'd1);
    wire l_acq_region = (morph_x >= (half_x >> 3)) && (morph_x <= (half_x - (half_x >> 3))) && (morph_y >= (v_disp >> 3)) && (morph_y <= (v_disp - (v_disp >> 3)));
    wire r_acq_region = (xr_m >= (half_x >> 3)) && (xr_m <= (half_x - (half_x >> 3))) && (morph_y >= (v_disp >> 3)) && (morph_y <= (v_disp - (v_disp >> 3)));
    wire l_in_search = l_box_valid ? ((morph_x >= l_search_x0) && (morph_x <= l_search_x1) && (morph_y >= l_search_y0) && (morph_y <= l_search_y1)) : l_acq_region;
    wire r_in_search = r_box_valid ? ((xr_m >= r_search_x0) && (xr_m <= r_search_x1) && (morph_y >= r_search_y0) && (morph_y <= r_search_y1)) : r_acq_region;

    wire [11:0] l_det_cx = ({1'b0, l_minx} + {1'b0, l_maxx}) >> 1;
    wire [11:0] l_det_cy = ({1'b0, l_miny} + {1'b0, l_maxy}) >> 1;
    wire [11:0] r_det_cx = ({1'b0, r_minx} + {1'b0, r_maxx}) >> 1;
    wire [11:0] r_det_cy = ({1'b0, r_miny} + {1'b0, r_maxy}) >> 1;
    // Follow-box centers are always direct; KEY3 filters distance only.
    wire [12:0] l_smooth_cx = {1'b0, l_det_cx};
    wire [12:0] l_smooth_cy = {1'b0, l_det_cy};
    wire [12:0] r_smooth_cx = {1'b0, r_det_cx};
    wire [12:0] r_smooth_cy = {1'b0, r_det_cy};
    wire        l_det_valid = l_seen && (l_track_count >= 16'd4);
    wire        r_det_valid = r_seen && (r_track_count >= 16'd4);

    wire [10:0] l_upd_fx0 = (l_smooth_cx > FOLLOW_HALF_W) ? (l_smooth_cx[10:0] - FOLLOW_HALF_W) : 11'd0;
    wire [10:0] l_upd_fx1 = ((l_smooth_cx[10:0] + FOLLOW_HALF_W) < half_x) ? (l_smooth_cx[10:0] + FOLLOW_HALF_W) : (half_x - 11'd1);
    wire [10:0] l_upd_fy0 = (l_smooth_cy > FOLLOW_HALF_H) ? (l_smooth_cy[10:0] - FOLLOW_HALF_H) : 11'd0;
    wire [10:0] l_upd_fy1 = ((l_smooth_cy[10:0] + FOLLOW_HALF_H) < v_disp) ? (l_smooth_cy[10:0] + FOLLOW_HALF_H) : (v_disp - 11'd1);

    wire [10:0] r_upd_fx0 = (r_smooth_cx > FOLLOW_HALF_W) ? (r_smooth_cx[10:0] - FOLLOW_HALF_W) : 11'd0;
    wire [10:0] r_upd_fx1 = ((r_smooth_cx[10:0] + FOLLOW_HALF_W) < half_x) ? (r_smooth_cx[10:0] + FOLLOW_HALF_W) : (half_x - 11'd1);
    wire [10:0] r_upd_fy0 = (r_smooth_cy > FOLLOW_HALF_H) ? (r_smooth_cy[10:0] - FOLLOW_HALF_H) : 11'd0;
    wire [10:0] r_upd_fy1 = ((r_smooth_cy[10:0] + FOLLOW_HALF_H) < v_disp) ? (r_smooth_cy[10:0] + FOLLOW_HALF_H) : (v_disp - 11'd1);

    wire [10:0] ext_l_upd_fx0 = (ext_l_cx > FOLLOW_HALF_W) ? (ext_l_cx - FOLLOW_HALF_W) : 11'd0;
    wire [10:0] ext_l_upd_fx1 = ((ext_l_cx + FOLLOW_HALF_W) < half_x) ? (ext_l_cx + FOLLOW_HALF_W) : (half_x - 11'd1);
    wire [10:0] ext_l_upd_fy0 = (ext_l_cy > FOLLOW_HALF_H) ? (ext_l_cy - FOLLOW_HALF_H) : 11'd0;
    wire [10:0] ext_l_upd_fy1 = ((ext_l_cy + FOLLOW_HALF_H) < v_disp) ? (ext_l_cy + FOLLOW_HALF_H) : (v_disp - 11'd1);

    wire [10:0] ext_r_upd_fx0 = (ext_r_cx > FOLLOW_HALF_W) ? (ext_r_cx - FOLLOW_HALF_W) : 11'd0;
    wire [10:0] ext_r_upd_fx1 = ((ext_r_cx + FOLLOW_HALF_W) < half_x) ? (ext_r_cx + FOLLOW_HALF_W) : (half_x - 11'd1);
    wire [10:0] ext_r_upd_fy0 = (ext_r_cy > FOLLOW_HALF_H) ? (ext_r_cy - FOLLOW_HALF_H) : 11'd0;
    wire [10:0] ext_r_upd_fy1 = ((ext_r_cy + FOLLOW_HALF_H) < v_disp) ? (ext_r_cy + FOLLOW_HALF_H) : (v_disp - 11'd1);

    wire        frame_start_ext = de && (y < y_prev_ext);
    // (E) The two halves are gated independently below.  The old code disabled
    //     the read-side fallback with "ext_l_valid || ext_r_valid", so a lock on
    //     ONE half switched the fallback detector off for BOTH halves and left
    //     the other one to freeze.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            y_prev_ext <= 11'd0;
        else if (de)
            y_prev_ext <= y;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l_minx <= 11'd0; l_maxx <= 11'd0; l_miny <= 11'd0; l_maxy <= 11'd0;
            r_minx <= 11'd0; r_maxx <= 11'd0; r_miny <= 11'd0; r_maxy <= 11'd0;
            l_seen <= 1'b0; r_seen <= 1'b0;
            l_track_count <= 16'd0; r_track_count <= 16'd0;
            l_box_x0 <= 11'd0; l_box_x1 <= 11'd0; l_box_y0 <= 11'd0; l_box_y1 <= 11'd0;
            r_box_x0 <= 11'd0; r_box_x1 <= 11'd0; r_box_y0 <= 11'd0; r_box_y1 <= 11'd0;
            l_box_valid <= 1'b0; r_box_valid <= 1'b0;
            l_miss <= 3'd0; r_miss <= 3'd0;
            l_search_w <= SEARCH_INIT_W; l_search_h <= SEARCH_INIT_H;
            r_search_w <= SEARCH_INIT_W; r_search_h <= SEARCH_INIT_H;
            ext_l_valid_frame <= 1'b0; ext_r_valid_frame <= 1'b0;
        end
        else if (frame_start_ext) begin
            ext_l_valid_frame <= ext_l_valid;
            ext_r_valid_frame <= ext_r_valid;

            if (ext_l_valid) begin
                l_box_x0 <= ext_l_upd_fx0; l_box_x1 <= ext_l_upd_fx1;
                l_box_y0 <= ext_l_upd_fy0; l_box_y1 <= ext_l_upd_fy1;
                l_box_valid <= 1'b1;
                l_miss <= 3'd0;
            end
            else if (l_box_valid && (l_miss < 3'd1)) begin
                l_miss <= l_miss + 3'd1;
            end
            else begin
                l_box_valid <= 1'b0;
                l_miss <= 3'd0;
            end

            if (ext_r_valid) begin
                r_box_x0 <= ext_r_upd_fx0; r_box_x1 <= ext_r_upd_fx1;
                r_box_y0 <= ext_r_upd_fy0; r_box_y1 <= ext_r_upd_fy1;
                r_box_valid <= 1'b1;
                r_miss <= 3'd0;
            end
            else if (r_box_valid && (r_miss < 3'd1)) begin
                r_miss <= r_miss + 3'd1;
            end
            else begin
                r_box_valid <= 1'b0;
                r_miss <= 3'd0;
            end

            l_seen <= 1'b0; r_seen <= 1'b0;
            l_track_count <= 16'd0; r_track_count <= 16'd0;
            l_minx <= 11'd0; l_maxx <= 11'd0; l_miny <= 11'd0; l_maxy <= 11'd0;
            r_minx <= 11'd0; r_maxx <= 11'd0; r_miny <= 11'd0; r_maxy <= 11'd0;
            l_search_w <= SEARCH_INIT_W; l_search_h <= SEARCH_INIT_H;
            r_search_w <= SEARCH_INIT_W; r_search_h <= SEARCH_INIT_H;
        end
        else if (morph_de && (!ext_l_valid_frame || !ext_r_valid_frame)) begin
            // Each half accumulates only while its OWN write-side result is absent.
            if (!ext_l_valid_frame && red_pix && (morph_x < half_x) && l_in_search) begin
                l_track_count <= l_track_count + 16'd1;
                if (!l_seen) begin
                    l_minx <= morph_x; l_maxx <= morph_x; l_miny <= morph_y; l_maxy <= morph_y;
                end
                else begin
                    if (morph_x < l_minx) l_minx <= morph_x;
                    if (morph_x > l_maxx) l_maxx <= morph_x;
                    if (morph_y < l_miny) l_miny <= morph_y;
                    if (morph_y > l_maxy) l_maxy <= morph_y;
                end
                l_seen <= 1'b1;
            end

            if (!ext_r_valid_frame && red_pix && (morph_x >= half_x) && r_in_search) begin
                r_track_count <= r_track_count + 16'd1;
                if (!r_seen) begin
                    r_minx <= xr_m; r_maxx <= xr_m;
                    r_miny <= morph_y; r_maxy <= morph_y;
                end
                else begin
                    if (xr_m < r_minx) r_minx <= xr_m;
                    if (xr_m > r_maxx) r_maxx <= xr_m;
                    if (morph_y < r_miny) r_miny <= morph_y;
                    if (morph_y > r_maxy) r_maxy <= morph_y;
                end
                r_seen <= 1'b1;
            end

            if ((morph_x == (h_disp - 11'd1)) && (morph_y == (v_disp - 11'd1))) begin
                if (!ext_l_valid_frame) begin
                    if (l_det_valid) begin
                        l_box_x0 <= l_upd_fx0; l_box_x1 <= l_upd_fx1;
                        l_box_y0 <= l_upd_fy0; l_box_y1 <= l_upd_fy1;
                        l_box_valid <= 1'b1;
                        l_miss <= 3'd0;
                        if (l_search_w > SEARCH_MIN_W) l_search_w <= l_search_w - SEARCH_STEP;
                        if (l_search_h > SEARCH_MIN_H) l_search_h <= l_search_h - SEARCH_STEP;
                    end
                    else if (l_box_valid && (l_miss < 3'd1)) begin
                        l_miss <= l_miss + 3'd1;
                        if (l_search_w < SEARCH_MAX_W) l_search_w <= l_search_w + SEARCH_STEP;
                        if (l_search_h < SEARCH_MAX_H) l_search_h <= l_search_h + SEARCH_STEP;
                    end
                    else begin
                        l_box_valid <= 1'b0;
                        l_search_w <= SEARCH_MAX_W; l_search_h <= SEARCH_MAX_H;
                        l_miss <= 3'd0;
                    end
                end

                if (!ext_r_valid_frame) begin
                    if (r_det_valid) begin
                        r_box_x0 <= r_upd_fx0; r_box_x1 <= r_upd_fx1;
                        r_box_y0 <= r_upd_fy0; r_box_y1 <= r_upd_fy1;
                        r_box_valid <= 1'b1;
                        r_miss <= 3'd0;
                        if (r_search_w > SEARCH_MIN_W) r_search_w <= r_search_w - SEARCH_STEP;
                        if (r_search_h > SEARCH_MIN_H) r_search_h <= r_search_h - SEARCH_STEP;
                    end
                    else if (r_box_valid && (r_miss < 3'd1)) begin
                        r_miss <= r_miss + 3'd1;
                        if (r_search_w < SEARCH_MAX_W) r_search_w <= r_search_w + SEARCH_STEP;
                        if (r_search_h < SEARCH_MAX_H) r_search_h <= r_search_h + SEARCH_STEP;
                    end
                    else begin
                        r_box_valid <= 1'b0;
                        r_search_w <= SEARCH_MAX_W; r_search_h <= SEARCH_MAX_H;
                        r_miss <= 3'd0;
                    end
                end

                l_seen <= 1'b0; r_seen <= 1'b0;
                l_track_count <= 16'd0; r_track_count <= 16'd0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // LATENCY PROBE
    //   An independent red detection run on the frame that is CURRENTLY ON
    //   SCREEN.  It uses the fixed central acquisition region, so it is NOT
    //   dragged along by the tracking box's search window, and it is NOT fed by
    //   the write-side metadata pipeline.
    //
    //   It is drawn as a RED box next to the GREEN tracking box.  The pixel
    //   distance between the two boxes IS the tracking latency, directly
    //   readable on the panel - no phone video and no guessing required.
    //   Toggle with KEY3 (same switch as the follow box).
    //--------------------------------------------------------------------------
    reg [10:0] l_rd_minx, l_rd_maxx, l_rd_miny, l_rd_maxy;
    reg [10:0] r_rd_minx, r_rd_maxx, r_rd_miny, r_rd_maxy;
    reg [15:0] l_rd_count, r_rd_count;
    reg        l_rd_seen, r_rd_seen;
    (* MARK_DEBUG = "TRUE" *) reg [10:0] l_rd_cx, l_rd_cy, r_rd_cx, r_rd_cy;
    reg        l_rd_ok, r_rd_ok;

    wire frame_end_rd = morph_de && (morph_x == (h_disp - 11'd1)) &&
                        (morph_y == (v_disp - 11'd1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l_rd_minx <= 11'h7FF; l_rd_maxx <= 11'd0; l_rd_miny <= 11'h7FF; l_rd_maxy <= 11'd0;
            r_rd_minx <= 11'h7FF; r_rd_maxx <= 11'd0; r_rd_miny <= 11'h7FF; r_rd_maxy <= 11'd0;
            l_rd_count <= 16'd0; r_rd_count <= 16'd0;
            l_rd_seen <= 1'b0; r_rd_seen <= 1'b0;
            l_rd_cx <= 11'd0; l_rd_cy <= 11'd0; r_rd_cx <= 11'd0; r_rd_cy <= 11'd0;
            l_rd_ok <= 1'b0; r_rd_ok <= 1'b0;
        end
        else if (morph_de) begin
            if (red_pix && (morph_x < half_x) && l_acq_region) begin
                l_rd_count <= l_rd_count + 16'd1;
                if (!l_rd_seen) begin
                    l_rd_minx <= morph_x; l_rd_maxx <= morph_x;
                    l_rd_miny <= morph_y; l_rd_maxy <= morph_y;
                    l_rd_seen <= 1'b1;
                end
                else begin
                    if (morph_x < l_rd_minx) l_rd_minx <= morph_x;
                    if (morph_x > l_rd_maxx) l_rd_maxx <= morph_x;
                    if (morph_y < l_rd_miny) l_rd_miny <= morph_y;
                    if (morph_y > l_rd_maxy) l_rd_maxy <= morph_y;
                end
            end

            if (red_pix && (morph_x >= half_x) && r_acq_region) begin
                r_rd_count <= r_rd_count + 16'd1;
                if (!r_rd_seen) begin
                    r_rd_minx <= xr_m; r_rd_maxx <= xr_m;
                    r_rd_miny <= morph_y; r_rd_maxy <= morph_y;
                    r_rd_seen <= 1'b1;
                end
                else begin
                    if (xr_m < r_rd_minx) r_rd_minx <= xr_m;
                    if (xr_m > r_rd_maxx) r_rd_maxx <= xr_m;
                    if (morph_y < r_rd_miny) r_rd_miny <= morph_y;
                    if (morph_y > r_rd_maxy) r_rd_maxy <= morph_y;
                end
            end

            if (frame_end_rd) begin
                l_rd_cx <= ({1'b0, l_rd_minx} + {1'b0, l_rd_maxx}) >> 1;
                l_rd_cy <= ({1'b0, l_rd_miny} + {1'b0, l_rd_maxy}) >> 1;
                r_rd_cx <= ({1'b0, r_rd_minx} + {1'b0, r_rd_maxx}) >> 1;
                r_rd_cy <= ({1'b0, r_rd_miny} + {1'b0, r_rd_maxy}) >> 1;
                l_rd_ok <= l_rd_seen && (l_rd_count >= 16'd8);
                r_rd_ok <= r_rd_seen && (r_rd_count >= 16'd8);
                l_rd_minx <= 11'h7FF; l_rd_maxx <= 11'd0; l_rd_miny <= 11'h7FF; l_rd_maxy <= 11'd0;
                r_rd_minx <= 11'h7FF; r_rd_maxx <= 11'd0; r_rd_miny <= 11'h7FF; r_rd_maxy <= 11'd0;
                l_rd_count <= 16'd0; r_rd_count <= 16'd0;
                l_rd_seen <= 1'b0; r_rd_seen <= 1'b0;
            end
        end
    end

    wire [10:0] l_rd_x0 = (l_rd_cx > FOLLOW_HALF_W) ? (l_rd_cx - FOLLOW_HALF_W) : 11'd0;
    wire [10:0] l_rd_x1 = ((l_rd_cx + FOLLOW_HALF_W) < half_x) ? (l_rd_cx + FOLLOW_HALF_W) : (half_x - 11'd1);
    wire [10:0] l_rd_y0 = (l_rd_cy > FOLLOW_HALF_H) ? (l_rd_cy - FOLLOW_HALF_H) : 11'd0;
    wire [10:0] l_rd_y1 = ((l_rd_cy + FOLLOW_HALF_H) < v_disp) ? (l_rd_cy + FOLLOW_HALF_H) : (v_disp - 11'd1);
    wire [10:0] r_rd_x0 = (r_rd_cx > FOLLOW_HALF_W) ? (r_rd_cx - FOLLOW_HALF_W) : 11'd0;
    wire [10:0] r_rd_x1 = ((r_rd_cx + FOLLOW_HALF_W) < half_x) ? (r_rd_cx + FOLLOW_HALF_W) : (half_x - 11'd1);
    wire [10:0] r_rd_y0 = (r_rd_cy > FOLLOW_HALF_H) ? (r_rd_cy - FOLLOW_HALF_H) : 11'd0;
    wire [10:0] r_rd_y1 = ((r_rd_cy + FOLLOW_HALF_H) < v_disp) ? (r_rd_cy + FOLLOW_HALF_H) : (v_disp - 11'd1);

    wire in_l_rd = l_rd_ok && (x < half_x) &&
                   (x >= l_rd_x0) && (x <= l_rd_x1) &&
                   (y >= l_rd_y0) && (y <= l_rd_y1);
    wire in_r_rd = r_rd_ok && (x >= half_x) &&
                   (xr >= r_rd_x0) && (xr <= r_rd_x1) &&
                   (y >= r_rd_y0) && (y <= r_rd_y1);
    wire border_l_rd = in_l_rd && ((x == l_rd_x0) || (x == l_rd_x1) ||
                                   (y == l_rd_y0) || (y == l_rd_y1));
    wire border_r_rd = in_r_rd && ((xr == r_rd_x0) || (xr == r_rd_x1) ||
                                   (y == r_rd_y0) || (y == r_rd_y1));

    wire in_l = l_box_valid && (x < half_x) &&
                (x >= l_box_x0) && (x <= l_box_x1) &&
                (y >= l_box_y0) && (y <= l_box_y1);
    wire in_r = r_box_valid && (x >= half_x) &&
                (xr >= r_box_x0) && (xr <= r_box_x1) &&
                (y >= r_box_y0) && (y <= r_box_y1);
    wire border_l = in_l && ((x == l_box_x0) || (x == l_box_x1) ||
                             (y == l_box_y0) || (y == l_box_y1));
    wire border_r = in_r && ((xr == r_box_x0) || (xr == r_box_x1) ||
                             (y == r_box_y0) || (y == r_box_y1));
    wire [15:0] target565 = (border_l || border_r) ? 16'h07E0 : din;


    // Stereo depth mode: right half is a live disparity map, left half is raw.
    wire [15:0] stereo_rgb;
    (* MARK_DEBUG = "TRUE" *) wire [15:0] stereo_distance_cm;
    wire        stereo_distance_valid;
    wire [5:0]  stereo_disp;
    wire [15:0] distance_osd_rgb;
    wire        distance_osd_active;
    reg  [10:0] osd_x1, osd_y1;
    reg  [10:0] osd_x, osd_y;

    stereo_red_ruler #(
        .FOCAL_PX    (346),
        .BASELINE_MM (60)
    ) u_stereo_red_ruler (
        .clk              (clk),
        .rst_n            (rst_n),
        .de               (de),
        .x                (x),
        .y                (y),
        .h_disp           (h_disp),
        .v_disp           (v_disp),
        .mask_de          (morph_de),
        .mask_x           (morph_x),
        .mask_y           (morph_y),
        .cal_scale        (cal_scale),
        .red_mask         (red_mask_open),
        .filter_enable    (filter_enable),
        .l_roi_cx         (l_cur_cx[10:0]),
        .l_roi_cy         (l_cur_cy[10:0]),
        .r_roi_cx         (r_cur_cx[10:0]),
        .r_roi_cy         (r_cur_cy[10:0]),
        .l_roi_valid      (l_box_valid),
        .r_roi_valid      (r_box_valid),
        .din              (din),
        .dout             (stereo_rgb),
        .distance_cm      (stereo_distance_cm),
        .distance_valid   (stereo_distance_valid),
        .disparity_locked (stereo_disp)
    );

    // These registers delay OSD coordinates by the two-pixel stereo map latency.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            osd_x1 <= 11'd0;
            osd_y1 <= 11'd0;
            osd_x <= 11'd0;
            osd_y <= 11'd0;
        end
        else if (de) begin
            osd_x1 <= x;
            osd_y1 <= y;
            osd_x <= osd_x1;
            osd_y <= osd_y1;
        end
    end

    distance_osd u_distance_osd (
        .clk            (clk),
        .rst_n          (rst_n),
        .x              (osd_x),
        .y              (osd_y),
        .h_disp         (h_disp),
        .distance_cm    (stereo_distance_cm),
        .distance_valid (stereo_distance_valid),
        .osd_active     (distance_osd_active),
        .osd_rgb        (distance_osd_rgb)
    );
    reg [15:0] mode_color;
    always @(*) begin
        case (mode)
            MODE_RAW:       mode_color = 16'hFFFF;  // white
            MODE_BINARY:    mode_color = 16'h8410;  // grey
            MODE_ERODE:     mode_color = 16'hF800;  // red
            MODE_OPEN:      mode_color = 16'h07E0;  // green
            MODE_EMBOSS:    mode_color = 16'hFFE0;  // yellow
            MODE_LAPLACIAN: mode_color = 16'hF81F;  // magenta
            MODE_SOBEL:     mode_color = 16'h07FF;  // cyan
            MODE_DEPTH:     mode_color = 16'hFFE0;  // yellow
            default:        mode_color = 16'hFFFF;
        endcase
    end

    // The follow box is an OVERLAY, not a mode: it tracks the RED target and is
    // drawn on top of the two colour modes, mirroring the reference design's
    // "edge detect overlay" switch.
    wire [15:0] base565 =
                (mode == MODE_BINARY)    ? bin565    :
                (mode == MODE_ERODE)     ? erode565  :
                (mode == MODE_OPEN)      ? open565   :
                (mode == MODE_EMBOSS)    ? emboss565 :
                (mode == MODE_LAPLACIAN) ? lap565    :
                (mode == MODE_SOBEL)     ? sobel565  :
                (mode == MODE_DEPTH)     ? (distance_osd_active ? distance_osd_rgb : stereo_rgb) :
                                           din;

    // Mode 7 draws its own 90x90 measurement box inside stereo_red_ruler, so the
    // KEY3 overlay is limited to the clean colour image - otherwise two
    // differently sized boxes would be on screen at once.
    wire colour_mode = (mode == MODE_RAW);
    wire box_on      = follow_enable && colour_mode && (border_l || border_r);

    // Latency probe (RED box) next to the tracking box (GREEN box).  The pixel
    // distance between the two is the tracking latency.
    wire diag_mode = (mode == MODE_RAW) || (mode == MODE_DEPTH);
    wire diag_on   = follow_enable && diag_mode && (border_l_rd || border_r_rd);

    // Frame-rate meter: two bars along the bottom, 4 px per frame of their own
    // source.  CYAN = camera frames, MAGENTA = LCD frames.  Compare their speeds
    // on a phone video to get fps_cam = 83.2 Hz * (cyan speed / magenta speed).
    wire [10:0] cam_bar_x = {cam_pos, 2'b00};
    wire [10:0] lcd_bar_x = {lcd_pos, 2'b00};
    wire        bar_row   = (y >= (v_disp - 11'd12)) && (y < (v_disp - 11'd7));
    wire        cam_bar_on = follow_enable && bar_row &&
                             (x >= cam_bar_x) && (x < (cam_bar_x + 11'd5));
    wire        lcd_bar_on = follow_enable && bar_row &&
                             (x >= lcd_bar_x) && (x < (lcd_bar_x + 11'd5));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 16'd0;
        end
        else if (de) begin
            dout <= diag_on    ? 16'hF800 :
                    cam_bar_on ? 16'h07FF :
                    lcd_bar_on ? 16'hF81F :
                    (box_on   ? 16'h07E0 : base565);

            if ((x < 11'd4) || (x >= (h_disp - 11'd4)) ||
                (y < 11'd4) || (y >= (v_disp - 11'd4)))
                dout <= mode_color;
            else if ((x < 11'd64) && (y < 11'd64))
                dout <= mode_color;
        end
    end

endmodule











