//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�http://www.openedv.com/forum.php
//�Ա����̣�https://zhengdianyuanzi.tmall.com
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2023-2033
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           top_dual_ov5640_lcd
// Created by:          ����ԭ��
// Created date:        2025��10��25��10:25:00
// Version:             V1.0
// Descriptions:        ˫Ŀov5640����ͷlcd��ʾ
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module top_dual_ov5640_lcd(
    input                 sys_clk        ,  //ϵͳʱ��
    input                 sys_rst_n      ,  //ϵͳ��λ���͵�ƽ��Ч
    input   [3:0]         key            ,  //user keys, active low
    output  [3:0]         led            ,  //user LEDs
    //����ͷ1�ӿ�
    input                 cam_pclk_1     ,  //cmos ��������ʱ��
    input                 cam_vsync_1    ,  //cmos ��ͬ���ź�
    input                 cam_href_1     ,  //cmos ��ͬ���ź�
    input   [7:0]         cam_data_1     ,  //cmos ����
    output                cam_rst_n_1    ,  //cmos ��λ�źţ��͵�ƽ��Ч
    output                cam_pwdn_1 ,      //��Դ����ģʽѡ�� 0������ģʽ 1����Դ����ģʽ
    output                cam_scl_1      ,  //cmos SCCB_SCL��
    inout                 cam_sda_1      ,  //cmos SCCB_SDA��
    //����ͷ2�ӿ�
    input                 cam_pclk_2     ,  //cmos ��������ʱ��
    input                 cam_vsync_2    ,  //cmos ��ͬ���ź�
    input                 cam_href_2     ,  //cmos ��ͬ���ź�
    input   [7:0]         cam_data_2     ,  //cmos ����
    output                cam_rst_n_2    ,  //cmos ��λ�źţ��͵�ƽ��Ч
    output                cam_pwdn_2     ,  //��Դ����ģʽѡ�� 0������ģʽ 1����Դ����ģʽ
    output                cam_scl_2      ,  //cmos SCCB_SCL��
    inout                 cam_sda_2      ,  //cmos SCCB_SDA��

    //DDR3
    inout   [15:0]        ddr3_dq        ,  //DDR3 ����
    inout   [1:0]         ddr3_dqs_n     ,  //DDR3 dqs��
    inout   [1:0]         ddr3_dqs_p     ,  //DDR3 dqs��
    output  [13:0]        ddr3_addr      ,  //DDR3 ��ַ
    output  [2:0]         ddr3_ba        ,  //DDR3 bankѡ��
    output                ddr3_ras_n     ,  //DDR3 ��ѡ��
    output                ddr3_cas_n     ,  //DDR3 ��ѡ��
    output                ddr3_we_n      ,  //DDR3 ��дѡ��
    output                ddr3_reset_n   ,  //DDR3 ��λ
    output  [0:0]         ddr3_ck_p      ,  //DDR3 ʱ����
    output  [0:0]         ddr3_ck_n      ,  //DDR3 ʱ�Ӹ�
    output  [0:0]         ddr3_cke       ,  //DDR3 ʱ��ʹ��
    output  [0:0]         ddr3_cs_n      ,  //DDR3 Ƭѡ
    output  [1:0]         ddr3_dm        ,  //DDR3_dm
    output  [0:0]         ddr3_odt       ,  //DDR3_odt
    //LCD�ӿ�
    output                lcd_hs         ,  //LCD ��ͬ���ź�
    output                lcd_vs         ,  //LCD ��ͬ���ź�
    output                lcd_de         ,  //LCD ��������ʹ��
    inout       [23:0]    lcd_rgb        ,  //LCD ��ɫ����
    output                lcd_bl         ,  //LCD ��������ź�
    output                lcd_rst        ,  //LCD ��λ�ź�
    output                lcd_pclk          //LCD ����ʱ��
    );

