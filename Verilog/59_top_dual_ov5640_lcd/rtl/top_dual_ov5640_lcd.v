//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�http://www.openedv.com/forum.php
//�Ա����̣�https://zhengdianyuanzi.tmall.com
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���?
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
    output                lcd_bl         ,  //LCD ��������ź�?
    output                lcd_rst        ,  //LCD ��λ�ź�
    output                lcd_pclk          //LCD ����ʱ��
    );

//wire define
wire         clk_50m                   ;  //50MHzʱ��,�ṩ��lcd����ʱ��
wire         locked                    ;  //ʱ�������ź�
reg   [2:0]  mode_50m                  ;
wire         key1_press                ;
wire         key2_press                ;
wire         key3_press                ;
reg   [8:0]  cal_scale                 ;
reg          filter_enable             ;
reg   [7:0]  thr_low                   ;
reg   [7:0]  thr_high                  ;
reg          follow_enable             ;
wire         key0_level                ;
reg          key0_level_d              ;
reg   [26:0] key0_hold                 ;
wire         key0_short                ;
wire         key0_long                 ;
wire         key0_release              ;
reg          adj_mode                  ;
reg   [1:0]  adj_sel                   ;
reg   [23:0] blink_cnt                 ;
wire         blink                     ;
wire         rst_n                     ;  //ȫ�ָ�λ
wire         i2c_exec                  ;  //I2C����ִ���ź�
wire  [23:0] i2c_data                  ;  //I2CҪ���õĵ�ַ������(��8λ��ַ,��8λ����)
wire         cam_init_done             ;  //����ͷ��ʼ�����?
wire         i2c_done                  ;  //I2C�Ĵ�����������ź�?
wire         i2c_dri_clk               ;  //I2C����ʱ��
wire         wr_en                     ;  //DDR3������ģ��дʹ��
wire         rdata_req                 ;  //DDR3������ģ���ʹ��?
wire  [15:0] rddata                    ;  //DDR3������ģ�������?
wire         cmos_frame_valid_1        ;  //����1��Чʹ���ź�
wire  [15:0] wr_data_1                 ;  //DDR3������ģ��д����1
wire         cmos_frame_valid_2        ;  //����2��Чʹ���ź�
wire  [15:0] wr_data_2                 ;  //DDR3������ģ��д����2
(* MARK_DEBUG = "TRUE" *) wire init_calib_complete;
wire         sys_init_done             ;  //ϵͳ��ʼ�����?DDR��ʼ��+����ͷ��ʼ��)
wire         clk_200m                  ;  //DDR3�ο�ʱ��
wire         cmos_frame_vsync_1        ;  //����?��Ч��ͬ���ź�
wire         cmos_frame_vsync_2        ;  //����?��Ч��ͬ���ź�
wire         rd_vsync                  ;  //LCD vsync
wire         cmos_frame_href_1         ;
wire         cmos_frame_href_2         ;
wire  [27:0] app_addr_rd_min           ;  //��DDR3����ʼ��ַ
wire  [27:0] app_addr_rd_max           ;  //��DDR3�Ľ�����ַ
wire  [7:0]  rd_bust_len               ;  //��DDR3�ж�����ʱ��ͻ������
wire  [27:0] app_addr_wr_min           ;  //дDDR3����ʼ��ַ
wire  [27:0] app_addr_wr_max           ;  //дDDR3�Ľ�����ַ
wire  [7:0]  wr_bust_len               ;  //��DDR3��д����ʱ��ͻ������
wire  [9:0]  pixel_xpos_w              ;  //���ص������?
wire  [9:0]  pixel_ypos_w              ;  //���ص�������
wire         lcd_clk                   ;  //��Ƶ������LCD����ʱ��
wire  [12:0] h_disp                    ;  //LCD��ˮƽ�ֱ���
wire  [12:0] v_disp                    ;  //LCD����ֱ�ֱ���
wire  [12:0] y_addr_st                 ;  //������ֱ������ʼ��ַ
wire  [12:0] y_addr_end                ;  //������ֱ�����ֹ���?
wire  [15:0] lcd_id                    ;  //LCD����ID��
wire  [27:0] ddr3_addr_max             ;  //����DDR3������д��ַ
wire         i2c_rh_wl                 ;  //I2C��д�����ź�
wire  [7:0]  i2c_data_r                ;  //I2C������
wire  [12:0] total_h_pixel             ;  //ˮƽ�����ش�С
wire  [12:0] total_v_pixel             ;  //��ֱ�����ش�С

