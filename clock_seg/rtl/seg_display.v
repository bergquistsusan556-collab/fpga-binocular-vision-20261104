module seg_display(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [23:0] digits_bcd,
    input  wire [5:0]  blank_mask,
    output reg  [5:0]  seg_sel,
    output reg  [7:0]  seg_led
);

    localparam integer SCAN_MAX = 50_000;

    reg [15:0] scan_cnt;
    reg [2:0]  scan_idx;
    reg [3:0]  digit;
    reg        blank;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt <= 16'd0;
            scan_idx <= 3'd0;
        end
        else if (scan_cnt == SCAN_MAX - 1) begin
            scan_cnt <= 16'd0;
            scan_idx <= (scan_idx == 3'd5) ? 3'd0 : scan_idx + 1'b1;
        end
        else begin
            scan_cnt <= scan_cnt + 1'b1;
        end
    end

    always @(*) begin
        seg_sel = 6'b111111;
        digit   = 4'd0;
        blank   = 1'b0;

        case (scan_idx)
            3'd0: begin
                seg_sel = 6'b111110;
                digit   = digits_bcd[3:0];
                blank   = blank_mask[0];
            end
            3'd1: begin
                seg_sel = 6'b111101;
                digit   = digits_bcd[7:4];
                blank   = blank_mask[1];
            end
            3'd2: begin
                seg_sel = 6'b111011;
                digit   = digits_bcd[11:8];
                blank   = blank_mask[2];
            end
            3'd3: begin
                seg_sel = 6'b110111;
                digit   = digits_bcd[15:12];
                blank   = blank_mask[3];
            end
            3'd4: begin
                seg_sel = 6'b101111;
                digit   = digits_bcd[19:16];
                blank   = blank_mask[4];
            end
            3'd5: begin
                seg_sel = 6'b011111;
                digit   = digits_bcd[23:20];
                blank   = blank_mask[5];
            end
            default: begin
                seg_sel = 6'b111111;
                digit   = 4'd0;
                blank   = 1'b1;
            end
        endcase

        if (blank) begin
            seg_led = 8'hff;
        end
        else begin
            case (digit)
                4'd0: seg_led = 8'b1100_0000;
                4'd1: seg_led = 8'b1111_1001;
                4'd2: seg_led = 8'b1010_0100;
                4'd3: seg_led = 8'b1011_0000;
                4'd4: seg_led = 8'b1001_1001;
                4'd5: seg_led = 8'b1001_0010;
                4'd6: seg_led = 8'b1000_0010;
                4'd7: seg_led = 8'b1111_1000;
                4'd8: seg_led = 8'b1000_0000;
                4'd9: seg_led = 8'b1001_0000;
                default: seg_led = 8'hff;
            endcase
        end
    end

endmodule
