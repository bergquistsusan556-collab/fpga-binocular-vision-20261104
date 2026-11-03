`timescale 1ns/1ps
// Independent bit-cost reference across both directions, including zero disparity.
module tb_front_fit_match #(parameter NEG=0);
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0,tex=1;
 reg [10:0] x=0,y=0;reg [7:0] code=0;
 wire ode,valid;wire [10:0] ox,oy;wire [5:0] disparity;
 stereo_census dut(clk,rst,de,x,y,11'd800,code,tex,NEG!=0,ode,valid,ox,oy,disparity);
 reg [7:0] seq[0:1023];reg [15:0] lfsr=16'hd3a7;
 integer i,j,phase,shift,checked=0,correct=0;
 integer k,q,z,c,best,second,index,aa;
 reg expected_valid;
 always @(negedge clk)if(ode&&ox>=100&&ox<300&&oy>=2)begin
  checked=checked+1;best=127;second=127;index=0;
  for(k=0;k<64;k=k+1)begin
   c=0;
   for(q=0;q<15;q=q+1)begin
    aa=NEG ? seq[ox-q-shift]^seq[ox-q-k] : seq[ox-q+shift]^seq[ox-q+k];
    for(z=0;z<8;z=z+1)c=c+((aa>>z)&1);
   end
   if(c<best)begin second=best;best=c;index=k;end
   else if(c<second)second=c;
  end
  expected_valid=(best<=45)&&(second>=best+6);
  if(valid!==expected_valid || (valid&&disparity!==index))
   $fatal(1,"Independent cost mismatch direction=%0d shift=%0d x=%0d",NEG,shift,ox);
  if(valid)begin
   if(disparity!=shift)$fatal(1,"Wrong accepted disparity");
   correct=correct+1;
  end
 end
 task tick;
 input integer tx,ty;input [7:0] c;
 begin @(negedge clk);de=1;x=tx;y=ty;code=c;end
 endtask
 initial begin
  for(i=0;i<1024;i=i+1)begin
   lfsr={lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};seq[i]=lfsr[15:8]^lfsr[7:0];
  end
  repeat(4)@(negedge clk);rst=1;
  for(phase=0;phase<4;phase=phase+1)begin
   case(phase)0:shift=0;1:shift=1;2:shift=7;3:shift=63;endcase
   checked=0;correct=0;
   for(j=0;j<5;j=j+1)begin
    for(i=0;i<400;i=i+1)tick(i,j,seq[i]);
    for(i=0;i<400;i=i+1)tick(i+400,j,NEG ? (i>=shift?seq[i-shift]:8'd0):seq[i+shift]);
    @(negedge clk);de=0;repeat(24)@(negedge clk);
   end
   repeat(24)@(negedge clk);
   if(checked<100||correct*100<checked*80)$fatal(1,"Insufficient correspondence coverage");
  end
  $display("PASS Census independent reference direction=%0d disparities 0/1/7/63",NEG);
  $finish;
 end
endmodule
module tb_front_fit_reverse;
 tb_front_fit_match #(.NEG(1)) test();
endmodule
