`timescale 1ns/1ps
//------------------------------------------------------------------------------
// red_ycbcr_morph
//   RGB565 -> YCrCb red mask -> 3x3 dilation -> 3x3 erosion (opening).
//   The output mask is delayed by four pixels.  The target box and
//   stereo disparity logic also use the delayed mask, which keeps left/right
//   disparity unaffected because both halves receive the same delay.
//------------------------------------------------------------------------------
module red_ycbcr_morph(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        de,
    input  wire [10:0] x,
    input  wire [10:0] y,
    input  wire [10:0] h_disp,
    input  wire [10:0] v_disp,
    input  wire [15:0] din,
    output wire        red_mask_raw,
    output wire        red_mask_open,
    output wire        de_o,
    output wire [10:0] x_o,
    output wire [10:0] y_o
);

    wire [4:0] r5 = din[15:11];
    wire [5:0] g6 = din[10:5];
    wire [4:0] b5 = din[4:0];
    wire [7:0] r8 = {r5, r5[4:2]};
    wire [7:0] g8 = {g6, g6[5:4]};
    wire [7:0] b8 = {b5, b5[4:2]};

    // Fixed-point BT.601 full-range conversion:
    // Cb = 128 + (-43R - 85G + 128B) / 256
    // Cr = 128 + ( 128R - 107G -  21B) / 256
    wire [15:0] r16 = {8'b0, r8};
    wire [15:0] g16 = {8'b0, g8};
    wire [15:0] b16 = {8'b0, b8};
    wire [15:0] r43  = (r16 << 5) + (r16 << 3) + (r16 << 1) + r16;
    wire [15:0] g85  = (g16 << 6) + (g16 << 4) + (g16 << 2) + g16;
    wire [15:0] b128 = b16 << 7;
    wire [15:0] r128 = r16 << 7;
    wire [15:0] g107 = (g16 << 6) + (g16 << 5) + (g16 << 3) + (g16 << 1) + g16;
    wire [15:0] b21  = (b16 << 4) + (b16 << 2) + b16;

    wire signed [18:0] cb_num = $signed(19'sd32768)
                              - $signed({3'b0, r43})
                              - $signed({3'b0, g85})
                              + $signed({3'b0, b128});
    wire signed [18:0] cr_num = $signed(19'sd32768)
                              + $signed({2'b0, r128})
                              - $signed({3'b0, g107})
                              - $signed({3'b0, b21});

    wire [8:0] cb8 = (cb_num < 0) ? 9'd0 :
                     ((cb_num > 19'sd65280) ? 9'd255 : {1'b0, cb_num[15:8]});
    wire [8:0] cr8 = (cr_num < 0) ? 9'd0 :
                     ((cr_num > 19'sd65280) ? 9'd255 : {1'b0, cr_num[15:8]});

    // Red/orange chroma gate.  Tight enough to reject most skin and wood.
    assign red_mask_raw = (cr8 >= 9'd150) &&
                          (cb8 <= 9'd120) &&
                          (cr8 > (cb8 + 9'd40));

    wire        dil_de;
    wire [10:0] dil_x, dil_y;
    wire        dil_mask;

    bin_morph_3x3 #(.DILATE(1)) u_dilate (
        .clk       (clk),
        .rst_n     (rst_n),
        .de        (de),
        .x         (x),
        .y         (y),
        .h_disp    (h_disp),
        .v_disp    (v_disp),
        .mask_in   (red_mask_raw),
        .de_o      (dil_de),
        .x_o       (dil_x),
        .y_o       (dil_y),
        .mask_o    (dil_mask)
    );

    bin_morph_3x3 #(.DILATE(0)) u_erode (
        .clk       (clk),
        .rst_n     (rst_n),
        .de        (dil_de),
        .x         (dil_x),
        .y         (dil_y),
        .h_disp    (h_disp),
        .v_disp    (v_disp),
        .mask_in   (dil_mask),
        .de_o      (de_o),
        .x_o       (x_o),
        .y_o       (y_o),
        .mask_o    (red_mask_open)
    );

endmodule


module bin_morph_3x3 #(
    parameter integer DILATE = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        de,
    input  wire [10:0] x,
    input  wire [10:0] y,
    input  wire [10:0] h_disp,
    input  wire [10:0] v_disp,
    input  wire        mask_in,
    output reg         de_o,
    output reg  [10:0] x_o,
    output reg  [10:0] y_o,
    output reg         mask_o
);

    reg line1 [0:2047];
    reg line2 [0:2047];

    reg r1, r2;
    reg p0, p1, p2;
    reg q0, q1, q2;
    reg s0, s1, s2;

    reg de_d1, de_d2;
    reg [10:0] x_d1, x_d2;
    reg [10:0] y_d1, y_d2;

    wire [8:0] win = {p0, p1, p2, q0, q1, q2, s0, s1, s2};
    wire morph = DILATE ? (|win) : (&win);
    wire valid = de_d2 && (x_d2 >= 11'd2) && (y_d2 >= 11'd2) &&
                 (x_d2 < (h_disp - 11'd2)) && (y_d2 < (v_disp - 11'd2));

    // Line buffers must stay outside the asynchronous-reset block.
    always @(posedge clk) begin
        if (de) begin
            r1 <= line1[x];
            r2 <= line2[x];
            line2[x] <= line1[x];
            line1[x] <= mask_in;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p0 <= 1'b0; p1 <= 1'b0; p2 <= 1'b0;
            q0 <= 1'b0; q1 <= 1'b0; q2 <= 1'b0;
            s0 <= 1'b0; s1 <= 1'b0; s2 <= 1'b0;
            de_d1 <= 1'b0; de_d2 <= 1'b0;
            x_d1 <= 11'd0; x_d2 <= 11'd0;
            y_d1 <= 11'd0; y_d2 <= 11'd0;
        end
        else begin
            de_d1 <= de;
            de_d2 <= de_d1;
            x_d1 <= x;
            x_d2 <= x_d1;
            y_d1 <= y;
            y_d2 <= y_d1;

            if (de) begin
                p2 <= p1; p1 <= p0; p0 <= mask_in;
                q2 <= q1; q1 <= q0; q0 <= r1;
                s2 <= s1; s1 <= s0; s0 <= r2;
            end
        end
    end

    always @(*) begin
        de_o   = de_d2;
        x_o    = x_d2;
        y_o    = y_d2;
        mask_o = valid ? morph : 1'b0;
    end

endmodule
