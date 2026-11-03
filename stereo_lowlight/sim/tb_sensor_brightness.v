`timescale 1ns/1ps
module tb_sensor_brightness;
 reg clk=0,rst=0,done=0;
 reg [7:0] read_data=0;
 wire exec,rw,ready;
 wire [23:0] data;
 wire [15:0] id;
 wire [63:0] debug_data;
 always #500 clk=~clk;
 i2c_ov5640_rgb565_cfg dut(.clk(clk),.rst_n(rst),.i2c_data_r(read_data),.i2c_done(done),
 .cmos_h_pixel(13'd400),.cmos_v_pixel(13'd480),.total_h_pixel(13'd1800),.total_v_pixel(13'd1000),
 .y_addr_st(13'd187),.y_addr_end(13'd1763),.i2c_exec(exec),.i2c_data(data),.i2c_rh_wl(rw),
 .sensor_id(id),.sensor_debug(debug_data),.init_done(ready));
 integer n=0,reads=0,k;
 reg [7:0] regs[0:65535];
 time reset_time;
 initial begin
  for(k=0;k<65536;k=k+1)regs[k]=0;
  regs['h300a]='h56;regs['h300b]='h40;
  regs['h3501]='h12;regs['h3502]='h30;regs['h350b]='h80;regs['h56a1]='h54;
  #1200 rst=1;
 end
 // Mock an SCCB transfer. Sample address/control at launch, return 8 clocks later.
 reg [23:0] transaction;
 reg reading;
 initial forever begin
  wait(exec);#1;
  transaction=data;reading=rw;
  if(n==0 && $time<20000000)$fatal(1,"Power-up wait too short");
  if(n==2)reset_time=$time;
  if(n==3 && $time-reset_time<2000000)$fatal(1,"Reset recovery too short");
  if(n<2 && !reading)$fatal(1,"ID must be read");
  if(n>=2 && n<251 && reading)$fatal(1,"Init must write");
  if(n>=251 && !reading)$fatal(1,"Polling must never write");
  repeat(8)@(negedge clk);
  if(reading)read_data=regs[transaction[23:8]];
  else regs[transaction[23:8]]=transaction[7:0];
  done=1;
  @(negedge clk);done=0;
  n=n+1;
  if(n>=267)begin
   repeat(3)@(negedge clk);
   if(id!==16'h5640 || !ready)$fatal(1,"Initialization/ID failed");
   if(regs['h3a0f]!==8'h58 || regs['h3a10]!==8'h50 || regs['h3503]!==0)$fatal(1,"AEC setup mismatch");
   if(debug_data!==64'h5854800030120000)$fatal(1,"Readback mismatch %h",debug_data);
   $display("PASS sensor: 251 init operations, reset delay, auto exposure target, repeated register readback");
   $finish;
  end
 end
 initial begin #300000000;$fatal(1,"Sensor config timed out");end
endmodule
