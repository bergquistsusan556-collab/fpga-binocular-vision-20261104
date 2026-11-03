`timescale 1ns/1ps
module BUFG(input wire I,output wire O);assign O=I;endmodule
module tb_lcd_system;
 reg sys_clk=0;always #10 sys_clk=~sys_clk;
 reg rst=0;reg [2:0] mode=0;
 wire clk,hs,vs,de,bl,lr,pc,sof,req;
 wire [10:0] x,y,w,h;
 wire [15:0] id;
 tri [23:0] bus;
 assign (weak1,weak0) bus=24'h000080;
 reg [15:0] data=0;
 wire [95:0] metrics;wire [24:0] status;
 lcd_rgb_top dut(.sys_clk(sys_clk),.sys_rst_n(rst),.sys_init_done(1'b1),
 .mode_in(mode),.cal_scale(9'd256),.filter_enable(1'b0),.activity1(8'd0),.activity2(8'd0),.heartbeat(1'b0),
 .lcd_clk(clk),.lcd_hs(hs),.lcd_vs(vs),.lcd_de(de),.lcd_rgb(bus),.lcd_bl(bl),.lcd_rst(lr),.lcd_pclk(pc),
 .lcd_id(id),.out_vsync(sof),.pixel_xpos(x),.pixel_ypos(y),.h_disp(w),.v_disp(h),.data_in(data),.data_req(req),
 .diagnostic_control(16'd0),.diagnostic_metrics(metrics),.diagnostic_status(status));
 function [15:0] pixel;
 input integer xx,yy;
 reg [7:0] a;
 begin a=8+((xx*17+yy*23)%80);pixel={a[7:3],a[7:2],a[7:3]};end
 endfunction
 function [15:0] bars;
 input integer xx;
 begin case(xx/64)
 0:bars=16'hffff;1:bars=16'hffe0;2:bars=16'h07ff;3:bars=16'h07e0;
 4:bars=16'hf81f;5:bars=16'hf800;6:bars=16'h001f;default:bars=16'h8410;
 endcase end endfunction
 integer rx=0,ry=0,count=0,frames=0;
 reg sof_d=0;
 reg [15:0] shown;
 always @(posedge clk)begin
  sof_d<=sof;
  if(sof&&!sof_d)begin rx<=0;ry<=0;end
  else if(req)begin
   data<=pixel(rx,ry);
   if(rx==799)begin rx<=0;ry<=ry+1;end else rx<=rx+1;
  end
 end
 always @(negedge clk)if(de)begin
  shown={bus[23:19],bus[15:10],bus[7:3]};
  if(x!=count%800 || y!=count/800)$fatal(1,"LCD request/FIFO/coordinate lost alignment %0d,%0d count=%0d",x,y,count);
  if(status[24:23]==0 && !(y>=8&&y<40) && !(x>=580&&x<=620&&y>=220&&y<=260) && shown!==pixel(x,y))
   $fatal(1,"LCD raw data mismatch at %0d,%0d got=%h expected=%h",x,y,shown,pixel(x,y));
  if(status[24:23]==3 && shown!==bars(x))$fatal(1,"Test bars altered by processing/overlay");
  count=count+1;
  if(count==384000)begin
   frames=frames+1;count=0;
   if(frames==1)mode=1;
   else if(frames==2)begin
    if(metrics[73:54]!=384000)$fatal(1,"LCD diagnostics pixel count incorrect");
    mode=3;
   end else if(frames==3)begin
    if(metrics[53:27]<=metrics[26:0])$fatal(1,"Enhanced frame was not brighter than raw frame");
    if(id!=16'h4384||w!=800||h!=480)$fatal(1,"LCD identification/geometry failed");
    $display("PASS complete LCD request + modeled FIFO latency + 3 full frames, raw RGB alignment, enhancement lift, color bars and frame metrics");$finish;
   end
  end
 end
 initial begin repeat(5)@(negedge sys_clk);rst=1;#90000000;$fatal(1,"Full LCD simulation timeout");end
endmodule
