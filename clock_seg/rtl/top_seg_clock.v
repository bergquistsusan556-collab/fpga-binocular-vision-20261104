module top_seg_clock #(
    parameter [0:0]  FORCE_INIT = 1'b0,
    parameter [47:0] TIME_INIT  = 48'h26_09_16_13_43_00
)(
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    input  wire [3:0] key,
    inout  wire       iic_sda,
    output wire       iic_scl,
    output wire [5:0] seg_sel,
    output wire [7:0] seg_led,
    output wire [3:0] led
);

    parameter SLAVE_ADDR = 7'b101_0001;
    parameter BIT_CTRL   = 1'b0;
    parameter CLK_FREQ   = 26'd50_000_000;
    parameter I2C_FREQ   = 18'd250_000;

    wire        dri_clk;
    wire        i2c_rh_wl;
    wire        i2c_exec;
    wire [15:0] i2c_addr;
    wire [7:0]  i2c_data_w;
    wire [7:0]  i2c_data_r;
    wire        i2c_done;
    wire        i2c_ack;

    wire [7:0]  sec_bcd;
    wire [7:0]  min_bcd;
    wire [7:0]  hour_bcd;
    wire [1:0]  set_mode;
    wire        rtc_ok;

    reg [7:0] sec_sync1,  sec_sync2;
    reg [7:0] min_sync1,  min_sync2;
    reg [7:0] hour_sync1, hour_sync2;
    reg [1:0] mode_sync1, mode_sync2;
    reg       ok_sync1,   ok_sync2;

    reg [24:0] blink_cnt;
    wire       blink;
    wire [23:0] digits_bcd;
    wire [5:0]  blank_mask;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            sec_sync1  <= 8'h00;
            sec_sync2  <= 8'h00;
            min_sync1  <= 8'h00;
            min_sync2  <= 8'h00;
            hour_sync1 <= 8'h00;
            hour_sync2 <= 8'h00;
            mode_sync1 <= 2'd0;
            mode_sync2 <= 2'd0;
            ok_sync1   <= 1'b0;
            ok_sync2   <= 1'b0;
            blink_cnt  <= 25'd0;
        end
        else begin
            sec_sync1  <= sec_bcd;
            sec_sync2  <= sec_sync1;
            min_sync1  <= min_bcd;
            min_sync2  <= min_sync1;
            hour_sync1 <= hour_bcd;
            hour_sync2 <= hour_sync1;
            mode_sync1 <= set_mode;
            mode_sync2 <= mode_sync1;
            ok_sync1   <= rtc_ok;
            ok_sync2   <= ok_sync1;
            blink_cnt  <= blink_cnt + 1'b1;
        end
    end

    assign blink = blink_cnt[24];

    i2c_dri #(
        .SLAVE_ADDR(SLAVE_ADDR),
        .CLK_FREQ  (CLK_FREQ),
        .I2C_FREQ  (I2C_FREQ)
    ) u_i2c_dri (
        .clk       (sys_clk),
        .rst_n     (sys_rst_n),
        .i2c_exec  (i2c_exec),
        .bit_ctrl  (BIT_CTRL),
        .i2c_rh_wl (i2c_rh_wl),
        .i2c_addr  (i2c_addr),
        .i2c_data_w(i2c_data_w),
        .i2c_data_r(i2c_data_r),
        .i2c_done  (i2c_done),
        .i2c_ack   (i2c_ack),
        .scl       (iic_scl),
        .sda       (iic_sda),
        .dri_clk   (dri_clk)
    );

    rtc_clock_ctrl #(
        .CLK_HZ    (1_000_000),
        .FORCE_INIT(FORCE_INIT),
        .TIME_INIT (TIME_INIT)
    ) u_rtc_clock_ctrl (
        .clk       (dri_clk),
        .rst_n     (sys_rst_n),
        .key       (key),
        .i2c_rh_wl (i2c_rh_wl),
        .i2c_exec  (i2c_exec),
        .i2c_addr  (i2c_addr),
        .i2c_data_w(i2c_data_w),
        .i2c_data_r(i2c_data_r),
        .i2c_done  (i2c_done),
        .i2c_ack   (i2c_ack),
        .sec_bcd   (sec_bcd),
        .min_bcd   (min_bcd),
        .hour_bcd  (hour_bcd),
        .set_mode  (set_mode),
        .rtc_ok    (rtc_ok)
    );

    assign digits_bcd = {hour_sync2, min_sync2, sec_sync2};

    assign blank_mask = (mode_sync2 == 2'd1) ? (blink ? 6'b110000 : 6'b000000) :
                        (mode_sync2 == 2'd2) ? (blink ? 6'b001100 : 6'b000000) :
                        (mode_sync2 == 2'd3) ? (blink ? 6'b000011 : 6'b000000) :
                                             6'b000000;

    seg_display u_seg_display (
        .clk       (sys_clk),
        .rst_n     (sys_rst_n),
        .digits_bcd(digits_bcd),
        .blank_mask(blank_mask),
        .seg_sel   (seg_sel),
        .seg_led   (seg_led)
    );

    assign led[0] = sec_sync2[0];
    assign led[1] = ok_sync2;
    assign led[3:2] = mode_sync2;

endmodule
