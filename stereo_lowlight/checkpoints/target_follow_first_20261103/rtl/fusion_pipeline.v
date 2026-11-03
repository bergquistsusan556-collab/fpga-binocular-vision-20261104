`timescale 1ns/1ps
// LCD-clock pipeline. All modes share identical pixel/DE latency.
// Matcher consumes original luminance Census; enhancement cannot distort matching.
module fusion_pipeline(
 input wire clk,rst_n,sof,de,
 input wire [10:0] x,y,width,height,
 input wire [15:0] rgb,
 input wire [2:0] mode,
 input wire reverse,
 input wire [8:0] scale,
 output reg out_de,
 output reg [10:0] out_x,out_y,
 output reg [15:0] out_rgb,
 output wire [15:0] distance_cm,
 output wire distance_valid,
 output wire [5:0] dominant,
 output wire match_de,match_valid,
 output wire [5:0] match_disp,
 output wire [95:0] diagnostic_metrics,
 output wire [63:0] diagnostic_roi,
 input wire [7:0] alignment_control
);
 wire fv,tex;wire [10:0] fx,fy;wire [15:0] frgb;
 wire [7:0] lum,code,hy;wire [11:0] isum;wire [3:0] iw;
 stream_features features(clk,rst_n,de,x,y,width,rgb,fv,fx,fy,frgb,lum,code,tex,isum,iw);
 luma_histogram histogram(clk,rst_n,fv,sof,lum,hy);
 wire ev;wire [10:0] ex,ey;wire [15:0] ergb;
 lowlight_fixed enhance(clk,rst_n,fv,mode!=0,fx,fy,frgb,lum,hy,isum,iw,ev,ex,ey,ergb);
 wire [10:0] mx,my;
 wire av,atex;wire [10:0] ax,ay;wire [7:0] acode;
 stereo_row_align align(clk,rst_n,fv,fx,fy,width,code,tex,alignment_control,av,ax,ay,acode,atex);
 stereo_census matcher(clk,rst_n,av,ax,ay,width,acode,atex,reverse,
                       match_de,match_valid,mx,my,match_disp);
 wire target_valid; wire [7:0] tx,ty,tw,th,tepoch; wire [1:0] trot;
 wire following=mode==7;
 // Tag-to-texture offset comes from the unchanged printed PDF geometry.
 wire [11:0] tx2={3'd0,tx,1'b0},ty2={3'd0,ty,1'b0};
 wire [11:0] tw2={3'd0,tw,1'b0},th2={3'd0,th,1'b0};
 wire [11:0] tail_x=(tw2*3)>>4,tail_y=(th2*3)>>4;
 wire [11:0] follow_cx=trot==1?tx2-tail_x:trot==3?tx2+tw2+tail_x:tx2+(tw2>>1);
 wire [11:0] follow_cy=trot==2?ty2-tail_y:trot==0?ty2+th2+tail_y:ty2+(th2>>1);
 wire [7:0] long_half=(trot[0]?th:tw)>>1;
 wire [7:0] short_half=((trot[0]?tw:th)*3)>>5;
 wire [5:0] follow_rx=trot[0]?(short_half<1?1:short_half>20?20:short_half):
                                      (long_half<4?4:long_half>20?20:long_half);
 wire [5:0] follow_ry=trot[0]?(long_half<4?4:long_half>20?20:long_half):
                                      (short_half<1?1:short_half>20?20:short_half);
 wire follow_roi_ok=target_valid&&follow_cx>=follow_rx&&follow_cy>=follow_ry&&
   follow_cx+follow_rx<width/2&&follow_cy+follow_ry<height;
 wire [10:0] rcx=following?follow_cx[10:0]:width>>2;
 wire [10:0] rcy=following?follow_cy[10:0]:height>>1;
 wire [5:0] rrx=following?follow_rx:6'd20,rry=following?follow_ry:6'd20;
 wire [15:0] roi_cm;wire roi_valid;
 depth_roi_follow roi(clk,rst_n,sof,match_de,match_valid,mx,my,width,height,
   match_disp,scale,roi_cm,roi_valid,dominant,diagnostic_roi,
   !following||follow_roi_ok,rcx,rcy,rrx,rry);
 assign distance_cm=following&&!follow_roi_ok?16'd0:roi_cm;
 assign distance_valid=roi_valid&&(!following||follow_roi_ok);
 (* MARK_DEBUG="TRUE",KEEP="TRUE" *) wire [63:0] tracking_diagnostic;
 assign tracking_diagnostic={5'd0,trot,following,tepoch,th,tw,ty,tx,7'd0,target_valid};
 wire [6:0] sample;wire ready;
 video_diagnostics metrics(clk,rst_n,sof,fv,ev,match_de,match_valid,lum,ergb,diagnostic_metrics);
 depth_frame frame(clk,rst_n,sof,match_de,match_valid,mx,my,match_disp,ex,ey,sample,ready);
 reg [15:0] rgb_d;reg [2:0] mode_d;
 wire [15:0] tools_rgb;
 video_tools display_tools(clk,rst_n,sof,ev,ex,ey,ergb,mode,tools_rgb,target_valid,tx,ty,tw,th,trot,tepoch);
 wire osd_on;wire [15:0] osd_rgb;
 distance_osd osd(clk,rst_n,out_x,out_y,width,distance_cm,distance_valid,osd_on,osd_rgb);
 reg [15:0] base;
 wire [5:0] heat=sample[5:0];
 wire [5:0] ramp_down=6'd63-{heat[4:0],1'b0};
 always @* begin
   base=rgb_d;
   if(mode_d>=4)base=tools_rgb;
   if(mode_d==2) begin
     if(!ready||!sample[6])base=0;
     else if(heat<16)base={5'd0,heat,5'd31};
     else if(heat<32)base={5'd0,6'd63,ramp_down[5:1]};
     else if(heat<48)base={{heat[3:0],1'b0},6'd63,5'd0};
     else base={5'd31,ramp_down,5'd0};
   end
   if(mode_d==3)begin
     case(out_x[9:6])
       0:base=16'hffff;1:base=16'hffe0;2:base=16'h07ff;3:base=16'h07e0;
       4:base=16'hf81f;5:base=16'hf800;6:base=16'h001f;default:base=16'h8410;
     endcase
   end
   // ROI outline in right-reference coordinates; whole-field map is 2x wider.
   if(mode_d==2)begin
     if(((out_x+40==width/2||out_x==width/2+40)&&(out_y+20>=height/2&&out_y<=height/2+20))||
        ((out_y+20==height/2||out_y==height/2+20)&&(out_x+40>=width/2&&out_x<=width/2+40)))base=16'hffff;
   end else if(mode_d<2)begin
     if(((out_x+20==width*3/4||out_x==width*3/4+20)&&(out_y+20>=height/2&&out_y<=height/2+20))||
        ((out_y+20==height/2||out_y==height/2+20)&&(out_x+20>=width*3/4&&out_x<=width*3/4+20)))base=16'hffff;
   end
     if(mode_d==7&&follow_roi_ok)begin
     if((((out_x+rrx==400+rcx)||(out_x==400+rcx+rrx))&&(out_y+rry>=rcy&&out_y<=rcy+rry))||
        (((out_y+rry==rcy)||(out_y==rcy+rry))&&(out_x+rrx>=400+rcx&&out_x<=400+rcx+rrx)))base=16'hffff;
   end
   out_rgb=(osd_on&&(mode_d<3||mode_d==7))?osd_rgb:base;
 end
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin out_de<=0;out_x<=0;out_y<=0;rgb_d<=0;mode_d<=0;end
   else begin out_de<=ev;out_x<=ex;out_y<=ey;rgb_d<=ergb;mode_d<=mode;end
 end
endmodule
