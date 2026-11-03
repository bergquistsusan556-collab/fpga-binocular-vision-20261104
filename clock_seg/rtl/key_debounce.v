module key_debounce #(
    parameter integer CNT_MAX = 500_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,
    output reg  key_level,
    output wire key_press
);

    reg [1:0]  key_sync;
    reg [18:0] cnt;
    reg        key_level_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync    <= 2'b11;
            key_level   <= 1'b1;
            key_level_d <= 1'b1;
            cnt         <= 19'd0;
        end
        else begin
            key_sync    <= {key_sync[0], key_in};
            key_level_d <= key_level;

            if (key_sync[1] == key_level)
                cnt <= 19'd0;
            else if (cnt == CNT_MAX - 1) begin
                cnt       <= 19'd0;
                key_level <= key_sync[1];
            end
            else
                cnt <= cnt + 1'b1;
        end
    end

    assign key_press = key_level_d & ~key_level;

endmodule
