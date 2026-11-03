`timescale 1ns/1ps
// One-cycle display sidecar. Never changes the stereo matcher input or stalls video.
// Modes 4/5/6: enhanced-luma binary, two-axis gradient, 8x8 sampled frame difference.
module video_tools(
 input wire clk,rst_n,sof,de,
 input wire [10:0] x,y,
 input wire [15:0] rgb,
 input wire [2:0] mode,
 output reg [15:0] processed
);
 wire [7:0] r={rgb[15:11],rgb[15:13]},g={rgb[10:5],rgb[10:9]},b={rgb[4:0],rgb[4:2]};
 wire [15:0] weighted=77*r+150*g+29*b;
 wire [7:0] lum=weighted[15:8];
 (* ram_style="block" *) reg [7:0] line_mem[0:799];
 (* ram_style="block" *) reg [5:0] previous[0:5999];
 (* ram_style="block" *) reg motion_mask[0:5999];
 wire [12:0] grid_addr=(y>>3)*100+(x>>3);
 reg [7:0] top,left,last_lum,current;
 reg [5:0] old_lum;
 reg old_mask,valid_q,have_previous,motion_run,sample_q;
 reg [10:0] xx,yy;
 reg [12:0] addr_q,samples;
 reg [15:0] rgb_q;
 reg [2:0] mode_q;
 wire [7:0] dx=current>left?current-left:left-current;
 wire [7:0] dy=current>top?current-top:top-current;
 wire [8:0] gradient={1'b0,dx}+{1'b0,dy};
 wire [5:0] delta=current[7:2]>old_lum?current[7:2]-old_lum:old_lum-current[7:2];
 wire changed=have_previous && delta>=6;
 wire moving=have_previous && (yy[2:0]==0 ? (xx[2:0]==0?changed:motion_run) : old_mask);
 wire template_valid,template_ready;
 wire [7:0] target_x,target_y;
 binary_template32 matcher(clk,rst_n,sof,de,x,y,lum>=128,mode==7,
                           template_ready,template_valid,target_x,target_y);
 wire [10:0] bx=400+{target_x,1'b0},by={target_y,1'b0};
 wire outline=template_valid &&
   (((xx==bx||xx==bx+63)&&(yy>=by&&yy<=by+63)) ||
    ((yy==by||yy==by+63)&&(xx>=bx&&xx<=bx+63)));
 always @* begin
   processed=rgb_q;
   case(mode_q)
    4:processed=current>=128?16'hffff:16'h0000;
    5:processed=(xx!=0&&xx!=400&&yy!=0&&gradient>=48)?16'hffff:16'h0000;
    6:processed=moving?16'hf800:{1'b0,rgb_q[15:12],1'b0,rgb_q[10:6],1'b0,rgb_q[4:1]};
    7:begin
      // Yellow: fixed acquisition area. Green: unique accepted search result.
      if(((xx==560||xx==623)&&(yy>=208&&yy<=271)) ||
         ((yy==208||yy==271)&&(xx>=560&&xx<=623))) processed=template_ready?16'hffe0:16'hffff;
      if(outline)processed=16'h07e0;
    end
   endcase
 end
 always @(posedge clk) begin
   if(de&&x<800&&y<480)begin
     top<=line_mem[x];line_mem[x]<=lum;
     old_lum<=previous[grid_addr];old_mask<=motion_mask[grid_addr];
     if(x[2:0]==0&&y[2:0]==0)previous[grid_addr]<=lum[7:2];
   end
   if(valid_q&&sample_q)motion_mask[addr_q]<=changed;
 end
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin
     xx<=0;yy<=0;current<=0;left<=0;last_lum<=0;rgb_q<=0;mode_q<=0;
     valid_q<=0;have_previous<=0;motion_run<=0;sample_q<=0;addr_q<=0;samples<=0;
   end else begin
     valid_q<=de;xx<=x;yy<=y;current<=lum;rgb_q<=rgb;mode_q<=mode;
     sample_q<=x[2:0]==0&&y[2:0]==0;addr_q<=grid_addr;
     if(de)begin left<=last_lum;last_lum<=lum;end
     if(valid_q&&xx[2:0]==0)motion_run<=changed;
     if(sof)begin have_previous<=samples==6000;samples<=0;end
     else if(de&&x<800&&y<480&&x[2:0]==0&&y[2:0]==0)samples<=samples+1'b1;
   end
 end
endmodule
