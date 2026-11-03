`timescale 1ns/1ps
// Per-target translational alignment search; original fixed modes bypass it.
// Compare only measurements that pass the unchanged matcher/ROI confidence.
module follow_row_tuner(
 input wire clk,rst_n,sof,enable,
 input wire [7:0] base_control,
 input wire target_valid,roi_in_frame,position_consistent,roi_valid,
 input wire [63:0] diagnostic,
 output wire [7:0] control,
 output reg ready,busy,
 output reg [4:0] row
);
 localparam IDLE=0,SEARCH=1,SETTLE=2,LOCKED=3;
 reg [1:0] state;
 reg [7:0] previous_base;
 reg [4:0] low_row,high_row,best_row;
 reg [2:0] phase;
 reg [13:0] score,best_score;
 reg [3:0] invalid_frames;
 wire qualified=target_valid&&roi_in_frame&&position_consistent&&roi_valid;
 wire [13:0] next_score=score+(qualified?{2'd0,diagnostic[39:28]}:14'd0);
 wire better=next_score>best_score;
 assign control=enable?{base_control[7:5],row}:base_control;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;previous_base<=0;low_row<=0;high_row<=0;best_row<=0;
   phase<=0;score<=0;best_score<=0;invalid_frames<=0;row<=0;ready<=0;busy<=0;
  end else if(!enable)begin
   state<=IDLE;row<=base_control[4:0];previous_base<=base_control;
   ready<=1;busy<=0;phase<=0;invalid_frames<=0;score<=0;best_score<=0;
  end else if(base_control!=previous_base)begin
   previous_base<=base_control;state<=IDLE;row<=base_control[4:0];
   ready<=0;busy<=0;score<=0;best_score<=0;phase<=0;invalid_frames<=0;
  end else if(sof)begin
   case(state)
    IDLE:begin
     ready<=0;busy<=0;
     if(target_valid&&roi_in_frame)begin
      low_row<=base_control[4:0]<4?0:base_control[4:0]-5'd4;
      high_row<=base_control[4:0]>27?31:base_control[4:0]+5'd4;
      row<=base_control[4:0]<4?0:base_control[4:0]-5'd4;
      best_row<=base_control[4:0];phase<=0;score<=0;best_score<=0;busy<=1;state<=SEARCH;
     end
    end
    SEARCH:begin
     // Two complete SOF intervals flush previous-row histogram/divider data;
     // then score two frames. A failed decode contributes no confidence.
     if(phase<2)phase<=phase+1'b1;
     else if(phase==2)begin score<=next_score;phase<=3;end
     else begin
      if(better)begin best_score<=next_score;best_row<=row;end
      phase<=0;score<=0;
      if(row==high_row)begin
       if(next_score!=0||best_score!=0)begin row<=better?row:best_row;state<=SETTLE;end
       else begin row<=low_row;best_score<=0;end
      end else row<=row+1'b1;
     end
    end
    SETTLE:begin
     if(phase<2)phase<=phase+1'b1;
     else begin state<=LOCKED;ready<=1;busy<=0;invalid_frames<=0;end
    end
    LOCKED:begin
     if(qualified)invalid_frames<=0;
     else if(target_valid&&roi_in_frame)begin
      if(invalid_frames==7)begin state<=IDLE;ready<=0;busy<=0;end
      else invalid_frames<=invalid_frames+1'b1;
     end
    end
    default:begin state<=IDLE;ready<=0;busy<=0;end
   endcase
  end
 end
endmodule
