`timescale 1ns/1ps
// Fetch coordinates are counted from DDR requests, independent of the legacy
// driver's one-based y coordinate. Pixel, coordinate and DE travel together.
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
 wire [23:0] bus_in=lcd_rgb;
 wire req;
 lcd_clock_800 divider(sys_clk,sys_rst_n,lcd_clk);
 rd_id id_reader(sys_clk,sys_rst_n,bus_in,lcd_id);
 lcd_driver driver(
  .lcd_clk(lcd_clk),.rst_n(sys_rst_n),.lcd_id(lcd_id),.pixel_data(data_in),
  .data_req(req),.pixel_xpos(),.pixel_ypos(),
  .h_disp(h_disp),.v_disp(v_disp),.out_vsync(out_vsync),
  .lcd_hs(lcd_hs),.lcd_vs(lcd_vs),.lcd_de(),.lcd_rgb(),
  .lcd_bl(lcd_bl),.lcd_rst(lcd_rst),.lcd_pclk(lcd_pclk)
 );
 assign data_req=req&&sys_init_done;
 (* ASYNC_REG="TRUE" *) reg [2:0] ms1,ms2;
 (* ASYNC_REG="TRUE" *) reg [8:0] ss1,ss2;
 (* ASYNC_REG="TRUE" *) reg rs1,rs2,is1,is2;
 reg vs_d,req_d;
 reg [2:0] frame_mode;
 reg frame_reverse;
 reg [8:0] frame_scale;
 (* ASYNC_REG="TRUE" *) reg [15:0] cs1,cs2;
 reg [15:0] frame_control;
 reg [10:0] count_x,count_y,fetch_x,fetch_y;
 wire sof=out_vsync&&!vs_d;
 always @(posedge lcd_clk or negedge sys_rst_n)begin
  if(!sys_rst_n)begin
   ms1<=0;ms2<=0;ss1<=256;ss2<=256;rs1<=0;rs2<=0;is1<=0;is2<=0;
   vs_d<=0;req_d<=0;count_x<=0;count_y<=0;fetch_x<=0;fetch_y<=0;
   frame_mode<=0;frame_reverse<=0;frame_scale<=256;
   cs1<=0;cs2<=0;frame_control<=0;
  end else begin
   ms1<=mode_in;ms2<=ms1;ss1<=cal_scale;ss2<=ss1;
   cs1<=diagnostic_control;cs2<=cs1;
   rs1<=filter_enable;rs2<=rs1;is1<=sys_init_done;is2<=is1;
   vs_d<=out_vsync;req_d<=data_req;
   if(sof)begin
    count_x<=0;count_y<=0;
    frame_mode<=is2?ms2:3;frame_reverse<=rs2^cs2[6];frame_scale<=ss2;frame_control<=cs2;
   end else if(data_req)begin
    fetch_x<=count_x;fetch_y<=count_y;
    if(count_x==h_disp-1)begin count_x<=0;count_y<=count_y+1'b1;end
    else count_x<=count_x+1'b1;
   end
  end
 end
 wire [15:0] processed,distance;
 wire [63:0] roi_diagnostic;
 wire distance_valid,match_de,match_valid;wire [5:0] dominant,match_disp;
 fusion_pipeline pipeline(lcd_clk,sys_rst_n,sof,req_d,fetch_x,fetch_y,h_disp,v_disp,
  data_in,frame_mode,frame_reverse,frame_scale,lcd_de,pixel_xpos,pixel_ypos,processed,
  distance,distance_valid,dominant,match_de,match_valid,match_disp,diagnostic_metrics,roi_diagnostic,frame_control[7:0]);
 assign diagnostic_extra[63:0]={3'd0,frame_reverse,roi_diagnostic[59:0]};
 stereo_observer observer(lcd_clk,sys_clk,sys_rst_n,req_d,fetch_x,fetch_y,data_in,frame_control[13:8],diagnostic_extra[95:64],sof,frame_control[14]);
 assign diagnostic_status={frame_mode[1:0],distance_valid,distance,dominant};
 assign lcd_rgb=lcd_de?{processed[15:11],3'b0,processed[10:5],2'b0,processed[4:0],3'b0}:24'bz;
endmodule
