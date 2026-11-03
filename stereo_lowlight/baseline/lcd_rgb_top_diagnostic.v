`timescale 1ns/1ps
// Bring-up display: raw DDR image or independent colour bars (KEY0).
// Bottom strips show camera frame activity; white marker is LCD heartbeat.
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
 output wire data_req
);
 wire [23:0] bus_in=lcd_rgb;
 wire req;
 reg [15:0] raw;
 reg [15:0] color;
 (* ASYNC_REG="TRUE" *) reg mode_s1,mode_s2;
 (* ASYNC_REG="TRUE" *) reg [7:0] act1_s1,act1_s2,act2_s1,act2_s2;
 (* ASYNC_REG="TRUE" *) reg beat_s1,beat_s2;
 clk_div divider(sys_clk,sys_rst_n,lcd_id,lcd_clk);
 rd_id id_reader(sys_clk,sys_rst_n,bus_in,lcd_id);
 lcd_driver driver(
  .lcd_clk(lcd_clk),.rst_n(sys_rst_n),.lcd_id(lcd_id),.pixel_data(data_in),
  .data_req(req),.pixel_xpos(pixel_xpos),.pixel_ypos(pixel_ypos),
  .h_disp(h_disp),.v_disp(v_disp),.out_vsync(out_vsync),
  .lcd_hs(lcd_hs),.lcd_vs(lcd_vs),.lcd_de(lcd_de),.lcd_rgb(),
  .lcd_bl(lcd_bl),.lcd_rst(lcd_rst),.lcd_pclk(lcd_pclk)
 );
 assign data_req=req&&sys_init_done;
 always @(posedge lcd_clk or negedge sys_rst_n)begin
  if(!sys_rst_n)begin
   raw<=0;mode_s1<=0;mode_s2<=0;act1_s1<=0;act1_s2<=0;act2_s1<=0;act2_s2<=0;beat_s1<=0;beat_s2<=0;
  end else begin
   raw<=data_in;mode_s1<=mode_in[0];mode_s2<=mode_s1;
   act1_s1<=activity1;act1_s2<=act1_s1;act2_s1<=activity2;act2_s2<=act2_s1;
   beat_s1<=heartbeat;beat_s2<=beat_s1;
  end
 end
 always @* begin
  color=raw;
  if(mode_s2||!sys_init_done)begin
   case(pixel_xpos[9:6])
    0:color=16'hffff;1:color=16'hffe0;2:color=16'h07ff;3:color=16'h07e0;
    4:color=16'hf81f;5:color=16'hf800;6:color=16'h001f;default:color=16'h8410;
   endcase
  end
  if(pixel_ypos>=v_disp-8)begin
   if(pixel_xpos<(h_disp>>1))color=act1_s2[2]?16'h07e0:16'h001f;
   else color=act2_s2[2]?16'hffe0:16'hf800;
   if(pixel_xpos<16&&beat_s2)color=16'hffff;
  end
 end
 assign lcd_rgb=lcd_de?{color[15:11],3'b0,color[10:5],2'b0,color[4:0],3'b0}:24'bz;
endmodule
