`timescale 1ns/1ps
// Read-only 100x60 luminance tap, programmable 8x8 sample phase.
// Independent read clock, registered address/data; no back-pressure on video.
module stereo_observer(
 input wire pixel_clk,read_clk,rst_n,de,
 input wire [10:0] x,y,
 input wire [15:0] rgb,
 input wire [5:0] phase,
 output wire [31:0] sample,
 input wire sof,snapshot
);
 (* ram_style="block" *) reg [7:0] image[0:5999];
 wire [7:0] r={rgb[15:11],rgb[15:13]},g={rgb[10:5],rgb[10:9]},b={rgb[4:0],rgb[4:2]};
 wire [15:0] sum=77*r+150*g+29*b;
 wire [12:0] normal_addr=(y>>3)*13'd100+(x>>3);
 // A single LCD frame: left 128x32 at (128,192), right 64x28 at (176,224).
 // The asymmetric regions include the observed vertical/horizontal mismatch.
 wire sl=x>=128&&x<256&&y>=192&&y<224;
 wire sr=x>=576&&x<640&&y>=224&&y<252;
 wire [12:0] snapshot_addr=sl?((y-11'd192)*13'd128+x-11'd128):
                         (13'd4096+(y-11'd224)*13'd64+x-11'd576);
 reg active,done;
 always @(posedge pixel_clk or negedge rst_n)
  if(!rst_n)begin active<=0;done<=0;end
  else if(!snapshot)begin active<=0;done<=0;end
  else if(sof&&!done)begin
   if(active)begin active<=0;done<=1;end
   else active<=1;
  end
 wire [12:0] wa=snapshot?snapshot_addr:normal_addr;
 wire write_enable=snapshot?(active&&(sl||sr)):
                   (x<800&&y<480&&x[2:0]==phase[2:0]&&y[2:0]==phase[5:3]);
 always @(posedge pixel_clk)
  if(de&&write_enable)image[wa]<=sum[15:8];
 reg [12:0] ra,addr;
 reg [7:0] pixel;
 (* ASYNC_REG="TRUE" *) reg [5:0] ps1,ps2;
 (* ASYNC_REG="TRUE" *) reg sn1,sn2,dn1,dn2;
 always @(posedge read_clk)pixel<=image[ra];
 always @(posedge read_clk or negedge rst_n)
  if(!rst_n)begin ra<=0;addr<=0;ps1<=0;ps2<=0;sn1<=0;sn2<=0;dn1<=0;dn2<=0;end
  else begin
   ra<=ra==5999?13'd0:ra+1'b1;addr<=ra;ps1<=phase;ps2<=ps1;
   sn1<=snapshot;sn2<=sn1;dn1<=done;dn2<=dn1;
  end
 assign sample=sn2?{3'b110,addr,5'd0,dn2,2'b10,pixel}:{3'b110,addr,ps2,2'b01,pixel};
endmodule
