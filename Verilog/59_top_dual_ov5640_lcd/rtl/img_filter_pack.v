`timescale 1ns/1ps
//------------------------------------------------------------------------------
// img_filter_pack
//   One aligned 3x3 luma window feeding the "video algorithm" display modes:
//     - dual-threshold (window) binarisation, low/high adjustable at runtime
//     - 3x3 erosion / dilation of that binary image
//     - opening = erosion followed by dilation (a second 3x3 stage)
//     - emboss, Laplacian sharpening, Sobel edge magnitude
//
//   Line buffer note: the three rows are read so that all nine taps belong to
//   the SAME pixel columns (a real axis-aligned 3x3 stencil).  The older
//   bin_morph_3x3 in red_ycbcr_morph.v pipelines the lower two rows through an
//   extra register, which skews its structuring element by one pixel; that
//   quirk is deliberately NOT copied here.
//
//   All taps live in registers, so the results below are combinational and are
//   sampled by the caller on its next active `de`.  The window is centred on
//   column X-1 of row Y-1, so every result is shifted by one pixel and one
//   line - imperceptible on the panel and consistent with the rest of the
//   design, which also samples on the input `de`.
//------------------------------------------------------------------------------
module img_filter_pack(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        de,
    input  wire [10:0] x,
    input  wire [7:0]  thr_low,
    input  wire [7:0]  thr_high,
    input  wire [15:0] din,
    output wire [15:0] bin565,
    output wire [15:0] erode565,
    output wire [15:0] open565,
    output wire [15:0] emboss565,
    output wire [15:0] lap565,
    output wire [15:0] sobel565
);

    //------------------------------------------------------------------
    // RGB565 -> luma
    //------------------------------------------------------------------
    wire [4:0] r5 = din[15:11];
    wire [5:0] g6 = din[10:5];
    wire [4:0] b5 = din[4:0];
    wire [7:0] r8 = {r5, r5[4:2]};
    wire [7:0] g8 = {g6, g6[5:4]};
    wire [7:0] b8 = {b5, b5[4:2]};
    wire [9:0] lum_sum = {1'b0, r8} + {g8, 1'b0} + {1'b0, b8};
    wire [7:0] lum = lum_sum[9:2];

    //------------------------------------------------------------------
    // Two line buffers -> aligned 3x3 window
    //   a* = row Y-2, b* = row Y-1, c* = row Y
    //   suffix 0 = column X, 1 = X-1, 2 = X-2
    //------------------------------------------------------------------
    reg [7:0] line1 [0:2047];
    reg [7:0] line2 [0:2047];

    reg [7:0] c0, c1, c2;
    reg [7:0] b0, b1, b2;
    reg [7:0] a0, a1, a2;

    always @(posedge clk) begin
        if (de) begin
            c0 <= lum;   c1 <= c0;   c2 <= c1;
            b0 <= line1[x]; b1 <= b0; b2 <= b1;
            a0 <= line2[x]; a1 <= a0; a2 <= a1;
            line2[x] <= line1[x];
            line1[x] <= lum;
        end
    end

    //------------------------------------------------------------------
    // Dual-threshold (window) binarisation of the whole window
    //------------------------------------------------------------------
    wire t_a2 = (a2 >= thr_low) && (a2 <= thr_high);
    wire t_a1 = (a1 >= thr_low) && (a1 <= thr_high);
    wire t_a0 = (a0 >= thr_low) && (a0 <= thr_high);
    wire t_b2 = (b2 >= thr_low) && (b2 <= thr_high);
    wire t_b1 = (b1 >= thr_low) && (b1 <= thr_high);
    wire t_b0 = (b0 >= thr_low) && (b0 <= thr_high);
    wire t_c2 = (c2 >= thr_low) && (c2 <= thr_high);
    wire t_c1 = (c1 >= thr_low) && (c1 <= thr_high);
    wire t_c0 = (c0 >= thr_low) && (c0 <= thr_high);

    wire [8:0] win_bin = {t_a2, t_a1, t_a0, t_b2, t_b1, t_b0, t_c2, t_c1, t_c0};

    wire bin_bit    = t_b1;      // plain threshold of the centre pixel
    wire erode_bit  = &win_bin;  // 3x3 erosion
    wire dilate_bit = |win_bin;  // 3x3 dilation

    //------------------------------------------------------------------
    // Opening = erosion -> dilation, on a second 3x3 stage (1-bit buffers)
    //------------------------------------------------------------------
    reg line1_o [0:2047];
    reg line2_o [0:2047];

    reg oc0, oc1, oc2;
    reg ob0, ob1, ob2;
    reg oa0, oa1, oa2;

    always @(posedge clk) begin
        if (de) begin
            oc0 <= erode_bit; oc1 <= oc0; oc2 <= oc1;
            ob0 <= line1_o[x]; ob1 <= ob0; ob2 <= ob1;
            oa0 <= line2_o[x]; oa1 <= oa0; oa2 <= oa1;
            line2_o[x] <= line1_o[x];
            line1_o[x] <= erode_bit;
        end
    end

    wire open_bit = oc0 | oc1 | oc2 | ob0 | ob1 | ob2 | oa0 | oa1 | oa2;

    //------------------------------------------------------------------
    // Emboss   [-2 -1  0; -1  1  1;  0  1  2]  + 128
    //------------------------------------------------------------------
    wire signed [12:0] emb_sum =
          $signed({4'b0, a2, 1'b0})     // -2*a2
        + $signed({5'b0, a1})           // -1*a1
        + $signed({5'b0, b2})           // -1*b2
        - $signed({5'b0, b1})           // +1*b1
        - $signed({5'b0, b0})           // +1*b0
        - $signed({5'b0, c1})           // +1*c1
        - $signed({4'b0, c0, 1'b0});    // +2*c0

    wire signed [13:0] emb_off = emb_sum + 14'sd128;
    wire [7:0] emb_v = (emb_off < 14'sd0)   ? 8'd0 :
                       (emb_off > 14'sd255) ? 8'd255 : emb_off[7:0];

    //------------------------------------------------------------------
    // Laplacian sharpening:  out = c + (4*b1 - (a1 + c1 + b2 + b0)) / 2
    //------------------------------------------------------------------
    wire [9:0] lap_nbr = a1 + c1 + b2 + b0;
    wire signed [12:0] lap_s = $signed({3'b0, b1, 2'b00}) - $signed({3'b0, lap_nbr});
    wire signed [12:0] sharp_s = $signed({5'b0, b1}) + (lap_s >>> 1);

    wire [7:0] lap_v = (sharp_s < 13'sd0)   ? 8'd0 :
                       (sharp_s > 13'sd255) ? 8'd255 : sharp_s[7:0];

    //------------------------------------------------------------------
    // Sobel magnitude, then a fixed edge threshold to give the usual
    // white-on-black edge picture.
    //------------------------------------------------------------------
    wire [9:0] gx_pos = c0 + {b0, 1'b0} + a0;
    wire [9:0] gx_neg = c2 + {b2, 1'b0} + a2;
    wire [9:0] gy_pos = c2 + {c1, 1'b0} + c0;
    wire [9:0] gy_neg = a2 + {a1, 1'b0} + a0;

    wire [10:0] gx_abs = (gx_pos >= gx_neg) ? (gx_pos - gx_neg) : (gx_neg - gx_pos);
    wire [10:0] gy_abs = (gy_pos >= gy_neg) ? (gy_pos - gy_neg) : (gy_neg - gy_pos);
    wire [11:0] sob_sum = gx_abs + gy_abs;      // 0..2040
    wire [7:0]  sob_v   = sob_sum[10:3];        // 0..255

    localparam [7:0] SOBEL_THRESH = 8'd40;

    //------------------------------------------------------------------
    // RGB565 packing
    //------------------------------------------------------------------
    assign bin565    = bin_bit    ? 16'hFFFF : 16'h0000;
    assign erode565  = erode_bit  ? 16'hFFFF : 16'h0000;
    assign open565   = open_bit   ? 16'hFFFF : 16'h0000;
    assign emboss565 = {emb_v[7:3], emb_v[7:2], emb_v[7:3]};
    assign lap565    = {lap_v[7:3], lap_v[7:2], lap_v[7:3]};
    assign sobel565  = (sob_v > SOBEL_THRESH) ? 16'hFFFF : 16'h0000;

endmodule
