//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�http://www.openedv.com/forum.php
//�Ա����̣�https://zhengdianyuanzi.tmall.com
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2023-2033
//All rights reserved  
//----------------------------------------------------------------------------------------
// File name:           lcd_rgb_top
// Created by:          ����ԭ��
// Created date:        2025��12��04��14:20:02
// Version:             V1.0
// Descriptions:        LCD����ģ��
//                      
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module lcd_rgb_top(
    input           sys_clk      ,  //ϵͳʱ��
    input           sys_rst_n,      //��λ�ź�
    input           sys_init_done,
    input   [2:0]   mode_in,
    input   [8:0]   cal_scale,
    input           filter_enable,
    //LCD�ӿ�
    output          lcd_clk,        //LCD����ʱ��
    output          lcd_hs,         //LCD��ͬ���ź�
    output          lcd_vs,         //LCD��ͬ���ź�
    output          lcd_de,         //LCD��������ʹ��
    inout  [23:0]   lcd_rgb,        //LCDRGB��ɫ����
    output          lcd_bl,         //LCD��������ź�
    output          lcd_rst,        //LCD��λ�ź�
    output          lcd_pclk,       //LCD����ʱ��
    output  [15:0]  lcd_id,         //LCD��ID
    output          out_vsync,      //LCD���ź�
    output  [10:0]  pixel_xpos,     //���ص������
    output  [10:0]  pixel_ypos,     //���ص�������
    output  [10:0]  h_disp,         //LCD��ˮƽ�ֱ���
    output  [10:0]  v_disp,         //LCD����ֱ�ֱ���
    input   [15:0]  data_in,        //��������
    output          data_req        //�������ص���ɫ��������
    );

//wire define
wire [15:0]  lcd_rgb_565;
wire [15:0]  lcd_alg_rgb565;
(* ASYNC_REG = "TRUE" *) reg [2:0] mode_sync1;
(* ASYNC_REG = "TRUE" *) reg [2:0] mode_sync2;
(* ASYNC_REG = "TRUE" *) reg [8:0] cal_scale_sync1, cal_scale_sync2;
(* ASYNC_REG = "TRUE" *) reg filter_enable_sync1, filter_enable_sync2;
wire [23:0]  lcd_rgb_o ;            //LCD�����ɫ����
wire [23:0]  lcd_rgb_i ;            //LCD������ɫ����

//*****************************************************
//**                    main code                      
//*****************************************************

always @(posedge lcd_clk) begin
    if (!(sys_rst_n & sys_init_done)) begin
        mode_sync1 <= 3'd0;
        mode_sync2 <= 3'd0;
        cal_scale_sync1 <= 9'd212;
        cal_scale_sync2 <= 9'd212;
        filter_enable_sync1 <= 1'b1;
        filter_enable_sync2 <= 1'b1;
    end
    else begin
        mode_sync1 <= mode_in;
        mode_sync2 <= mode_sync1;
        cal_scale_sync1 <= cal_scale;
        cal_scale_sync2 <= cal_scale_sync1;
        filter_enable_sync1 <= filter_enable;
        filter_enable_sync2 <= filter_enable_sync1;
    end
end


//������ͷ16bit����ת��Ϊ24bit��LCD����
assign lcd_rgb_o = {lcd_alg_rgb565[15:11],3'b000,lcd_alg_rgb565[10:5],2'b00,
                    lcd_alg_rgb565[4:0],3'b000};

//�������ݷ����л�
assign lcd_rgb = lcd_de ?  lcd_rgb_o :  {24{1'bz}};
assign lcd_rgb_i = lcd_rgb;

//*****************************************************
//**                    main code
//*****************************************************

//ʱ�ӷ�Ƶģ��
clk_div u_clk_div(
    .clk                    (sys_clk  ),
    .rst_n                  (sys_rst_n),
    .lcd_id                 (lcd_id   ),
    .lcd_pclk               (lcd_clk  )
    );

//��LCD IDģ��
rd_id u_rd_id(
    .clk                    (sys_clk  ),
    .rst_n                  (sys_rst_n),
    .lcd_rgb                (lcd_rgb_i),
    .lcd_id                 (lcd_id   )
    );

//lcd����ģ��
lcd_driver u_lcd_driver(
    .lcd_clk        (lcd_clk),
    .rst_n          (sys_rst_n & sys_init_done),
    .lcd_id         (lcd_id),

    .lcd_hs         (lcd_hs),
    .lcd_vs         (lcd_vs),
    .lcd_de         (lcd_de),
    .lcd_rgb        (),
    .lcd_bl         (lcd_bl),
    .lcd_rst        (lcd_rst),
    .lcd_pclk       (lcd_pclk),

    .pixel_data     (data_in),
    .data_req       (data_req),
    .out_vsync      (out_vsync),
    .h_disp         (h_disp),
    .v_disp         (v_disp),
    .pixel_xpos     (pixel_xpos),
    .pixel_ypos     (pixel_ypos)
    );

//LCD��ʾģ��
 lcd_disply u_lcd_disply(
    .lcd_clk          (lcd_clk),                   //LCDģ������ʱ��
    .sys_rst_n        (sys_rst_n & sys_init_done), //��λ�ź�
    //RGB LCD�ӿ�
    .pixel_xpos       (pixel_xpos),                //���ص������
    .pixel_ypos       (pixel_ypos),                //���ص�������
    .rd_data          (data_in),                   //ͼ������
    .rd_h_pixel       (h_disp),                    //ͼ��ˮƽ���ش�С
    .pixel_data       (lcd_rgb_565)                //���ص�����
);

video_alg_top u_video_alg_top(
    .clk              (lcd_clk),
    .rst_n            (sys_rst_n & sys_init_done),
    .de               (lcd_de),
    .x                (pixel_xpos),
    .y                (pixel_ypos),
    .h_disp           (h_disp),
    .v_disp           (v_disp),
    .mode             (mode_sync2),
    .cal_scale        (cal_scale_sync2),
    .filter_enable    (filter_enable_sync2),
    .din              (lcd_rgb_565),
    .dout             (lcd_alg_rgb565)
);

endmodule
