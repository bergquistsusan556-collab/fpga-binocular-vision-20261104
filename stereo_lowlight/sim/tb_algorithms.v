`timescale 1ns/1ps
module tb_algorithms #(parameter NEG=0);
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0,tex=1,en=0;
 reg [10:0] x=0,y=0;
 reg [7:0] code=0;
 wire ode,valid;wire [10:0] ox,oy;wire [5:0] d;
 stereo_census dut(clk,rst,de,x,y,11'd256,code,tex,NEG!=0,ode,valid,ox,oy,d);
 reg [7:0] seq[0:255];
 integer i,j,f,checked=0,correct=0;
 integer bd,bc,sc,c,k,q,z,aa;
 reg ev;
 reg [15:0] lfsr=16'hd3a7;
 always @(negedge clk)if(ode&&ox>=24&&ox<100&&oy>=2)begin
  checked=checked+1;
  bd=0;bc=127;sc=127;
  for(k=1;k<64;k=k+1)begin
   c=0;
   if(NEG ? ox<k+16 : ox+k>=128)c=127;
   else for(q=0;q<15;q=q+1)begin
     aa=NEG ? seq[ox-q-7]^seq[ox-q-k] : seq[ox-q+7]^seq[ox-q+k];
     for(z=0;z<8;z=z+1)c=c+((aa>>z)&1);
   end
   if(c<bc)begin sc=bc;bc=c;bd=k;end
   else if(c<sc)sc=c;
  end
  ev=(bc<=45)&&(sc>=bc+6);
  if(valid!==ev || (valid && d!==bd))$fatal(1,"Reference mismatch x=%0d valid=%b/%b d=%0d/%0d",ox,valid,ev,d,bd);
  if(valid)begin
   if(d!=7)$fatal(1,"Wrong accepted disparity");
   correct=correct+1;
  end
 end
 task tick;
 input integer tx,ty; input [7:0] c;
 begin @(negedge clk);de=1;x=tx;y=ty;code=c;end
 endtask
 initial begin
  for(i=0;i<256;i=i+1)begin
   lfsr={lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};seq[i]=lfsr[15:8]^lfsr[7:0];
  end
  repeat(4)@(negedge clk);rst=1;
  for(j=0;j<8;j=j+1)begin
   for(i=0;i<128;i=i+1)tick(i,j,seq[i]);
   for(i=0;i<128;i=i+1)tick(i+128,j,NEG ? (i>=7 ? seq[i-7] : 8'd0) : seq[i+7]);
   @(negedge clk);de=0;repeat(20)@(negedge clk);
  end
  repeat(20)@(negedge clk);
  if(checked<100||correct*100<checked*80)$fatal(1,"Insufficient valid coverage %0d/%0d",correct,checked);
  $display("PASS Census direction=%0d independent cost/uniqueness reference, disparity 7: %0d/%0d",NEG,correct,checked);
  $finish;
 end
endmodule
