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
 depth_roi roi(clk,rst_n,sof,match_de,match_valid,mx,my,width,height,
               match_disp,scale,distance_cm,distance_valid,dominant,diagnostic_roi);
 wire [6:0] sample;wire ready;
 video_diagnostics metrics(clk,rst_n,sof,fv,ev,match_de,match_valid,lum,ergb,diagnostic_metrics);
 depth_frame frame(clk,rst_n,sof,match_de,match_valid,mx,my,match_disp,ex,ey,sample,ready);
 reg [15:0] rgb_d;reg [2:0] mode_d;
 wire [15:0] tools_rgb;
 video_tools display_tools(clk,rst_n,sof,ev,ex,ey,ergb,mode,tools_rgb);
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
   // Distance is tied to the fixed stereo ROI, not the template's green box.
   out_rgb=(osd_on&&mode_d<3)?osd_rgb:base;
 end
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin out_de<=0;out_x<=0;out_y<=0;rgb_d<=0;mode_d<=0;end
   else begin out_de<=ev;out_x<=ex;out_y<=ey;rgb_d<=ergb;mode_d<=mode;end
 end
endmodule