//wire define
wire         clk_50m                   ;  //50MHzʱ��,�ṩ��lcd����ʱ��
wire         locked                    ;  //ʱ�������ź�
reg   [2:0]  mode_50m                  ;
wire         key0_press                ;
wire         key1_press                ;
wire         key2_press                ;
wire         key3_press                ;
reg   [8:0]  cal_scale                 ;
reg          filter_enable             ;
wire         rst_n                     ;  //ȫ�ָ�λ
wire         i2c_exec                  ;  //I2C����ִ���ź�
wire  [23:0] i2c_data                  ;  //I2CҪ���õĵ�ַ������(��8λ��ַ,��8λ����)
wire         cam_init_done             ;  //����ͷ��ʼ�����
wire         i2c_done                  ;  //I2C�Ĵ�����������ź�
wire         i2c_dri_clk               ;  //I2C����ʱ��
wire         wr_en                     ;  //DDR3������ģ��дʹ��
wire         rdata_req                 ;  //DDR3������ģ���ʹ��
wire  [15:0] rddata                    ;  //DDR3������ģ�������
wire         cmos_frame_valid_1        ;  //����1��Чʹ���ź�
wire  [15:0] wr_data_1                 ;  //DDR3������ģ��д����1
wire         cmos_frame_valid_2        ;  //����2��Чʹ���ź�
wire  [15:0] wr_data_2                 ;  //DDR3������ģ��д����2
wire         init_calib_complete       ;  //DDR3��ʼ�����init_calib_complete
wire         sys_init_done             ;  //ϵͳ��ʼ�����(DDR��ʼ��+����ͷ��ʼ��)
wire         clk_200m                  ;  //DDR3�ο�ʱ��
wire         cmos_frame_vsync_1        ;  //���֡1��Ч��ͬ���ź�
wire         cmos_frame_vsync_2        ;  //���֡2��Ч��ͬ���ź�
wire         rd_vsync;
wire [15:0] chip_id1,chip_id2;
wire [63:0] sensor_debug1,sensor_debug2;
wire cfg_done1,cfg_done2;
wire         lcd_de                    ;  //LCD��������ʹ��
wire         cmos_frame_href           ;  //���֡��Ч��ͬ���ź�
wire  [27:0] app_addr_rd_min           ;  //��DDR3����ʼ��ַ
wire  [27:0] app_addr_rd_max           ;  //��DDR3�Ľ�����ַ
wire  [7:0]  rd_bust_len               ;  //��DDR3�ж�����ʱ��ͻ������
wire  [27:0] app_addr_wr_min           ;  //дDDR3����ʼ��ַ
wire  [27:0] app_addr_wr_max           ;  //дDDR3�Ľ�����ַ
wire  [7:0]  wr_bust_len               ;  //��DDR3��д����ʱ��ͻ������
wire  [9:0]  pixel_xpos_w              ;  //���ص������
wire  [9:0]  pixel_ypos_w              ;  //���ص�������
wire         lcd_clk                   ;  //��Ƶ������LCD����ʱ��
wire  [12:0] h_disp                    ;  //LCD��ˮƽ�ֱ���
wire  [12:0] v_disp                    ;  //LCD����ֱ�ֱ���
wire  [12:0] y_addr_st                 ;  //������ֱ������ʼ��ַ
wire  [12:0] y_addr_end                ;  //������ֱ�����ֹ��ַ
wire  [15:0] lcd_id                    ;  //LCD����ID��
wire  [27:0] ddr3_addr_max             ;  //����DDR3������д��ַ
wire         i2c_rh_wl                 ;  //I2C��д�����ź�
wire  [7:0]  i2c_data_r                ;  //I2C������
wire  [12:0] total_h_pixel             ;  //ˮƽ�����ش�С
wire  [12:0] total_v_pixel             ;  //��ֱ�����ش�С

//*****************************************************
//**                    main code
//*****************************************************

//��ʱ�������������λ�����ź�
assign  rst_n = sys_rst_n & locked;

//ϵͳ��ʼ����ɣ�DDR3��ʼ�����
assign  sys_init_done = init_calib_complete;

// KEY0 cycles the LCD real-time processing mode. LED[2:0] shows the mode.
key_debounce #(.CNT_MAX(500_000)) u_key0_debounce (
    .clk        (clk_50m),
    .rst_n      (rst_n),
    .key_in     (key[0]),
    .key_level  (),
    .key_press  (key0_press)
);

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        mode_50m <= 3'd0;
    else if (key0_press)
        mode_50m <= {2'b0,~mode_50m[0]};
end

// Runtime stereo-distance calibration.
// KEY1 decreases the scale, KEY2 increases it.
// Default 256/256 is UNCALIBRATED. KEY3 reverses the disparity search direction.
key_debounce #(.CNT_MAX(500_000)) u_key1_debounce (
    .clk        (clk_50m),
    .rst_n      (rst_n),
    .key_in     (key[1]),
    .key_level  (),
    .key_press  (key1_press)
);

