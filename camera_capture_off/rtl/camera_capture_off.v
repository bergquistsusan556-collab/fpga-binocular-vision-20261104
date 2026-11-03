module camera_capture_off(
    output wire cam_pwdn_1,
    output wire cam_rst_n_1,
    output wire cam_scl_1,
    output wire cam_pwdn_2,
    output wire cam_rst_n_2,
    output wire cam_scl_2
);

// OV5640 PWDN is active-high; RST_N is active-low.
assign cam_pwdn_1 = 1'b1;
assign cam_rst_n_1 = 1'b0;
assign cam_scl_1  = 1'b1;

assign cam_pwdn_2 = 1'b1;
assign cam_rst_n_2 = 1'b0;
assign cam_scl_2  = 1'b1;

endmodule