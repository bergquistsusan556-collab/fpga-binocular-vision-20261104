from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'sim/tb_stereo_scene.v').read_text()
s=s.replace('module tb_stereo_scene;','module tb_alignment_scene;')
s=s.replace(' stereo_census match(clk,rst,fv,fx,fy,11\'d800,code,tex,1\'b0,md,mv,mx,my,disparity);',
 ''' wire av,at;wire [10:0] ax,ay;wire [7:0] ac;
 stereo_row_align align(clk,rst,fv,fx,fy,11'd800,code,tex,8'h98,av,ax,ay,ac,at);
 stereo_census match(clk,rst,av,ax,ay,11'd800,ac,at,1'b0,md,mv,mx,my,disparity);''')
s=s.replace('my>=4','my>=28')
s=s.replace('pixel(i-400+truth(i-400),j);','pixel(i-400+truth(i-400),j-24);')
s=s.replace('PASS 400x480 RGB stereo scene,','PASS 24-row misaligned RGB scene after compensation,')
(r/'sim/tb_alignment_scene.v').write_text(s)
print('Created vertically shifted scene test')