key_debounce #(.CNT_MAX(500_000)) u_key3_debounce (
    .clk        (clk_50m),
    .rst_n      (rst_n),
    .key_in     (key[3]),
    .key_level  (),
    .key_press  (key3_press)
);

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        filter_enable <= 1'b0;
    else if (key3_press)
        filter_enable <= ~filter_enable;
end

key_debounce #(.CNT_MAX(500_000)) u_key2_debounce (
    .clk        (clk_50m),
    .rst_n      (rst_n),
    .key_in     (key[2]),
    .key_level  (),
    .key_press  (key2_press)
);

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        cal_scale <= 9'd256;
    else begin
        if (key1_press && (cal_scale > 9'd8))
            cal_scale <= cal_scale - 9'd4;
        else if (key2_press && (cal_scale < 9'd508))
            cal_scale <= cal_scale + 9'd4;
    end
end

assign led[2:0] = mode_50m;
assign led[3]   = filter_enable;

//����ͷͼ��ֱ�������ģ��
picture_size u_picture_size (
    .rst_n              (rst_n),
    .clk                (clk_50m  ),
    .lcd_id             (lcd_id),           //LCD������ID
                        
    .cmos_h_pixel       (h_disp  ),         //����ͷˮƽ�ֱ���
    .cmos_v_pixel       (v_disp  ),         //����ͷ��ֱ�ֱ���
    .total_h_pixel      (total_h_pixel ),   //ˮƽ�����ش�С
    .total_v_pixel      (total_v_pixel ),   //��ֱ�����ش�С
    .y_addr_st          (y_addr_st ),
    .y_addr_end         (y_addr_end),
    .ddr3_addr_max      (ddr3_addr_max)     //DDR3����д��ַ
    );

//��һ·OV5640����ͷ����
ov5640_dri u_ov5640_dri_1(
    .clk               (clk_50m),
    .rst_n             (rst_n),

    .cam_pclk          (cam_pclk_1),
    .cam_vsync         (cam_vsync_1),
    .cam_href          (cam_href_1 ),
    .cam_data          (cam_data_1 ),
    .cam_rst_n         (cam_rst_n_1),
    .cam_pwdn          (cam_pwdn_1),
    .cam_scl           (cam_scl_1  ),
    .cam_sda           (cam_sda_1  ),
    
    .capture_start     (init_calib_complete),
    .cmos_h_pixel      (h_disp[12:1]),
    .cmos_v_pixel      (v_disp),
    .total_h_pixel     (total_h_pixel),
    .total_v_pixel     (total_v_pixel),
    .y_addr_st         (y_addr_st ), 
    .y_addr_end        (y_addr_end),
    .cmos_frame_vsync  (cmos_frame_vsync_1),
    .cam_init_done     (cfg_done1),
    .sensor_id         (chip_id1),
    .sensor_debug      (sensor_debug1),
    .cmos_frame_href   (),
    .cmos_frame_valid  (cmos_frame_valid_1),
    .cmos_frame_data   (wr_data_1)
    );

//�ڶ�·OV5640����ͷ����
ov5640_dri u_ov5640_dri_2(
    .clk               (clk_50m),
    .rst_n             (rst_n),

    .cam_pclk          (cam_pclk_2 ),
    .cam_vsync         (cam_vsync_2),
    .cam_href          (cam_href_2 ),
    .cam_data          (cam_data_2),
    .cam_rst_n         (cam_rst_n_2),
    .cam_pwdn          (cam_pwdn_2 ),
    .cam_scl           (cam_scl_2  ),
    .cam_sda           (cam_sda_2 ),

    .capture_start     (init_calib_complete),
    .cmos_h_pixel      (h_disp[12:1]),
    .cmos_v_pixel      (v_disp),
    .total_h_pixel     (total_h_pixel),
    .total_v_pixel     (total_v_pixel),
    .y_addr_st         (y_addr_st ),
    .y_addr_end        (y_addr_end),
    .cmos_frame_vsync  (cmos_frame_vsync_2),
    .cam_init_done     (cfg_done2),
    .sensor_id         (chip_id2),
    .sensor_debug      (sensor_debug2),
    .cmos_frame_href   (),
    .cmos_frame_valid  (cmos_frame_valid_2),
    .cmos_frame_data   (wr_data_2)
    );

//DDR3��д����ģ��
ddr3_top u_ddr3_top (
    .rst_n                 (rst_n),                 //��λ,����Ч
    .init_calib_complete   (init_calib_complete),   //DDR3��ʼ������ź�
    //DDR3�ӿ��ź�
    .app_addr_rd_min       (28'd0),                 //��DDR3����ʼ��ַ
    .app_addr_rd_max       (ddr3_addr_max[27:1]),   //��DDR3�Ľ�����ַ
    .rd_bust_len           (h_disp[10:3]),          //��DDR3�ж�����ʱ��ͻ������
    .app_addr_wr_min       (28'd0),                 //дDDR3����ʼ��ַ
    .app_addr_wr_max       (ddr3_addr_max[27:1]),   //дDDR3�Ľ�����ַ
    .wr_bust_len           (h_disp[10:3]),          //��DDR3��д����ʱ��ͻ������
    //DDR3 IO�ӿ�
    .ddr3_dq               (ddr3_dq),               //DDR3 ����
    .ddr3_dqs_n            (ddr3_dqs_n),            //DDR3 dqs��
    .ddr3_dqs_p            (ddr3_dqs_p),            //DDR3 dqs��
    .ddr3_addr             (ddr3_addr),             //DDR3 ��ַ
    .ddr3_ba               (ddr3_ba),               //DDR3 bankѡ��
    .ddr3_ras_n            (ddr3_ras_n),            //DDR3 ��ѡ��
    .ddr3_cas_n            (ddr3_cas_n),            //DDR3 ��ѡ��
    .ddr3_we_n             (ddr3_we_n),             //DDR3 ��дѡ��
    .ddr3_reset_n          (ddr3_reset_n),          //DDR3 ��λ
    .ddr3_ck_p             (ddr3_ck_p),             //DDR3 ʱ����
    .ddr3_ck_n             (ddr3_ck_n),             //DDR3 ʱ�Ӹ�
    .ddr3_cke              (ddr3_cke),              //DDR3 ʱ��ʹ��
    .ddr3_cs_n             (ddr3_cs_n),             //DDR3 Ƭѡ
    .ddr3_dm               (ddr3_dm),               //DDR3_dm
    .ddr3_odt              (ddr3_odt),              //DDR3_odt
    // System Clock Ports
    .sys_clk_i             (clk_200m),
    // Reference Clock Ports
    .clk_ref_i             (clk_200m),
    //�û��ӿ�
    .ddr3_read_valid       (1'b1),                  //DDR3��ʹ��
    .ddr3_pingpang_en      (1'b1),                  //DDR3ƹ�Ҳ���ʹ��
    .wr_clk_1              (cam_pclk_1),            //����ͷ1ʱ��
    .wr_load_1             (cmos_frame_vsync_1),    //����ͷ1���ź�
    .wr_en_1               (cmos_frame_valid_1),    //����1��Чʹ���ź�
    .wrdata_1              (wr_data_1),             //��Ч����1
    .wr_clk_2              (cam_pclk_2),            //����ͷ2ʱ��
    .wr_load_2             (cmos_frame_vsync_2),    //����ͷ2���ź�
    .wr_en_2               (cmos_frame_valid_2),    //������Чʹ���ź�
    .wrdata_2              (wr_data_2),             //��Ч����

    .h_disp                (h_disp),
    .rd_clk                (lcd_clk),               //rfifo�Ķ�ʱ��
    .rd_load               (rd_vsync),              //lcd���ź�
    .rddata                (rddata),                //rfifo�������
    .rdata_req             (rdata_req)              //������������
    );

//����ʱ��IP��
clk_wiz_0 u_clk_wiz_0(
    // Clock out ports
    .clk_out1              (clk_200m),
    .clk_out2              (clk_50m),
    // Status and control signals
    .reset                 (1'b0),
    .locked                (locked),
   // Clock in ports
    .clk_in1               (sys_clk)
    );

//LCD������ʾģ��
lcd_rgb_top  u_lcd_rgb_top(
    .sys_clk               (clk_50m  ),
    .sys_rst_n             (rst_n ),
    .sys_init_done         (sys_init_done),
    .mode_in              (mode_50m),
    .cal_scale             (cal_scale),
    .filter_enable         (filter_enable),
    .activity1             (fg1_s2),
    .activity2             (fg2_s2),
    .heartbeat             (diag_ticks[23]),

    //LCD�ӿ�
    .lcd_id                (lcd_id),                //LCD����ID��
    .lcd_hs                (lcd_hs),                //LCD��ͬ���ź�
    .lcd_vs                (lcd_vs),                //LCD��ͬ���ź�
    .lcd_de                (lcd_de),                //LCD��������ʹ��
    .lcd_rgb               (lcd_rgb),               //LCD��ɫ����
    .lcd_bl                (lcd_bl),                //LCD��������ź�
    .lcd_rst               (lcd_rst),               //LCD��λ�ź�
    .lcd_pclk              (lcd_pclk),              //LCD����ʱ��
    .lcd_clk               (lcd_clk),               //LCD����ʱ��
    //�û��ӿ�
    .out_vsync             (rd_vsync),              //LCD���ź�
    .h_disp                (),                      //�зֱ���
    .v_disp                (),                      //���ֱ���
    .pixel_xpos            (),
    .pixel_ypos            (),
    .data_in               (rddata),                //rfifo�������
    .data_req              (rdata_req)              //������������
    );

wire [7:0] fg1,fg2;
wire [15:0] cg1,cg2,fh1,fh2;
wire [19:0] fp1,fp2;
camera_activity u_activity1(cam_pclk_1,rst_n,cam_vsync_1,cmos_frame_valid_1,wr_data_1,fg1,cg1,fp1,fh1);
camera_activity u_activity2(cam_pclk_2,rst_n,cam_vsync_2,cmos_frame_valid_2,wr_data_2,fg2,cg2,fp2,fh2);
(* ASYNC_REG="TRUE" *) reg [7:0] fg1_s1,fg1_s2,fg2_s1,fg2_s2;
(* ASYNC_REG="TRUE" *) reg [15:0] cg1_s1,cg1_s2,cg2_s1,cg2_s2;
(* ASYNC_REG="TRUE" *) reg [5:0] cam_io_s1,cam_io_s2;
reg [31:0] diag_ticks;
reg [15:0] read_hash;
always @(posedge clk_50m or negedge rst_n) begin
 if(!rst_n)begin
  fg1_s1<=0;fg1_s2<=0;fg2_s1<=0;fg2_s2<=0;
  cg1_s1<=0;cg1_s2<=0;cg2_s1<=0;cg2_s2<=0;
  cam_io_s1<=0;cam_io_s2<=0;diag_ticks<=0;
 end else begin
  fg1_s1<=fg1;fg1_s2<=fg1_s1;fg2_s1<=fg2;fg2_s2<=fg2_s1;
  cg1_s1<=cg1;cg1_s2<=cg1_s1;cg2_s1<=cg2;cg2_s2<=cg2_s1;
  cam_io_s1<={cam_href_2,cam_href_1,cam_vsync_2,cam_vsync_1,cfg_done2,cfg_done1};
  cam_io_s2<=cam_io_s1;diag_ticks<=diag_ticks+1'b1;
 end
end
always @(posedge lcd_clk or negedge rst_n)
 if(!rst_n)read_hash<=0;
 else if(rd_vsync)read_hash<=0;
 else if(rdata_req)read_hash<={read_hash[14:0],read_hash[15]}^rddata;
(* MARK_DEBUG="TRUE",KEEP="TRUE" *) wire [383:0] diagnostic_bus;
assign diagnostic_bus={sensor_debug2,sensor_debug1,13'd0,u_ddr3_top.u_ddr3_rw.app_addr,
 u_ddr3_top.u_ddr3_rw.state_cnt,diag_ticks[31:16],read_hash,fh2,fh1,fp2,fp1,
 cg2_s2,cg1_s2,fg2_s2,fg1_s2,lcd_id,chip_id2,chip_id1,
 cam_io_s2[5:2],rst_n,cam_io_s2[1:0],init_calib_complete};

endmodule

