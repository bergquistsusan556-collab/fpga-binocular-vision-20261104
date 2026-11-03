`timescale 1ns/1ps
// ROI dominant disparity +/-1 bins; fractional mean via count/weighted sum.
// Sequential divider is used only once per frame, never in the pixel path.
module depth_roi #(
 parameter integer FOCAL_PX=346, BASELINE_MM=32,
 parameter integer MIN_SAMPLES=24
)(
 input wire clk,rst_n,sof,de,valid,
 input wire [10:0] x,y,width,height,
 input wire [5:0] disp,
 input wire [8:0] scale,
 output reg [15:0] distance_cm,
 output reg distance_valid,
 output reg [5:0] dominant
);
 reg [11:0] hist[0:63];
 reg [5:0] pos,winner;
 reg [11:0] peak;
 reg [13:0] samples;
 reg [19:0] weighted;
 reg [3:0] state;
 reg [31:0] dividend,quotient;
 reg [32:0] remn;
 reg [19:0] divisor;
 reg [5:0] bitpos;
 reg [45:0] scaled_numerator;
 wire [32:0] trial={remn[31:0],dividend[31]};
 wire [10:0] cx=width>>2,cy=height>>1;
 wire roi=(x+20>=cx)&&(x<=cx+20)&&(y+20>=cy)&&(y<=cy+20);
 integer i;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   for(i=0;i<64;i=i+1)hist[i]<=0;
   pos<=0;winner<=0;peak<=0;samples<=0;weighted<=0;state<=0;
   distance_cm<=0;distance_valid<=0;dominant<=0;scaled_numerator<=0;
   dividend<=0;quotient<=0;remn<=0;divisor<=0;bitpos<=0;
  end else begin
   case(state)
   0:begin
    if(de&&valid&&roi&&disp!=0&&hist[disp]!=4095)hist[disp]<=hist[disp]+1'b1;
    if(sof)begin pos<=1;winner<=0;peak<=0;state<=1;end
   end
   1:begin
    if(hist[pos]>peak)begin peak<=hist[pos];winner<=pos;end
    if(pos==63)begin state<=2;pos<=0;samples<=0;weighted<=0;end
    else pos<=pos+1'b1;
   end
   2:begin
    if(pos!=0 && ({1'b0,pos}+1>=winner) && (pos<={1'b0,winner}+1))begin
      samples<=samples+hist[pos];weighted<=weighted+hist[pos]*pos;
    end
    hist[pos]<=0;
    if(pos==63)state<=3;else pos<=pos+1'b1;
   end
   3:begin
    dominant<=winner;
    if(samples>=MIN_SAMPLES&&peak>=MIN_SAMPLES&&weighted!=0)begin
      scaled_numerator<=samples*(FOCAL_PX*BASELINE_MM/10)*scale;
      divisor<=weighted;state<=4;
    end else begin distance_valid<=0;distance_cm<=0;state<=0;end
   end
   4:begin dividend<=scaled_numerator>>8;quotient<=0;remn<=0;bitpos<=31;state<=5;end
   5:begin
    dividend<=dividend<<1;
    if(trial>=divisor)begin remn<=trial-divisor;quotient<={quotient[30:0],1'b1};end
    else begin remn<=trial;quotient<={quotient[30:0],1'b0};end
    if(bitpos==0)state<=6;else bitpos<=bitpos-1'b1;
   end
   6:begin
    distance_valid<=(quotient>=50&&quotient<=300);
    distance_cm<=quotient[15:0];state<=0;
   end
   default:state<=0;
   endcase
  end
 end
endmodule
