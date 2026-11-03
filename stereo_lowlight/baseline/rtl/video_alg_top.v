`timescale 1ns/1ps
// Real-time video processing for the dual OV5640 HDMI pipeline.
// Modes are selected by KEY0 and shown on LED[2:0].
// 0 RAW, 1 GRAY, 2 BINARY, 3 EDGE, 4 4x FRAME DIFF,
// 5 RED TARGET BOX FOLLOW, 6 INVERT, 7 STEREO DEPTH.
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
    input  wire [15:0] din,
    output reg  [15:0] dout
);

    localparam MODE_RAW    = 3'd0;
    localparam MODE_GRAY   = 3'd1;
    localparam MODE_BINARY = 3'd2;
    localparam MODE_EDGE   = 3'd3;
    localparam MODE_DIFF   = 3'd4;
    localparam MODE_TARGET = 3'd5;
    localparam MODE_INVERT = 3'd6;
    localparam MODE_DEPTH  = 3'd7;

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
    wire [9:0] lum_sum = {1'b0, r8} + {g8, 1'b0} + {1'b0, b8};
    wire [7:0] lum = lum_sum[9:2];

    wire [15:0] gray565 = {lum[7:3], lum[7:2], lum[7:3]};
    wire [15:0] binary565 = (lum > 8'd96) ? 16'hFFFF : 16'h0000;
    wire [15:0] invert565 = ~din;

    // Line buffer used by the 1-D horizontal/vertical edge detector.
    reg [7:0] line_mem [0:2047];
    reg [7:0] line_q;
    reg [7:0] lum_d1;

    always @(posedge clk) begin
        if (de) begin
            line_q <= line_mem[x[10:0]];
            line_mem[x[10:0]] <= lum;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lum_d1 <= 8'd0;
        else if (de)
            lum_d1 <= lum;
    end

    wire [7:0] diff_h = (lum > lum_d1) ? (lum - lum_d1) : (lum_d1 - lum);
    wire [7:0] diff_v = (lum > line_q) ? (lum - line_q) : (line_q - lum);
    wire [8:0] edge_sum = {1'b0, diff_h} + {1'b0, diff_v};
    wire [15:0] edge565 = (edge_sum > 9'd48) ? 16'hFFFF : 16'h0000;

    wire [10:0] half_x = {1'b0, h_disp[10:1]};

    wire [15:0] dim565 = {din[15:11] >> 1, din[10:5] >> 1, din[4:0] >> 1};
    wire [7:0] line_diff = (lum > line_q) ? (lum - line_q) : (line_q - lum);
    wire [15:0] diff565 = (line_diff > 8'd20) ? 16'hF800 : dim565;

    // RGB565 -> YCrCb red mask -> 3x3 dilation -> 3x3 erosion.
    wire        red_mask_raw;
    wire        red_mask_open;
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
        .red_mask_raw  (red_mask_raw),
        .red_mask_open (red_mask_open),
        .de_o          (morph_de),
        .x_o           (morph_x),
        .y_o           (morph_y)
    );


    // Simple colour-template / red-target detector with a previous-frame box.
    // This is intentionally small enough to run in the display pixel clock.
    wire [8:0] target_rg_diff = (r8 > g8) ? ({1'b0, r8} - {1'b0, g8}) : 9'd0;
    wire [8:0] target_rb_diff = (r8 > b8) ? ({1'b0, r8} - {1'b0, b8}) : 9'd0;
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

    wire [11:0] l_cur_cx = ({1'b0, l_box_x0} + {1'b0, l_box_x1}) >> 1;
    wire [11:0] l_cur_cy = ({1'b0, l_box_y0} + {1'b0, l_box_y1}) >> 1;
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
        end
        else if (morph_de) begin
            if (red_pix && (morph_x < half_x) && l_in_search) begin
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
            else if (red_pix && (morph_x >= half_x) && r_in_search) begin
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
                if (l_det_valid) begin
                    l_box_x0 <= l_upd_fx0; l_box_x1 <= l_upd_fx1;
                    l_box_y0 <= l_upd_fy0; l_box_y1 <= l_upd_fy1;
                    l_box_valid <= 1'b1;
                    l_miss <= 3'd0;
                    if (l_search_w > SEARCH_MIN_W) l_search_w <= l_search_w - SEARCH_STEP;
                    if (l_search_h > SEARCH_MIN_H) l_search_h <= l_search_h - SEARCH_STEP;
                end
                else if (l_box_valid && (l_miss < 3'd2)) begin
                    l_miss <= l_miss + 3'd1;
                    if (l_search_w < SEARCH_MAX_W) l_search_w <= l_search_w + SEARCH_STEP;
                    if (l_search_h < SEARCH_MAX_H) l_search_h <= l_search_h + SEARCH_STEP;
                end
                else begin
                    l_box_valid <= 1'b0;
                    l_search_w <= SEARCH_MAX_W; l_search_h <= SEARCH_MAX_H;
                    l_miss <= 3'd0;
                end

                if (r_det_valid) begin
                    r_box_x0 <= r_upd_fx0; r_box_x1 <= r_upd_fx1;
                    r_box_y0 <= r_upd_fy0; r_box_y1 <= r_upd_fy1;
                    r_box_valid <= 1'b1;
                    r_miss <= 3'd0;
                    if (r_search_w > SEARCH_MIN_W) r_search_w <= r_search_w - SEARCH_STEP;
                    if (r_search_h > SEARCH_MIN_H) r_search_h <= r_search_h - SEARCH_STEP;
                end
                else if (r_box_valid && (r_miss < 3'd2)) begin
                    r_miss <= r_miss + 3'd1;
                    if (r_search_w < SEARCH_MAX_W) r_search_w <= r_search_w + SEARCH_STEP;
                    if (r_search_h < SEARCH_MAX_H) r_search_h <= r_search_h + SEARCH_STEP;
                end
                else begin
                    r_box_valid <= 1'b0;
                    r_search_w <= SEARCH_MAX_W; r_search_h <= SEARCH_MAX_H;
                    r_miss <= 3'd0;
                end

                l_seen <= 1'b0; r_seen <= 1'b0;
                l_track_count <= 16'd0; r_track_count <= 16'd0;
            end
        end
    end

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
    wire [15:0] stereo_distance_cm;
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
            MODE_RAW:    mode_color = 16'hFFFF;
            MODE_GRAY:   mode_color = 16'h8410;
            MODE_BINARY: mode_color = 16'h0000;
            MODE_EDGE:   mode_color = 16'h07E0;
            MODE_DIFF:   mode_color = 16'hF800;
            MODE_TARGET: mode_color = 16'hF81F;
            MODE_INVERT: mode_color = 16'h07FF;
            MODE_DEPTH:  mode_color = 16'h07FF;
            default:     mode_color = 16'hFFFF;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 16'd0;
        end
        else if (de) begin
            case (mode)
                MODE_RAW:    dout <= din;
                MODE_GRAY:   dout <= gray565;
                MODE_BINARY: dout <= binary565;
                MODE_EDGE:   dout <= edge565;
                MODE_DIFF:   dout <= diff565;
                MODE_TARGET: dout <= distance_osd_active ? distance_osd_rgb : target565;
                MODE_INVERT: dout <= invert565;
                MODE_DEPTH:  dout <= distance_osd_active ? distance_osd_rgb : stereo_rgb;
                default:     dout <= din;
            endcase

            if ((x < 11'd4) || (x >= (h_disp - 11'd4)) ||
                (y < 11'd4) || (y >= (v_disp - 11'd4)))
                dout <= mode_color;
            else if ((x < 11'd64) && (y < 11'd64))
                dout <= mode_color;
        end
    end

endmodule











