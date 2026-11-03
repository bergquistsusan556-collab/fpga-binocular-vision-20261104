"""Prepare an isolated tracking build; preserve the user's accepted range model."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
variant = root / 'variants/target_follow_20261103'
(variant / 'rtl').mkdir(parents=True, exist_ok=True)
(variant / 'sim').mkdir(exist_ok=True)
base = root / 'variants/front_fit_20261103/rtl'
for name in ['stereo_census.v', 'depth_roi.v']:
    (variant / 'rtl' / name).write_bytes((base / name).read_bytes())

roi = (base / 'depth_roi.v').read_text(encoding='utf-8')
roi = roi.replace('module depth_roi #(', 'module depth_roi_follow #(')
roi = roi.replace('output reg [63:0] diagnostic\n',
    'output reg [63:0] diagnostic,\n input wire roi_enable,\n'
    ' input wire [10:0] roi_cx,roi_cy,\n input wire [5:0] roi_rx,roi_ry,\n output reg [33:0] measured_roi\n')
roi = roi.replace('wire [10:0] cx=width>>2,cy=height>>1;\n wire roi=(x+20>=cx)&&(x<=cx+20)&&(y+20>=cy)&&(y<=cy+20);',
    'reg [10:0] cx,cy,completed_cx,completed_cy; reg [5:0] rx,ry,completed_rx,completed_ry; reg frame_enable,completed_enable;\n'
    ' wire roi=frame_enable&&roi_enable&&(x+rx>=cx)&&(x<=cx+rx)&&(y+ry>=cy)&&(y<=cy+ry);')
roi = roi.replace('if(!rst_n)begin\n', 'if(!rst_n)begin\n   cx<=0;cy<=0;rx<=0;ry<=0;frame_enable<=0;\n   completed_cx<=0;completed_cy<=0;completed_rx<=0;completed_ry<=0;completed_enable<=0;measured_roi<=0;\n', 1)
roi = roi.replace('if(sof)begin pos<=0;',
    'if(sof)begin completed_cx<=cx;completed_cy<=cy;completed_rx<=rx;completed_ry<=ry;completed_enable<=frame_enable;cx<=roi_cx;cy<=roi_cy;rx<=roi_rx;ry<=roi_ry;frame_enable<=roi_enable;pos<=0;')
roi = roi.replace('if(samples>=MIN_SAMPLES&&peak>=MIN_SAMPLES&&',
    'if(completed_enable&&roi_enable&&samples>=MIN_SAMPLES&&peak>=MIN_SAMPLES&&')
roi = roi.replace('distance_valid<=(rounded_distance>=25&&rounded_distance<=250);',
    'distance_valid<=completed_enable&&roi_enable&&(rounded_distance>=25&&rounded_distance<=250);')
roi=roi.replace('distance_cm<=rounded_distance[15:0];state<=0;',
    'distance_cm<=rounded_distance[15:0];measured_roi<={completed_rx,completed_ry,completed_cx,completed_cy};state<=0;')
roi = roi.replace('endcase\n  end\n',
    'endcase\n   if(!roi_enable)begin distance_valid<=0;distance_cm<=0;end\n  end\n')
assert 'reg [10:0] cx,cy' in roi and 'roi_enable' in roi
(variant / 'rtl/depth_roi_follow.v').write_text(roi, encoding='utf-8')

video = (root / 'rtl/video_tools.v').read_text(encoding='utf-8')
video = video.replace('output reg [15:0] processed\n',
    'output reg [15:0] processed,\n output wire target_valid,\n'
    ' output wire [7:0] target_x,target_y,target_w,target_h,\n'
    ' output wire [1:0] target_rotation,\n output wire [7:0] target_epoch,\n'
    ' input wire raw_de,\n input wire [10:0] raw_x,raw_y,\n input wire [7:0] raw_lum\n')
start = video.index(' wire template_valid,template_ready;')
end = video.index(' always @* begin', start)
video = video[:start] + ''' wire detector_ready;
 reg [7:0] threshold,minimum,maximum;
 wire [8:0] extrema_sum={1'b0,minimum}+{1'b0,maximum};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin threshold<=128;minimum<=255;maximum<=0;end
  else if(sof)begin
   if(maximum>=minimum+9'd16)threshold<=extrema_sum[8:1];
   minimum<=255;maximum<=0;
  end else if(raw_de&&raw_x>=400&&raw_x<800&&raw_y<480)begin
   if(raw_lum<minimum)minimum<=raw_lum;
   if(raw_lum>maximum)maximum<=raw_lum;
  end
 end
 marker7_tracker matcher(clk,rst_n,sof,raw_de,raw_x,raw_y,raw_lum>=threshold,mode==7,
   detector_ready,target_valid,target_x,target_y,target_w,target_h,target_rotation,target_epoch);
 wire [10:0] bx=400+{target_x,1'b0},by={target_y,1'b0};
 wire [10:0] bw={target_w,1'b0},bh={target_h,1'b0};
 wire outline=target_valid &&
   (((xx==bx||xx+1==bx+bw)&&(yy>=by&&yy<by+bh)) ||
    ((yy==by||yy+1==by+bh)&&(xx>=bx&&xx<bx+bw)));
''' + video[end:]
start = video.index('      // Yellow: fixed acquisition area.')
end = video.index('    end\n   endcase', start)
video = video[:start] + '''      // The printed ID7 marker is acquired anywhere in the right view.
      if(outline)processed=16'h07e0;
      if(xx>=404&&xx<416&&yy>=44&&yy<56)processed=target_valid?16'h07e0:16'hffe0;
''' + video[end:]
(variant / 'rtl/video_tools.v').write_text(video, encoding='utf-8')

pipeline = (root / 'rtl/fusion_pipeline.v').read_text(encoding='utf-8')
pipeline=pipeline.replace('stereo_row_align align(clk,rst_n,fv,fx,fy,width,code,tex,alignment_control,',
  'wire [7:0] effective_alignment;wire alignment_ready,alignment_busy;wire [4:0] alignment_row;\n'
  ' stereo_row_align align(clk,rst_n,fv,fx,fy,width,code,tex,effective_alignment,')
start = pipeline.index(' depth_roi roi(')
end = pipeline.index(' wire [6:0] sample;', start)
pipeline = pipeline[:start] + ''' wire target_valid; wire [7:0] tx,ty,tw,th,tepoch; wire [1:0] trot;
 wire following=mode==7;
 // Tag-to-texture offset comes from the unchanged printed PDF geometry.
 wire [11:0] tx2={3'd0,tx,1'b0},ty2={3'd0,ty,1'b0};
 wire [11:0] tw2={3'd0,tw,1'b0},th2={3'd0,th,1'b0};
 wire [11:0] tail_x=(tw2*3)>>4,tail_y=(th2*3)>>4;
 wire [11:0] follow_cx=trot==1?tx2-tail_x:trot==3?tx2+tw2+tail_x:tx2+(tw2>>1);
 wire [11:0] follow_cy=trot==2?ty2-tail_y:trot==0?ty2+th2+tail_y:ty2+(th2>>1);
 wire [7:0] long_half=((trot[0]?th:tw)*3)>>2;
 wire [7:0] short_half=((trot[0]?tw:th)*3)>>5;
 wire [5:0] follow_rx=trot[0]?(short_half<1?1:short_half>20?20:short_half):
                                      (long_half<4?4:long_half>40?40:long_half);
 wire [5:0] follow_ry=trot[0]?(long_half<4?4:long_half>40?40:long_half):
                                      (short_half<1?1:short_half>20?20:short_half);
 wire follow_roi_ok=target_valid&&follow_cx>=follow_rx&&follow_cy>=follow_ry&&
   follow_cx+follow_rx<width/2&&follow_cy+follow_ry<height;
 wire [10:0] rcx=following?follow_cx[10:0]:width>>2;
 wire [10:0] rcy=following?follow_cy[10:0]:height>>1;
 wire [5:0] rrx=following?follow_rx:6'd20,rry=following?follow_ry:6'd20;
 wire [15:0] roi_cm;wire roi_valid;wire [33:0] measured_roi;
 depth_roi_follow roi(clk,rst_n,sof,match_de,match_valid,mx,my,width,height,
   match_disp,scale,roi_cm,roi_valid,dominant,diagnostic_roi,
   !following||follow_roi_ok,rcx,rcy,rrx,rry,measured_roi);
 assign distance_cm=following&&!follow_roi_ok?16'd0:roi_cm;
 // A completed sample must still belong to the current target's texture band.
 // Allow bbox jitter only while its entire measured rectangle remains inside it.
 wire [11:0] texture_rx=trot[0]?(tw2>>4):(tw2>>1);
 wire [11:0] texture_ry=trot[0]?(th2>>1):(th2>>4);
 wire [11:0] measured_cx={1'b0,measured_roi[21:11]},measured_cy={1'b0,measured_roi[10:0]};
 wire [11:0] delta_x=measured_cx>=follow_cx?measured_cx-follow_cx:follow_cx-measured_cx;
 wire [11:0] delta_y=measured_cy>=follow_cy?measured_cy-follow_cy:follow_cy-measured_cy;
 wire position_consistent=following?
   (delta_x+measured_roi[33:28]<=texture_rx&&delta_y+measured_roi[27:22]<=texture_ry):
   (measured_roi=={rrx,rry,rcx,rcy});
 follow_row_tuner row_tuner(clk,rst_n,sof,following&&alignment_control[7],alignment_control,
   target_valid,follow_roi_ok,position_consistent,roi_valid,diagnostic_roi,
   effective_alignment,alignment_ready,alignment_busy,alignment_row);
 assign distance_valid=roi_valid&&position_consistent&&(!following||(follow_roi_ok&&alignment_ready));
 (* MARK_DEBUG="TRUE",KEEP="TRUE" *) wire [63:0] tracking_diagnostic;
 assign tracking_diagnostic={2'd0,roi_valid,position_consistent,follow_roi_ok,trot,following,tepoch,th,tw,ty,tx,alignment_ready,alignment_busy,alignment_row,target_valid};
''' + pipeline[end:]
pipeline = pipeline.replace('mode,tools_rgb);', 'mode,tools_rgb,target_valid,tx,ty,tw,th,trot,tepoch,fv,fx,fy,lum);')
pipeline = pipeline.replace(' // Distance is tied to the fixed stereo ROI, not the template\'s green box.\n   out_rgb=(osd_on&&mode_d<3)?osd_rgb:base;',
'''   if(mode_d==7&&follow_roi_ok)begin
     if((((out_x+rrx==400+rcx)||(out_x==400+rcx+rrx))&&(out_y+rry>=rcy&&out_y<=rcy+rry))||
        (((out_y+rry==rcy)||(out_y==rcy+rry))&&(out_x+rrx>=400+rcx&&out_x<=400+rcx+rrx)))base=16'hffff;
   end
   out_rgb=(osd_on&&(mode_d<3||mode_d==7))?osd_rgb:base;''')
assert 'depth_roi_follow roi' in pipeline and 'tracking_diagnostic' in pipeline
(variant / 'rtl/fusion_pipeline.v').write_text(pipeline, encoding='utf-8')
top = (root / 'rtl/top_dual_ov5640_lcd.v').read_bytes()
assert top.count(b'mode_50m <= 3\'d1;') == 1
(variant / 'rtl/top_dual_ov5640_lcd.v').write_bytes(top.replace(b'mode_50m <= 3\'d1;', b'mode_50m <= 3\'d7;'))

build = (root / 'tools/build_front_fit.tcl').read_text(encoding='utf-8')
build = build.replace('front_fit_20261103', 'target_follow_20261103')
build = build.replace('set skip {', 'set skip {video_tools.v fusion_pipeline.v top_dual_ov5640_lcd.v ')
build = build.replace('implement_front_fit.tcl', 'implement_target_follow.tcl')
build=build.replace('read_ip [file join $out generated_ip stereo_control stereo_control.xci]',
                    'read_ip [list [file join $out generated_ip stereo_control stereo_control.xci]]')
(root / 'tools/build_target_follow.tcl').write_text(build, encoding='utf-8')
impl = (root / 'tools/implement_front_fit.tcl').read_text(encoding='utf-8')
impl = impl.replace('set diagnostic_width 320','set diagnostic_width 288')
old_loop='for {set i 0} {$i<$diagnostic_width} {incr i} {lappend probes [get_nets [format {diagnostic_bus[%d]} [expr {$i<256?$i:$i+128}]]]}\n'
new_loop='''for {set i 0} {$i<$diagnostic_width} {incr i} {
 if {$i<72} {set name [format {diagnostic_bus[%d]} $i]} elseif {$i<112} {
  set name [format {diagnostic_bus[%d]} [expr {$i+32}]]
 } elseif {$i<136} {set name [format {diagnostic_bus[%d]} [expr {$i+96}]]} elseif {$i<200} {
  set name [format {diagnostic_bus[%d]} [expr {$i+248}]]
 } elseif {$i<256} {set name [format {u_lcd_rgb_top/pipeline/tracking_diagnostic[%d]} [expr {$i-200}]]
 } else {set name [format {diagnostic_bus[%d]} [expr {$i+192}]]}
 lappend probes [get_nets $name]
}
'''
assert old_loop in impl
impl=impl.replace(old_loop,new_loop)
(root / 'tools/implement_target_follow.tcl').write_text(impl, encoding='utf-8')
manifest = {'variant':'target_follow_20261103', 'range_model':'unchanged front_fit_20261103',
 'user_report':'User reports current distance is accurate; now requests target following',
 'production_rtl_sha256':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((root/'rtl').glob('*.v'))},
 'overrides_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((variant/'rtl').glob('*.v'))}}
(variant/'source_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(variant)
