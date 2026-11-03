`timescale 1ns/1ps
// Temporary raw-video acquisition profile. Production fusion RTL is untouched.
module lcd_rgb_top(
 input wire sys_clk,sys_rst_n,sys_init_done,
 input wire [2:0] mode_in,
 input wire [8:0] cal_scale,
 input wire filter_enable,
 input wire [7:0] activity1,activity2,
 input wire heartbeat,
 output wire lcd_clk,lcd_hs,lcd_vs,lcd_de,
 inout wire [23:0] lcd_rgb,
 output wire lcd_bl,lcd_rst,lcd_pclk,
 output wire [15:0] lcd_id,
 output wire out_vsync,
 output wire [10:0] pixel_xpos,pixel_ypos,h_disp,v_disp,
 input wire [15:0] data_in,
 output wire data_req,
 output wire [95:0] diagnostic_metrics,
 output wire [24:0] diagnostic_status,
 output wire [95:0] diagnostic_extra,
 input wire [15:0] diagnostic_control
);
 wire req;
 lcd_clock_800 divider(sys_clk,sys_rst_n,lcd_clk);
 rd_id id_reader(sys_clk,sys_rst_n,lcd_rgb,lcd_id);
 lcd_driver driver(
  .lcd_clk(lcd_clk),.rst_n(sys_rst_n),.lcd_id(lcd_id),.pixel_data(data_in),
  .data_req(req),.pixel_xpos(),.pixel_ypos(),.h_disp(h_disp),.v_disp(v_disp),
  .out_vsync(out_vsync),.lcd_hs(lcd_hs),.lcd_vs(lcd_vs),.lcd_de(),.lcd_rgb(),
  .lcd_bl(lcd_bl),.lcd_rst(lcd_rst),.lcd_pclk(lcd_pclk)
 );
 assign data_req=req&&sys_init_done;
 (* ASYNC_REG="TRUE" *) reg [15:0] cs1,cs2;
 reg vs_d,req_d,out_de;
 reg [10:0] count_x,count_y,fetch_x,fetch_y,out_x,out_y;
 reg [15:0] out_rgb;
 wire sof=out_vsync&&!vs_d;
 always @(posedge lcd_clk or negedge sys_rst_n)begin
  if(!sys_rst_n)begin
   cs1<=0;cs2<=0;vs_d<=0;req_d<=0;out_de<=0;
   count_x<=0;count_y<=0;fetch_x<=0;fetch_y<=0;out_x<=0;out_y<=0;out_rgb<=0;
  end else begin
   cs1<=diagnostic_control;cs2<=cs1;
   vs_d<=out_vsync;req_d<=data_req;
   out_de<=req_d;out_x<=fetch_x;out_y<=fetch_y;out_rgb<=data_in;
   if(sof)begin count_x<=0;count_y<=0;end
   else if(data_req)begin
    fetch_x<=count_x;fetch_y<=count_y;
    if(count_x==h_disp-1)begin count_x<=0;count_y<=count_y+1'b1;end
    else count_x<=count_x+1'b1;
   end
  end
 end
 calibration_capture capture(lcd_clk,sys_clk,sys_rst_n,sof,req_d,fetch_x,fetch_y,
  data_in,cs2,diagnostic_extra[95:64]);
 assign diagnostic_extra[63:0]=0;
 assign diagnostic_metrics=0;
 assign diagnostic_status=0;
 assign lcd_de=out_de;
 assign pixel_xpos=out_x;
 assign pixel_ypos=out_y;
 assign lcd_rgb=out_de?{out_rgb[15:11],3'b0,out_rgb[10:5],2'b0,out_rgb[4:0],3'b0}:24'bz;
endmodule