wire        ws_l_meta_valid           ;
wire        ws_l_meta_we              ;
wire        ws_l_wr_page              ;
wire [10:0] ws_l_meta_cx              ;
wire [10:0] ws_l_meta_cy              ;
wire        ws_r_meta_valid           ;
wire        ws_r_meta_we              ;
wire        ws_r_wr_page              ;
wire [10:0] ws_r_meta_cx              ;
wire [10:0] ws_r_meta_cy              ;
wire [22:0] ws_l_meta_rd             ;
wire [22:0] ws_r_meta_rd             ;
wire        ws_l_meta_valid_rd        ;
wire        ws_r_meta_valid_rd        ;
wire [10:0] ws_l_meta_cx_rd           ;
wire [10:0] ws_l_meta_cy_rd           ;
wire [10:0] ws_r_meta_cx_rd           ;
wire [10:0] ws_r_meta_cy_rd           ;
(* ASYNC_REG = "TRUE" *) reg ws_l_page_sync1;
(* ASYNC_REG = "TRUE" *) reg ws_l_page_sync2;
(* ASYNC_REG = "TRUE" *) reg ws_r_page_sync1;
(* ASYNC_REG = "TRUE" *) reg ws_r_page_sync2;
reg         ws_l_rd_page              ;
reg         ws_r_rd_page              ;
reg         rd_vsync_d                ;

assign ws_l_meta_valid_rd = ws_l_meta_rd[22];
assign ws_l_meta_cx_rd = ws_l_meta_rd[21:11];
assign ws_l_meta_cy_rd = ws_l_meta_rd[10:0];
assign ws_r_meta_valid_rd = ws_r_meta_rd[22];
assign ws_r_meta_cx_rd = ws_r_meta_rd[21:11];
assign ws_r_meta_cy_rd = ws_r_meta_rd[10:0];

//*****************************************************
//**                    main code
//*****************************************************

//��ʱ�������������λ�����ź�?
assign  rst_n = sys_rst_n & locked;

//ϵͳ��ʼ����ɣ�DDR3��ʼ�����?
assign  sys_init_done = init_calib_complete;

//--------------------------------------------------------------------------
// Key handling
//   KEY0 short : cycle the 8 display modes              (LED[2:0] = mode)
//   KEY0 long  : enter / leave parameter-adjust mode    (LED[3] blinks)
//   KEY3 short : toggle the red-target follow overlay   (LED[3], normal mode)
//                OR cycle the selected parameter        (adjust mode)
//   KEY1/KEY2  : decrease / increase the selected parameter; outside adjust
//                mode they still trim the stereo distance scale.
//
//   Adjust-mode parameters: 0 = low threshold, 1 = high threshold,
//                           2 = distance scale, 3 = distance filter
//--------------------------------------------------------------------------
key_debounce #(.CNT_MAX(500_000)) u_key0_debounce (
    .clk        (clk_50m),
    .rst_n      (rst_n),
    .key_in     (key[0]),
    .key_level  (key0_level),
    .key_press  ()
);

key_debounce #(.CNT_MAX(500_000)) u_key1_debounce (
    .clk        (clk_50m),
    .rst_n      (rst_n),
    .key_in     (key[1]),
    .key_level  (),
    .key_press  (key1_press)
);

key_debounce #(.CNT_MAX(500_000)) u_key2_debounce (
    .clk        (clk_50m),
    .rst_n      (rst_n),
    .key_in     (key[2]),
    .key_level  (),
    .key_press  (key2_press)
);

key_debounce #(.CNT_MAX(500_000)) u_key3_debounce (
    .clk        (clk_50m),
    .rst_n      (rst_n),
    .key_in     (key[3]),
    .key_level  (),
    .key_press  (key3_press)
);

