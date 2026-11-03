`timescale 1ns/1ps
// Provisional frontal calibration: Z=A/(d+B); zero disparity may be valid.
// Parameters derived from three ruler-reference groups; see provisional_fit.json.
// Sequential divider is used only once per frame, never in the pixel path.
module depth_roi_follow #(
 parameter integer FOCAL_PX=346, BASELINE_MM=32,
 parameter integer MIN_SAMPLES=24,
 parameter integer CAL_A_Q8=561884, CAL_B_Q8=2677
)(
 input wire clk,rst_n,sof,de,valid,
 input wire [10:0] x,y,width,height,
 input wire [5:0] disp,
 input wire [8:0] scale,
 output reg [15:0] distance_cm,
 output reg distance_valid,
 output reg [5:0] dominant,
 output reg [63:0] diagnostic,
 input wire roi_enable,
 input wire [10:0] roi_cx,roi_cy,
 input wire [5:0] roi_rx,roi_ry,
 output reg [33:0] measured_roi
);
 reg [11:0] hist[0:63];
 reg [5:0] pos,winner;
 reg [11:0] peak;
 reg [13:0] samples;
 reg [13:0] population;
 reg [19:0] weighted;
 reg [3:0] state;
 reg [31:0] dividend,quotient;
 reg [32:0] remn;
 reg [31:0] divisor;
 reg [5:0] bitpos;
 reg [45:0] scaled_numerator;
 wire [32:0] trial={remn[31:0],dividend[31]};
 wire [31:0] rounded_distance=quotient+(({remn,1'b0}>={2'd0,divisor})?32'd1:32'd0);
 reg [10:0] cx,cy,completed_cx,completed_cy; reg [5:0] rx,ry,completed_rx,completed_ry; reg frame_enable,completed_enable;
 wire roi=frame_enable&&roi_enable&&(x+rx>=cx)&&(x<=cx+rx)&&(y+ry>=cy)&&(y<=cy+ry);
 integer i;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   cx<=0;cy<=0;rx<=0;ry<=0;frame_enable<=0;
   completed_cx<=0;completed_cy<=0;completed_rx<=0;completed_ry<=0;completed_enable<=0;measured_roi<=0;
   for(i=0;i<64;i=i+1)hist[i]<=0;
   pos<=0;winner<=0;peak<=0;samples<=0;population<=0;weighted<=0;state<=0;
   distance_cm<=0;distance_valid<=0;dominant<=0;scaled_numerator<=0;diagnostic<=0;
   dividend<=0;quotient<=0;remn<=0;divisor<=0;bitpos<=0;
  end else begin
   case(state)
   0:begin
    if(de&&valid&&roi&&hist[disp]!=4095)hist[disp]<=hist[disp]+1'b1;
    if(sof)begin completed_cx<=cx;completed_cy<=cy;completed_rx<=rx;completed_ry<=ry;completed_enable<=frame_enable;cx<=roi_cx;cy<=roi_cy;rx<=roi_rx;ry<=roi_ry;frame_enable<=roi_enable;pos<=0;winner<=0;peak<=0;state<=1;end
   end
   1:begin
    if(hist[pos]>peak)begin peak<=hist[pos];winner<=pos;end
    if(pos==63)begin state<=2;pos<=0;samples<=0;population<=0;weighted<=0;end
    else pos<=pos+1'b1;
   end
   2:begin
    population<=population+hist[pos];
    if(({1'b0,pos}+1>=winner) && (pos<={1'b0,winner}+1))begin
      samples<=samples+hist[pos];weighted<=weighted+hist[pos]*pos;
    end
    hist[pos]<=0;
    if(pos==63)state<=3;else pos<=pos+1'b1;
   end
   3:begin
    dominant<=winner;
    diagnostic<={4'd0,weighted,peak,samples[11:0],population[11:0],
                 population==0?4'd1:(samples<MIN_SAMPLES||peak<MIN_SAMPLES)?4'd2:
                 (({1'b0,samples}<<1)<population)?4'd3:4'd0};
    if(completed_enable&&roi_enable&&samples>=MIN_SAMPLES&&peak>=MIN_SAMPLES&&({1'b0,samples}<<1)>=population)begin
      scaled_numerator<=samples*CAL_A_Q8*scale;
      divisor<=({12'd0,weighted}<<8)+samples*CAL_B_Q8;state<=4;
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
    distance_valid<=completed_enable&&roi_enable&&(rounded_distance>=25&&rounded_distance<=250);
    diagnostic[3:0]<=rounded_distance<25?4'd4:rounded_distance>250?4'd5:4'd6;
    distance_cm<=rounded_distance[15:0];measured_roi<={completed_rx,completed_ry,completed_cx,completed_cy};state<=0;
   end
   default:state<=0;
   endcase
   if(!roi_enable)begin distance_valid<=0;distance_cm<=0;end
  end
 end
endmodule
