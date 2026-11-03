`timescale 1ns/1ps
// Dedicated printed ID7 detector, not a generic object classifier.
// Coherent 200x240 binary snapshot; border-run candidates, four rotations,
// normalized 6x6 code verification, duplicate rejection and automatic reacquisition.
module marker7_tracker(
 input wire clk,rst_n,sof,de,
 input wire [10:0] x,y,
 input wire binary_pixel,enable,
 output reg ready,match_valid,
 output reg [7:0] match_x,match_y,match_w,match_h,
 output reg [1:0] match_rotation,
 output reg [7:0] epoch
);
 localparam WAIT_FRAME=0,CAPTURE=1,SCAN_READ=2,SCAN_EVAL=3,
   TOP_READ=4,TOP_EVAL=5,EDGE_READ=6,EDGE_EVAL=7,
   QUIET_READ=8,QUIET_EVAL=9,GRID_READ=10,GRID_EVAL=11,PUBLISH=12,UP_READ=13,UP_EVAL=14;
 reg [3:0] state;
 (* ram_style="block" *) reg frame_mem[0:47999];
 reg pixel_q;
 wire sample=de&&x>=400&&x<800&&y<480&&!x[0]&&!y[0];
 wire [7:0] sx=(x-400)>>1,sy=y>>1;
 wire [15:0] write_addr=sy*200+sx;
 reg [15:0] sample_count;
 reg [7:0] scan_x,scan_y,run_start,run_length;
 reg [7:0] cx,cy,cw,ch,edge_y,left_h,upper_y;
 reg edge_right;
 reg [1:0] quiet;
 reg [2:0] gr,gc;
 reg [5:0] err0,err1,err2,err3;
 reg found,ambiguous;
 reg [7:0] found_x,found_y,found_w,found_h;
 reg [1:0] found_rotation;
 reg [2:0] age;
 wire [7:0] edge_height=edge_y-cy;
 wire [7:0] candidate_h=edge_height>left_h?edge_height:left_h;
 wire [7:0] edge_top=pixel_q?edge_y+1'b1:edge_y;
 wire [7:0] normalized_top=edge_top<upper_y?edge_top:upper_y;
 wire [8:0] normalized_h={1'b0,cy}+ch-normalized_top;
 wire [15:0] area=cw*ch,found_area=found_w*found_h;
 wire [8:0] center_x={1'b0,cx}+({1'b0,cw}>>1);
 wire [8:0] center_y={1'b0,cy}+({1'b0,ch}>>1);
 wire [8:0] found_center_x={1'b0,found_x}+({1'b0,found_w}>>1);
 wire [8:0] found_center_y={1'b0,found_y}+({1'b0,found_h}>>1);
 wire [8:0] dx=center_x>found_center_x?center_x-found_center_x:found_center_x-center_x;
 wire [8:0] dy=center_y>found_center_y?center_y-found_center_y:found_center_y-center_y;
 wire same_object=dx<(({1'b0,cw}+found_w)>>2)&&dy<(({1'b0,ch}+found_h)>>2);
 function marker_cell;
 input [1:0] rotation; input [2:0] row,col;
 reg [2:0] a,b;
 begin
   case(rotation)
    0:begin a=row;b=col;end
    1:begin a=5-col;b=row;end
    2:begin a=5-row;b=5-col;end
    default:begin a=col;b=5-row;end
   endcase
   case({a,b})
    {3'd1,3'd1},{3'd1,3'd2},{3'd2,3'd2},
    {3'd3,3'd1},{3'd3,3'd2},{3'd3,3'd3},{3'd3,3'd4},{3'd4,3'd3}:marker_cell=1;
    default:marker_cell=0;
   endcase
 end endfunction
 wire [5:0] next0=err0+(pixel_q^marker_cell(0,gr,gc));
 wire [5:0] next1=err1+(pixel_q^marker_cell(1,gr,gc));
 wire [5:0] next2=err2+(pixel_q^marker_cell(2,gr,gc));
 wire [5:0] next3=err3+(pixel_q^marker_cell(3,gr,gc));
 // ID7 is at least four payload bits from every other dictionary ID/rotation.
 // One sampled-cell error is allowed; competing orientations remain rejected.
 wire [2:0] orientations={2'b0,(next0<=1)}+{2'b0,(next1<=1)}+
                         {2'b0,(next2<=1)}+{2'b0,(next3<=1)};
 wire code_ok=orientations==1;
 wire [1:0] code_rotation=next0<=1?0:next1<=1?1:next2<=1?2:3;
 wire [15:0] grid_x=(2*gc+1)*cw/12;
 wire [15:0] grid_y=(2*gr+1)*ch/12;
 reg [15:0] read_addr;
 always @*begin
  read_addr=scan_y*200+scan_x;
  case(state)
   TOP_READ:read_addr=(cy>cw/2?cy-cw/2:0)*200+cx+cw/2;
   EDGE_READ,UP_READ:read_addr=edge_y*200+cx+(edge_right?cw-1-cw/12:cw/12);
   QUIET_READ:case(quiet)
    0:read_addr=(cy+ch/2)*200+(cx>=cw/6?cx-cw/6:0);
    1:read_addr=(cy+ch/2)*200+(cx+cw+cw/6<200?cx+cw+cw/6:199);
    default:read_addr=(cy+ch+ch/12<240?cy+ch+ch/12:239)*200+cx+cw/2;
   endcase
   GRID_READ:read_addr=(cy+grid_y)*200+cx+grid_x;
  endcase
 end
 always @(posedge clk)begin
  if(enable&&state==CAPTURE&&sample)frame_mem[write_addr]<=binary_pixel;
  if(state==SCAN_READ||state==TOP_READ||state==EDGE_READ||state==UP_READ||state==QUIET_READ||state==GRID_READ)
    pixel_q<=frame_mem[read_addr];
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=WAIT_FRAME;ready<=0;match_valid<=0;match_x<=0;match_y<=0;match_w<=0;match_h<=0;
   match_rotation<=0;epoch<=0;age<=0;sample_count<=0;
   scan_x<=0;scan_y<=0;run_start<=0;run_length<=0;
   cx<=0;cy<=0;cw<=0;ch<=0;edge_y<=0;left_h<=0;upper_y<=0;edge_right<=0;quiet<=0;gr<=0;gc<=0;
   err0<=0;err1<=0;err2<=0;err3<=0;found<=0;ambiguous<=0;
   found_x<=0;found_y<=0;found_w<=0;found_h<=0;found_rotation<=0;
  end else if(!enable)begin
   state<=WAIT_FRAME;ready<=0;match_valid<=0;sample_count<=0;age<=0;
  end else begin
   if(sof)begin
    if(age<7)age<=age+1'b1;
    if(age>=3)match_valid<=0;
   end
   case(state)
    WAIT_FRAME:if(sof)begin state<=CAPTURE;sample_count<=0;end
    CAPTURE:begin
     if(sof)begin sample_count<=0;match_valid<=0;end
     else if(sample)begin
      sample_count<=sample_count+1'b1;
      if(sx==199&&sy==239)begin
       if(sample_count!=47999)begin state<=WAIT_FRAME;match_valid<=0;end
       else begin
        ready<=1;state<=SCAN_READ;scan_x<=0;scan_y<=0;run_length<=0;found<=0;ambiguous<=0;
       end
      end
     end
    end
    SCAN_READ:state<=SCAN_EVAL;
    SCAN_EVAL:begin
     state<=SCAN_READ;
     if(pixel_q)begin
      run_length<=0;
      if(run_length>=12&&run_length<=190&&run_start>=2&&scan_x<198&&
         scan_y>=2&&scan_y<226)begin
       cx<=run_start;cy<=scan_y;cw<=run_length;state<=TOP_READ;
      end
     end else begin
      if(run_length==0)run_start<=scan_x;
      run_length<=run_length+1'b1;
     end
     if(scan_x==199)begin
      scan_x<=0;scan_y<=scan_y+1'b1;run_length<=0;
      if(scan_y==239)state<=PUBLISH;
     end else scan_x<=scan_x+1'b1;
    end
    TOP_READ:state<=TOP_EVAL;
    TOP_EVAL:begin
     if(!pixel_q)state<=SCAN_READ;
     else begin edge_y<=cy;edge_right<=0;left_h<=0;state<=EDGE_READ;end
    end
    EDGE_READ:state<=EDGE_EVAL;
    EDGE_EVAL:begin
     if(!pixel_q&&edge_y<238)begin edge_y<=edge_y+1'b1;state<=EDGE_READ;end
     else if(!edge_right)begin
      left_h<=edge_height;edge_right<=1;edge_y<=cy;state<=EDGE_READ;
     end else if(candidate_h>=12&&cy+{1'b0,candidate_h}<238&&
                 candidate_h*3>=cw&&candidate_h<=cw*3)begin
      ch<=candidate_h;upper_y<=cy;edge_y<=cy;edge_right<=0;state<=UP_READ;
     end else state<=SCAN_READ;
    end
    UP_READ:state<=UP_EVAL;
    UP_EVAL:begin
     if(!pixel_q&&edge_y>1)begin edge_y<=edge_y-1'b1;state<=UP_READ;end
     else if(!edge_right)begin
      upper_y<=edge_top;edge_y<=cy;edge_right<=1;state<=UP_READ;
     end else if(normalized_h>=12&&normalized_h<=cw*3&&normalized_h*3>=cw)begin
      cy<=normalized_top;ch<=normalized_h[7:0];quiet<=0;state<=QUIET_READ;
     end else state<=SCAN_READ;
    end
    QUIET_READ:state<=QUIET_EVAL;
    QUIET_EVAL:begin
     if(!pixel_q)state<=SCAN_READ;
     else if(quiet==2)begin gr<=0;gc<=0;err0<=0;err1<=0;err2<=0;err3<=0;state<=GRID_READ;end
     else begin quiet<=quiet+1'b1;state<=QUIET_READ;end
    end
    GRID_READ:state<=GRID_EVAL;
    GRID_EVAL:begin
     err0<=next0;err1<=next1;err2<=next2;err3<=next3;
     if(gr==5&&gc==5)begin
      if(code_ok)begin
       if(!found||same_object)begin
        if(!found||area>found_area)begin
         found_x<=cx;found_y<=cy;found_w<=cw;found_h<=ch;found_rotation<=code_rotation;
        end
        found<=1;
       end else ambiguous<=1;
      end
      state<=SCAN_READ;
     end else if(next0>1&&next1>1&&next2>1&&next3>1)state<=SCAN_READ;
     else begin
      if(gc==5)begin gc<=0;gr<=gr+1'b1;end else gc<=gc+1'b1;
      state<=GRID_READ;
     end
    end
    PUBLISH:if(sof)begin
     match_valid<=found&&!ambiguous;match_x<=found_x;match_y<=found_y;match_w<=found_w;match_h<=found_h;
     match_rotation<=found_rotation;epoch<=epoch+1'b1;age<=0;
     state<=CAPTURE;sample_count<=0;
    end
    default:state<=WAIT_FRAME;
   endcase
  end
 end
endmodule
