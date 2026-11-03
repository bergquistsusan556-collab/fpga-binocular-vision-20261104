module rtc_clock_ctrl #(
    parameter integer CLK_HZ = 1_000_000,
    parameter [0:0]   FORCE_INIT = 1'b0,
    parameter [47:0]  TIME_INIT = 48'h26_09_16_13_43_00
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  key,
    output reg         i2c_rh_wl,
    output reg         i2c_exec,
    output reg  [15:0] i2c_addr,
    output reg  [7:0]  i2c_data_w,
    input  wire [7:0]  i2c_data_r,
    input  wire        i2c_done,
    input  wire        i2c_ack,
    output reg  [7:0]  sec_bcd,
    output reg  [7:0]  min_bcd,
    output reg  [7:0]  hour_bcd,
    output reg  [1:0]  set_mode,
    output reg         rtc_ok
);

    localparam [1:0] MODE_RUN      = 2'd0;
    localparam [1:0] MODE_SET_HOUR = 2'd1;
    localparam [1:0] MODE_SET_MIN  = 2'd2;
    localparam [1:0] MODE_SET_SEC  = 2'd3;

    localparam [2:0] S_BOOT        = 3'd0;
    localparam [2:0] S_WAIT        = 3'd1;
    localparam [2:0] S_READ_START  = 3'd2;
    localparam [2:0] S_READ_WAIT   = 3'd3;
    localparam [2:0] S_WRITE_START = 3'd4;
    localparam [2:0] S_WRITE_WAIT  = 3'd5;

    localparam integer BOOT_WAIT   = CLK_HZ / 10;
    localparam integer READ_PERIOD = CLK_HZ;

    reg [2:0]  state;
    reg [2:0]  idx;
    reg [20:0] wait_cnt;
    reg [20:0] period_cnt;
    reg        save_req;
    reg [15:0] rd_addr;
    reg [15:0] wr_addr;
    reg [7:0]  wr_data;
    reg [7:0]  day_bcd;
    reg [7:0]  mon_bcd;
    reg [7:0]  year_bcd;

    wire key_mode_press;
    wire key_plus_press;
    wire key_minus_press;
    wire key_clear_press;
    wire key_mode_level;
    wire key_plus_level;
    wire key_minus_level;
    wire key_clear_level;

    function [6:0] bcd2bin;
        input [7:0] bcd;
        reg   [7:0] tmp;
        begin
            tmp = (bcd[7:4] * 8'd10) + {4'b0, bcd[3:0]};
            bcd2bin = tmp[6:0];
        end
    endfunction

    function [7:0] bin2bcd;
        input [6:0] bin;
        reg   [3:0] tens;
        reg   [3:0] ones;
        begin
            tens = bin / 8'd10;
            ones = bin % 8'd10;
            bin2bcd = {tens, ones};
        end
    endfunction

    function [7:0] bcd_inc;
        input [7:0] value;
        input [6:0] max_value;
        reg   [6:0] tmp;
        begin
            tmp = bcd2bin(value);
            if (tmp >= max_value)
                tmp = 7'd0;
            else
                tmp = tmp + 1'b1;
            bcd_inc = bin2bcd(tmp);
        end
    endfunction

    function [7:0] bcd_dec;
        input [7:0] value;
        input [6:0] max_value;
        reg   [6:0] tmp;
        begin
            tmp = bcd2bin(value);
            if (tmp == 7'd0)
                tmp = max_value;
            else
                tmp = tmp - 1'b1;
            bcd_dec = bin2bcd(tmp);
        end
    endfunction

    always @(*) begin
        case (idx)
            3'd0: rd_addr = 16'h02;
            3'd1: rd_addr = 16'h03;
            3'd2: rd_addr = 16'h04;
            3'd3: rd_addr = 16'h05;
            3'd4: rd_addr = 16'h07;
            3'd5: rd_addr = 16'h08;
            default: rd_addr = 16'h02;
        endcase
    end

    always @(*) begin
        case (idx)
            3'd0: begin wr_addr = 16'h02; wr_data = sec_bcd;  end
            3'd1: begin wr_addr = 16'h03; wr_data = min_bcd;  end
            3'd2: begin wr_addr = 16'h04; wr_data = hour_bcd; end
            3'd3: begin wr_addr = 16'h05; wr_data = day_bcd;  end
            3'd4: begin wr_addr = 16'h07; wr_data = mon_bcd;  end
            3'd5: begin wr_addr = 16'h08; wr_data = year_bcd; end
            default: begin wr_addr = 16'h02; wr_data = 8'h00; end
        endcase
    end

    key_debounce #(.CNT_MAX(CLK_HZ / 100)) u_key_mode (
        .clk(clk), .rst_n(rst_n), .key_in(key[3]),
        .key_level(key_mode_level), .key_press(key_mode_press)
    );

    key_debounce #(.CNT_MAX(CLK_HZ / 100)) u_key_plus (
        .clk(clk), .rst_n(rst_n), .key_in(key[2]),
        .key_level(key_plus_level), .key_press(key_plus_press)
    );

    key_debounce #(.CNT_MAX(CLK_HZ / 100)) u_key_minus (
        .clk(clk), .rst_n(rst_n), .key_in(key[1]),
        .key_level(key_minus_level), .key_press(key_minus_press)
    );

    key_debounce #(.CNT_MAX(CLK_HZ / 100)) u_key_clear (
        .clk(clk), .rst_n(rst_n), .key_in(key[0]),
        .key_level(key_clear_level), .key_press(key_clear_press)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_BOOT;
            idx        <= 3'd0;
            wait_cnt   <= 21'd0;
            period_cnt <= 21'd0;
            save_req   <= 1'b0;
            i2c_rh_wl  <= 1'b0;
            i2c_exec   <= 1'b0;
            i2c_addr   <= 16'd0;
            i2c_data_w <= 8'd0;
            sec_bcd    <= 8'h00;
            min_bcd    <= 8'h00;
            hour_bcd   <= 8'h00;
            day_bcd    <= 8'h01;
            mon_bcd    <= 8'h01;
            year_bcd   <= 8'h00;
            set_mode   <= MODE_RUN;
            rtc_ok     <= 1'b0;
        end
        else begin
            i2c_exec <= 1'b0;

            if (key_mode_press) begin
                if (set_mode == MODE_SET_SEC) begin
                    set_mode <= MODE_RUN;
                    save_req <= 1'b1;
                end
                else begin
                    set_mode <= set_mode + 1'b1;
                end
            end

            if (key_plus_press) begin
                case (set_mode)
                    MODE_SET_HOUR: hour_bcd <= bcd_inc(hour_bcd, 7'd23);
                    MODE_SET_MIN:  min_bcd  <= bcd_inc(min_bcd,  7'd59);
                    MODE_SET_SEC:  sec_bcd  <= bcd_inc(sec_bcd,  7'd59);
                    default: ;
                endcase
            end

            if (key_minus_press) begin
                case (set_mode)
                    MODE_SET_HOUR: hour_bcd <= bcd_dec(hour_bcd, 7'd23);
                    MODE_SET_MIN:  min_bcd  <= bcd_dec(min_bcd,  7'd59);
                    MODE_SET_SEC:  sec_bcd  <= bcd_dec(sec_bcd,  7'd59);
                    default: ;
                endcase
            end

            if (key_clear_press)
                sec_bcd <= 8'h00;
            case (state)
                S_BOOT: begin
                    if (wait_cnt == BOOT_WAIT - 1) begin
                        wait_cnt <= 21'd0;
                        if (FORCE_INIT) begin
                            sec_bcd  <= TIME_INIT[7:0];
                            min_bcd  <= TIME_INIT[15:8];
                            hour_bcd <= TIME_INIT[23:16];
                            day_bcd  <= TIME_INIT[31:24];
                            mon_bcd  <= TIME_INIT[39:32];
                            year_bcd <= TIME_INIT[47:40];
                            idx      <= 3'd0;
                            state    <= S_WRITE_START;
                        end
                        else begin
                            idx   <= 3'd0;
                            state <= S_READ_START;
                        end
                    end
                    else begin
                        wait_cnt <= wait_cnt + 1'b1;
                    end
                end

                S_WAIT: begin
                    if (save_req) begin
                        save_req   <= 1'b0;
                        idx        <= 3'd0;
                        state      <= S_WRITE_START;
                    end
                    else if ((set_mode == MODE_RUN) &&
                             (period_cnt == READ_PERIOD - 1)) begin
                        period_cnt <= 21'd0;
                        idx        <= 3'd0;
                        state      <= S_READ_START;
                    end
                    else begin
                        period_cnt <= period_cnt + 1'b1;
                    end
                end

                S_READ_START: begin
                    i2c_rh_wl  <= 1'b1;
                    i2c_addr   <= rd_addr;
                    i2c_data_w <= 8'h00;
                    i2c_exec   <= 1'b1;
                    state      <= S_READ_WAIT;
                end

                S_READ_WAIT: begin
                    if (i2c_done) begin
                        if (i2c_ack == 1'b0) begin
                            if (set_mode == MODE_RUN) begin
                                case (idx)
                                    3'd0: sec_bcd  <= {1'b0, i2c_data_r[6:0]};
                                    3'd1: min_bcd  <= {1'b0, i2c_data_r[6:0]};
                                    3'd2: hour_bcd <= {2'b0, i2c_data_r[5:0]};
                                    3'd3: day_bcd  <= {2'b0, i2c_data_r[5:0]};
                                    3'd4: mon_bcd  <= i2c_data_r;
                                    3'd5: year_bcd <= i2c_data_r;
                                    default: ;
                                endcase
                            end
                            rtc_ok <= 1'b1;
                        end
                        else begin
                            rtc_ok <= 1'b0;
                        end

                        if (idx == 3'd5) begin
                            idx        <= 3'd0;
                            period_cnt <= 21'd0;
                            state      <= S_WAIT;
                        end
                        else begin
                            idx   <= idx + 1'b1;
                            state <= S_READ_START;
                        end
                    end
                end

                S_WRITE_START: begin
                    i2c_rh_wl  <= 1'b0;
                    i2c_addr   <= wr_addr;
                    i2c_data_w <= wr_data;
                    i2c_exec   <= 1'b1;
                    state      <= S_WRITE_WAIT;
                end

                S_WRITE_WAIT: begin
                    if (i2c_done) begin
                        if (idx == 3'd5) begin
                            idx        <= 3'd0;
                            period_cnt <= 21'd0;
                            state      <= S_WAIT;
                        end
                        else begin
                            idx   <= idx + 1'b1;
                            state <= S_WRITE_START;
                        end
                    end
                end

                default: begin
                    idx   <= 3'd0;
                    state <= S_BOOT;
                end
            endcase
        end
    end

endmodule