// KEY0 acts on RELEASE, so a long press is not also counted as a short one.
localparam [26:0] KEY0_LONG = 27'd75_000_000;   // 1.5 s at 50 MHz

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        key0_level_d <= 1'b1;
        key0_hold    <= 27'd0;
    end
    else begin
        key0_level_d <= key0_level;
        if (!key0_level) begin
            if (key0_hold != KEY0_LONG)
                key0_hold <= key0_hold + 1'b1;
        end
        else
            key0_hold <= 27'd0;
    end
end

assign key0_release = key0_level & ~key0_level_d;
assign key0_long    = key0_release && (key0_hold >= KEY0_LONG);
assign key0_short   = key0_release && (key0_hold <  KEY0_LONG);

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        mode_50m <= 3'd0;
    else if (key0_short)
        mode_50m <= mode_50m + 1'b1;
end

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        adj_mode <= 1'b0;
    else if (key0_long)
        adj_mode <= ~adj_mode;
end

// KEY3 selects the parameter inside adjust mode, and toggles the red-target
// follow overlay outside it.
always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        adj_sel <= 2'd0;
    else if (key3_press && adj_mode)
        adj_sel <= adj_sel + 1'b1;
end

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        follow_enable <= 1'b0;
    else if (key3_press && !adj_mode)
        follow_enable <= ~follow_enable;
end

// ~1.5 Hz blink used to show that adjust mode is active.
always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        blink_cnt <= 24'd0;
    else
        blink_cnt <= blink_cnt + 1'b1;
