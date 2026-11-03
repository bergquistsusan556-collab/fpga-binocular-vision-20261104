`timescale 1ns/1ps
//------------------------------------------------------------------------------
// distance_osd
//   5x7 bitmap OSD, large on wide LCDs, showing D=xxxxcm.
//   The 256-pixel banner is horizontally centered for the active LCD width.
//------------------------------------------------------------------------------
module distance_osd(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [10:0] x,
    input  wire [10:0] y,
    input  wire [10:0] h_disp,
    input  wire [15:0] distance_cm,
    input  wire        distance_valid,
    output reg         osd_active,
    output reg  [15:0] osd_rgb
);

    wire        osd_large = 1'b0;
    wire [10:0] OSD_W = osd_large ? 11'd512 : 11'd256;
    wire [10:0] OSD_H = osd_large ? 11'd64  : 11'd32;
    localparam [10:0] OSD_Y = 11'd8;
    wire [10:0] osd_x0 = (h_disp - OSD_W) >> 1;

    localparam [3:0] CH_D    = 4'd10;
    localparam [3:0] CH_EQ   = 4'd11;
    localparam [3:0] CH_C    = 4'd12;
    localparam [3:0] CH_M    = 4'd13;
    localparam [3:0] CH_DASH = 4'd14;

    reg [13:0] dist_hold;
    reg [3:0]  dig3, dig2, dig1, dig0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dist_hold <= 14'd0;
            dig3 <= 4'd0;
            dig2 <= 4'd0;
            dig1 <= 4'd0;
            dig0 <= 4'd0;
        end
        else if (distance_cm != {2'b00, dist_hold}) begin
            dist_hold <= distance_cm[13:0];
            dig3 <= distance_cm / 16'd1000;
            dig2 <= (distance_cm / 16'd100) % 16'd10;
            dig1 <= (distance_cm / 16'd10) % 16'd10;
            dig0 <= distance_cm % 16'd10;
        end
    end

    function [4:0] glyph;
        input [3:0] code;
        input [2:0] row;
        begin
            glyph = 5'b00000;
            case (code)
                4'd0: case (row)
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001;
                    3'd2: glyph = 5'b10011; 3'd3: glyph = 5'b10101;
                    3'd4: glyph = 5'b11001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110;
                endcase
                4'd1: case (row)
                    3'd0: glyph = 5'b00100; 3'd1: glyph = 5'b01100;
                    3'd2: glyph = 5'b00100; 3'd3: glyph = 5'b00100;
                    3'd4: glyph = 5'b00100; 3'd5: glyph = 5'b00100;
                    default: glyph = 5'b01110;
                endcase
                4'd2: case (row)
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001;
                    3'd2: glyph = 5'b00001; 3'd3: glyph = 5'b00010;
                    3'd4: glyph = 5'b00100; 3'd5: glyph = 5'b01000;
                    default: glyph = 5'b11111;
                endcase
                4'd3: case (row)
                    3'd0: glyph = 5'b11110; 3'd1: glyph = 5'b00001;
                    3'd2: glyph = 5'b00001; 3'd3: glyph = 5'b01110;
                    3'd4: glyph = 5'b00001; 3'd5: glyph = 5'b00001;
                    default: glyph = 5'b11110;
                endcase
                4'd4: case (row)
                    3'd0: glyph = 5'b00010; 3'd1: glyph = 5'b00110;
                    3'd2: glyph = 5'b01010; 3'd3: glyph = 5'b10010;
                    3'd4: glyph = 5'b11111; 3'd5: glyph = 5'b00010;
                    default: glyph = 5'b00010;
                endcase
                4'd5: case (row)
                    3'd0: glyph = 5'b11111; 3'd1: glyph = 5'b10000;
                    3'd2: glyph = 5'b10000; 3'd3: glyph = 5'b11110;
                    3'd4: glyph = 5'b00001; 3'd5: glyph = 5'b00001;
                    default: glyph = 5'b11110;
                endcase
                4'd6: case (row)
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10000;
                    3'd2: glyph = 5'b10000; 3'd3: glyph = 5'b11110;
                    3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110;
                endcase
                4'd7: case (row)
                    3'd0: glyph = 5'b11111; 3'd1: glyph = 5'b00001;
                    3'd2: glyph = 5'b00010; 3'd3: glyph = 5'b00100;
                    3'd4: glyph = 5'b01000; 3'd5: glyph = 5'b01000;
                    default: glyph = 5'b01000;
                endcase
                4'd8: case (row)
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001;
                    3'd2: glyph = 5'b10001; 3'd3: glyph = 5'b01110;
                    3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110;
                endcase
                4'd9: case (row)
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001;
                    3'd2: glyph = 5'b10001; 3'd3: glyph = 5'b01111;
                    3'd4: glyph = 5'b00001; 3'd5: glyph = 5'b00001;
                    default: glyph = 5'b01110;
                endcase
                CH_D: case (row)
                    3'd0: glyph = 5'b11110; 3'd1: glyph = 5'b10001;
                    3'd2: glyph = 5'b10001; 3'd3: glyph = 5'b10001;
                    3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b11110;
                endcase
                CH_EQ: case (row)
                    3'd2: glyph = 5'b11111; 3'd5: glyph = 5'b11111;
                    default: glyph = 5'b00000;
                endcase
                CH_C: case (row)
                    3'd2: glyph = 5'b01110; 3'd3: glyph = 5'b10000;
                    3'd4: glyph = 5'b10000; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110;
                endcase
                CH_M: case (row)
                    3'd2: glyph = 5'b11010; 3'd3: glyph = 5'b10101;
                    3'd4: glyph = 5'b10101; 3'd5: glyph = 5'b10101;
                    default: glyph = 5'b10101;
                endcase
                CH_DASH: case (row)
                    3'd3: glyph = 5'b11111;
                    default: glyph = 5'b00000;
                endcase
                default: glyph = 5'b00000;
            endcase
        end
    endfunction

    wire [11:0] osd_dx = {1'b0, x} - {1'b0, osd_x0};
    wire in_banner = (x >= osd_x0) && (x < (osd_x0 + OSD_W)) &&
                     (y >= OSD_Y) && (y < (OSD_Y + OSD_H));
    wire [5:0] col_num = osd_large ? osd_dx[11:6] : osd_dx[10:5];
    wire [6:0] fx_large = osd_dx[5:0] - 7'd20;
    wire [6:0] fy_large = y[5:0] - 7'd4;
    wire [4:0] fx_small = osd_dx[4:0] - 5'd6;
    wire [4:0] fy_small = y[4:0] - OSD_Y - 5'd2;
    wire [2:0] gx = osd_large ? fx_large[5:3] : fx_small[4:2];
    wire [2:0] gy = osd_large ? fy_large[5:3] : fy_small[4:2];
    wire glyph_in_cell = osd_large ?
                         ((fx_large < 7'd40) && (fy_large < 7'd56)) :
                         ((fx_small < 5'd20) && (fy_small < 5'd28));

    wire [3:0] char_code =
        (col_num == 6'd0) ? CH_D :
        (col_num == 6'd1) ? CH_EQ :
        (col_num == 6'd2) ? (distance_valid ? dig3 : CH_DASH) :
        (col_num == 6'd3) ? (distance_valid ? dig2 : CH_DASH) :
        (col_num == 6'd4) ? (distance_valid ? dig1 : CH_DASH) :
        (col_num == 6'd5) ? (distance_valid ? dig0 : CH_DASH) :
        (col_num == 6'd6) ? CH_C : CH_M;

    wire glyph_on_pre = in_banner && glyph_in_cell;
    wire [4:0] glyph_row = glyph(char_code, gy);
    wire glyph_on = glyph_on_pre && ((glyph_row & (5'b10000 >> gx)) != 5'd0);

    wire border = in_banner && ((x < (osd_x0 + 11'd2)) ||
                                (x >= (osd_x0 + OSD_W - 11'd2)) ||
                                (y < (OSD_Y + 11'd2)) ||
                                (y >= (OSD_Y + OSD_H - 11'd2)));

    always @(*) begin
        osd_active = in_banner;
        if (!in_banner)
            osd_rgb = 16'h0000;
        else if (border)
            osd_rgb = 16'h07FF;
        else if (glyph_on)
            osd_rgb = 16'hFFE0;
        else
            osd_rgb = 16'h0000;
    end

endmodule








