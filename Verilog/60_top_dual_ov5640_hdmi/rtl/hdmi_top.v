//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：http://www.openedv.com/forum.php
//淘宝店铺：https://zhengdianyuanzi.tmall.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2023-2033
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           hdmi_top
// Created by:          正点原子
// Created date:        2025年10月28日13:09:00
// Version:             V1.0
// Descriptions:        HDMI顶层模块
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module  hdmi_top(
    input           pixel_clk,
    input           pixel_clk_5x,
    input           sys_rst_n,
    input   [2:0]   mode,
   //HDMI接口
    output          tmds_clk_p,      // TMDS时钟通道
    output          tmds_clk_n,
    output  [2:0]   tmds_data_p,     // TMDS数据通道
    output  [2:0]   tmds_data_n,
    output          tmds_oen ,       // TMDS输出使能
   //用户接口
    output          video_vs,        //HDMI场信号
    output  [10:0]  h_disp,          //HDMI屏水平分辨率
    output  [10:0]  v_disp,          //HDMI屏垂直分辨率
    input   [15:0]  data_in,         //数据输入
    output          data_req         //请求数据输入
);

//wire define
wire          pixel_clk;
wire          pixel_clk_5x;
wire          clk_locked;
wire  [2:0]   tmds_data_p;   // TMDS数据通道
wire  [2:0]   tmds_data_n;

wire  [10:0]  pixel_xpos_w;
wire  [10:0]  pixel_ypos_w;
wire  [23:0]  pixel_data_w;
wire  [10:0]  h_disp;
wire  [10:0]  v_disp;
wire          video_hs;
wire          video_vs;
wire          video_de;
wire  [23:0]  video_rgb;
wire  [15:0]  video_rgb_565;
wire  [15:0]  video_alg_rgb565;

//*****************************************************
//**                    main code
//*****************************************************

//将摄像头16bit数据转换为24bit的hdmi数据
assign video_rgb = {video_alg_rgb565[15:11],3'b000,video_alg_rgb565[10:5],2'b00,
                    video_alg_rgb565[4:0],3'b000};

//例化视频显示驱动模块
video_driver u_video_driver(
    .pixel_clk      (pixel_clk),
    .sys_rst_n      (sys_rst_n),

    .video_hs       (video_hs),
    .video_vs       (video_vs),
    .video_de       (video_de),
    .video_rgb      (),

    .data_req       (data_req),
    .h_disp         (h_disp),
    .v_disp         (v_disp), 
    .pixel_xpos     (pixel_xpos_w),
    .pixel_ypos     (pixel_ypos_w),
    .pixel_data     (data_in)
    );

 hdmi_disply u_hdmi_disply(
    .hdmi_clk         (pixel_clk),                 //模块驱动时钟
    .sys_rst_n        (sys_rst_n),                 //复位信号
    //HDMI接口
    .pixel_xpos       (pixel_xpos_w),              //像素点横坐标
    .pixel_ypos       (pixel_ypos_w),              //像素点纵坐标
    .rd_data          (data_in),                   //图像数据
    .rd_h_pixel       (h_disp),                    //图像水平像素大小
    .pixel_data       (video_rgb_565)              //像素点数据
);

video_alg_top u_video_alg_top(
    .clk              (pixel_clk),
    .rst_n            (sys_rst_n),
    .de               (video_de),
    .x                (pixel_xpos_w),
    .y                (pixel_ypos_w),
    .mode             (mode),
    .din              (video_rgb_565),
    .dout             (video_alg_rgb565)
);

//例化HDMI驱动模块
dvi_transmitter_top u_rgb2dvi_0(
    .pclk           (pixel_clk),
    .pclk_x5        (pixel_clk_5x),
    .reset_n        (sys_rst_n),

    .video_din      (video_rgb),
    .video_hsync    (video_hs), 
    .video_vsync    (video_vs),
    .video_de       (video_de),

    .tmds_clk_p     (tmds_clk_p),
    .tmds_clk_n     (tmds_clk_n),
    .tmds_data_p    (tmds_data_p),
    .tmds_data_n    (tmds_data_n),
    .tmds_oen       (tmds_oen)
    );

endmodule