end
assign blink = blink_cnt[23];

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        cal_scale     <= 9'd212;
        filter_enable <= 1'b1;
        thr_low       <= 8'd120;
        thr_high      <= 8'd255;
    end
    else if (adj_mode) begin
        case (adj_sel)
            2'd0: begin                       // low threshold
                if (key1_press && (thr_low > 8'd4))
                    thr_low <= thr_low - 8'd4;
                else if (key2_press && (thr_low < thr_high))
                    thr_low <= thr_low + 8'd4;
            end
            2'd1: begin                       // high threshold
                if (key1_press && (thr_high > thr_low))
                    thr_high <= thr_high - 8'd4;
                else if (key2_press && (thr_high < 8'd255))
                    thr_high <= thr_high + 8'd4;
            end
            2'd2: begin                       // stereo distance scale
                if (key1_press && (cal_scale > 9'd8))
                    cal_scale <= cal_scale - 9'd4;
                else if (key2_press && (cal_scale < 9'd256))
                    cal_scale <= cal_scale + 9'd4;
            end
            default: begin                    // distance filter on/off
                if (key1_press)
                    filter_enable <= 1'b0;
                else if (key2_press)
                    filter_enable <= 1'b1;
            end
        endcase
    end
    else begin
        if (key1_press && (cal_scale > 9'd8))
            cal_scale <= cal_scale - 9'd4;
        else if (key2_press && (cal_scale < 9'd256))
            cal_scale <= cal_scale + 9'd4;
    end
end

// LED: normal = mode + follow flag, adjust = parameter index + blink.
assign led[2:0] = adj_mode ? {1'b0, adj_sel} : mode_50m;
assign led[3]   = adj_mode ? blink : follow_enable;

//����ͷͼ��ֱ�������ģ��?
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
    .cmos_frame_href   (cmos_frame_href_1),
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
    .cmos_frame_href   (cmos_frame_href_2),
    .cmos_frame_valid  (cmos_frame_valid_2),
    .cmos_frame_data   (wr_data_2)
    );

    // Write-side red target detectors. Metadata follows the DDR3 ping-pong page.
    red_target_write_track u_ws_track_1 (
        .clk        (cam_pclk_1),
        .rst_n      (rst_n),
        .vsync      (cmos_frame_vsync_1),
        .href       (cmos_frame_href_1),
        .de         (cmos_frame_valid_1),
        .din        (wr_data_1),
        .h_disp     (h_disp[11:1]),
        .v_disp     (v_disp[10:0]),
        .meta_cx    (ws_l_meta_cx),
        .meta_cy    (ws_l_meta_cy),
        .meta_valid (ws_l_meta_valid),
        .meta_we    (ws_l_meta_we),
        .wr_page    (ws_l_wr_page)
    );

    red_target_write_track u_ws_track_2 (
        .clk        (cam_pclk_2),
        .rst_n      (rst_n),
        .vsync      (cmos_frame_vsync_2),
        .href       (cmos_frame_href_2),
        .de         (cmos_frame_valid_2),
        .din        (wr_data_2),
        .h_disp     (h_disp[11:1]),
        .v_disp     (v_disp[10:0]),
        .meta_cx    (ws_r_meta_cx),
        .meta_cy    (ws_r_meta_cy),
        .meta_valid (ws_r_meta_valid),
        .meta_we    (ws_r_meta_we),
        .wr_page    (ws_r_wr_page)
    );

    meta_dual_ram u_ws_meta_ram_1 (
        .wr_clk  (cam_pclk_1),
        .wr_en   (ws_l_meta_we),
        .wr_addr (ws_l_wr_page),
        .wr_data ({ws_l_meta_valid, ws_l_meta_cx, ws_l_meta_cy}),
        .rd_clk  (lcd_clk),
        .rd_addr (ws_l_rd_page),
        .rd_data (ws_l_meta_rd)
    );

    meta_dual_ram u_ws_meta_ram_2 (
        .wr_clk  (cam_pclk_2),
        .wr_en   (ws_r_meta_we),
        .wr_addr (ws_r_wr_page),
        .wr_data ({ws_r_meta_valid, ws_r_meta_cx, ws_r_meta_cy}),
        .rd_clk  (lcd_clk),
        .rd_addr (ws_r_rd_page),
        .rd_data (ws_r_meta_rd)
    );

    always @(posedge lcd_clk or negedge rst_n) begin
        if (!rst_n) begin
            ws_l_page_sync1 <= 1'b1; ws_l_page_sync2 <= 1'b1;
            ws_r_page_sync1 <= 1'b1; ws_r_page_sync2 <= 1'b1;
            ws_l_rd_page <= 1'b0; ws_r_rd_page <= 1'b0;
            rd_vsync_d <= 1'b0;
        end
        else begin
            ws_l_page_sync1 <= ws_l_wr_page; ws_l_page_sync2 <= ws_l_page_sync1;
            ws_r_page_sync1 <= ws_r_wr_page; ws_r_page_sync2 <= ws_r_page_sync1;
            rd_vsync_d <= rd_vsync;
            if (rd_vsync && !rd_vsync_d) begin
                ws_l_rd_page <= ~ws_l_page_sync2;
                ws_r_rd_page <= ~ws_r_page_sync2;
            end
        end
    end

//DDR3��д����ģ��
ddr3_top u_ddr3_top (
    .rst_n                 (rst_n),                 //��λ,����Ч
    .init_calib_complete   (init_calib_complete),   //DDR3��ʼ������ź�?
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
    .rddata                (rddata),                //rfifo�������?
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
    .follow_enable         (follow_enable),
    .thr_low               (thr_low),
    .thr_high              (thr_high),
    .cam_vsync             (cmos_frame_vsync_1),
    .ext_l_valid           (ws_l_meta_valid_rd),
    .ext_l_cx              (ws_l_meta_cx_rd),
    .ext_l_cy              (ws_l_meta_cy_rd),
    .ext_r_valid           (ws_r_meta_valid_rd),
    .ext_r_cx              (ws_r_meta_cx_rd),
    .ext_r_cy              (ws_r_meta_cy_rd),
    //LCD�ӿ�
    .lcd_id                (lcd_id),                //LCD����ID��
    .lcd_hs                (lcd_hs),                //LCD��ͬ���ź�
    .lcd_vs                (lcd_vs),                //LCD��ͬ���ź�
    .lcd_de                (lcd_de),                //LCD��������ʹ��
    .lcd_rgb               (lcd_rgb),               //LCD��ɫ����
    .lcd_bl                (lcd_bl),                //LCD��������ź�?
    .lcd_rst               (lcd_rst),               //LCD��λ�ź�
    .lcd_pclk              (lcd_pclk),              //LCD����ʱ��
    .lcd_clk               (lcd_clk),               //LCD����ʱ��
    //�û��ӿ�
    .out_vsync             (rd_vsync),              //LCD���ź�
    .h_disp                (),                      //�зֱ���
    .v_disp                (),                      //���ֱ���
    .pixel_xpos            (),
    .pixel_ypos            (),
    .data_in               (rddata),                //rfifo�������?
    .data_req              (rdata_req)              //������������
    );

endmodule

