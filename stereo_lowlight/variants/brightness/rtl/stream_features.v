`timescale 1ns/1ps
// Causal 3x3 window. Independent history for the two half-width images.
// RAM contents need no reset: first two rows/columns use replicated samples.
module stream_features(
 input wire clk, rst_n, de,
 input wire [10:0] x,y,width,
 input wire [15:0] rgb,
 output reg valid,
 output reg [10:0] ox,oy,
 output reg [15:0] orgb,
 output reg [7:0] luminance, census,
 output reg textured,
 output reg [11:0] illum_sum,
 output reg [3:0] illum_weight
);
 wire [7:0] r={rgb[15:11],rgb[15:13]};
 wire [7:0] g={rgb[10:5],rgb[10:9]};
 wire [7:0] b={rgb[4:0],rgb[4:2]};
 wire [15:0] ys=77*r+150*g+29*b;
 wire [7:0] yin=ys[15:8];
 (* ram_style="block" *) reg [7:0] row1[0:1023],row2[0:1023];
 reg [7:0] q1,q2,cy;
 reg [15:0] crgb;
 reg [10:0] cx,cypos;
 reg cv;
 reg [7:0] h00,h01,h10,h11,h20,h21;
 wire [10:0] local_x=(cx >= (width>>1)) ? cx-(width>>1) : cx;
 wire [7:0] up1=(cypos>=1)?q1:cy;
 wire [7:0] up2=(cypos>=2)?q2:up1;
 wire [7:0] n[0:7];
 assign n[0]=(local_x>=2)?h01:up2;
 assign n[1]=(local_x>=1)?h00:up2;
 assign n[2]=up2;
 assign n[3]=(local_x>=2)?h11:up1;
 assign n[4]=(local_x>=1)?h10:up1;
 assign n[5]=up1;
 assign n[6]=(local_x>=2)?h21:cy;
 assign n[7]=(local_x>=1)?h20:cy;
 reg [11:0] sum;
 reg [3:0] weight;
 reg [7:0] code,mind,maxd;
 integer k;
 always @* begin
   sum={2'b0,cy,2'b0}; weight=4; code=0; mind=cy; maxd=cy;
   for(k=0;k<8;k=k+1) begin
     code[k]=(n[k]<cy);
     if(n[k]<mind) mind=n[k];
     if(n[k]>maxd) maxd=n[k];
     // Hard range kernel is a fixed-point bilateral approximation.
     if(((n[k]>cy)?n[k]-cy:cy-n[k])<=24) begin
       sum=sum+n[k]; weight=weight+1'b1;
     end
   end
 end
 always @(posedge clk) if(de) begin
   q1<=row1[x]; q2<=row2[x];
   row1[x]<=yin; row2[x]<=row1[x];
 end
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
     cv<=0;valid<=0;cx<=0;cypos<=0;cy<=0;crgb<=0;
     h00<=0;h01<=0;h10<=0;h11<=0;h20<=0;h21<=0;
     ox<=0;oy<=0;orgb<=0;luminance<=0;census<=0;
     textured<=0;illum_sum<=0;illum_weight<=4;
   end else begin
     cv<=de;cx<=x;cypos<=y;cy<=yin;crgb<=rgb;
     valid<=cv;ox<=cx;oy<=cypos;orgb<=crgb;luminance<=cy;
     census<=code;textured<=(maxd-mind>=8)&&(local_x>=2)&&(cypos>=2);
     illum_sum<=sum;illum_weight<=weight;
     if(cv) begin
       h00<=up2;h01<=local_x==0?up2:h00;
       h10<=up1;h11<=local_x==0?up1:h10;
       h20<=cy;h21<=local_x==0?cy:h20;
     end
   end
 end
endmodule
