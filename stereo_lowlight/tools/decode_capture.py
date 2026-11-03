from pathlib import Path
import csv,json,sys
root=Path(__file__).resolve().parents[1]
fields=[('flags',0,8),('chip1',8,16),('chip2',24,16),('lcd',40,16),
 ('frame1_gray',56,8),('frame2_gray',64,8),('pclk1_gray',72,16),('pclk2_gray',88,16),
 ('pixels1',104,20),('pixels2',124,20),('hash1',144,16),('hash2',160,16),
 ('read_hash',176,16),('ticks_hi',192,16),('ddr_state',208,7),('ddr_addr',215,28)]
def ungray(v):
 b=v
 while v:
  v>>=1;b^=v
 return b
results=[]
folder=root/'build'/(sys.argv[1] if len(sys.argv)>1 else 'diagnostic')
for p in sorted(folder.glob('capture_*.csv'),key=lambda p:int(p.stem.rsplit('_',1)[1])):
 rows=list(csv.reader(p.open()))[2:]
 vals=[int(r[-1],16) for r in rows if r]
 if not vals:continue
 d={n:(vals[0]>>offset)&((1<<bits)-1) for n,offset,bits in fields}
 for n in ['frame1_gray','frame2_gray','pclk1_gray','pclk2_gray']:d[n.replace('_gray','')]=ungray(d[n])
 d['file']=p.name
 d['pclk1_edges_in_window']=(ungray((vals[-1]>>72)&65535)-d['pclk1'])&65535
 d['pclk2_edges_in_window']=(ungray((vals[-1]>>88)&65535)-d['pclk2'])&65535
 d['camera1_mhz']=round(d['pclk1_edges_in_window']/((len(vals)-1)/50),3)
 d['camera2_mhz']=round(d['pclk2_edges_in_window']/((len(vals)-1)/50),3)
 if ('fusion' in folder.parts or vals[0].bit_length()>384) and vals[0].bit_length()>256:
  def bits(offset,n):return (vals[0]>>offset)&((1<<n)-1)
  for n in ('ddr_state','ddr_addr'):d.pop(n,None)
  d.update({'dominant_disparity':bits(208,6),'distance_cm':bits(214,16),
   'distance_valid':bool(bits(230,1)),'display_mode':bits(231,2),
   'aec_target1':bits(233,8),'aec_target2':bits(241,8),
   'aec_manual1':bits(249,2),'aec_manual2':bits(251,2),
   'raw_luminance_sum':bits(256,27),'enhanced_luminance_sum':bits(283,27),
   'display_pixels':bits(310,20),'valid_matches':bits(330,18),
   'display_frame_mod16':bits(348,4),'sensor_average1':bits(352,8),'sensor_average2':bits(360,8),
   'sensor_gain1_x':bits(368,8)/16,'sensor_gain2_x':bits(376,8)/16})
  if d['display_pixels']:
   d['raw_mean']=round(d['raw_luminance_sum']/d['display_pixels'],3)
   d['enhanced_mean']=round(d['enhanced_luminance_sum']/d['display_pixels'],3)
  if vals[0].bit_length()>384:
   d.update({'roi_reason':bits(384,4),'roi_population':bits(388,12),
    'roi_cluster_samples':bits(400,12),'roi_peak':bits(412,12),
    'roi_weighted_disparity':bits(424,20),'search_reverse':bool(bits(444,1))})
 if folder.name=='brightness':
  for camera,offset in [(1,256),(2,320)]:
   raw=(vals[0]>>offset)&((1<<64)-1)
   b=[(raw>>(8*j))&255 for j in range(8)]
   d[f'sensor{camera}']={'manual_control':b[0],
    'exposure_lines':(((b[1]&15)<<16)|(b[2]<<8)|b[3])/16,
    'gain_x':(((b[4]&3)<<8)|b[5])/16,
    'average_luminance':b[6],'target_high':b[7], 'register_bytes':b}
 if 'video_fusion' in folder.parts:
  def bits(offset,n):return (vals[0]>>offset)&((1<<n)-1)
  for n in ('ddr_state','ddr_addr'):d.pop(n,None)
  d.update({'dominant_disparity':bits(208,6),'distance_cm':bits(214,16),
   'distance_valid':bool(bits(230,1)),'display_mode_low2':bits(231,2),
   'aec_target1':bits(233,8),'aec_target2':bits(241,8),
   'aec_manual1':bits(249,2),'aec_manual2':bits(251,2),
   'probe_layout':'compact256; mode high bit and enhanced metrics unavailable'})
 results.append(d)
print(json.dumps(results,indent=2))
(folder/'decoded.json').write_text(json.dumps(results,indent=2))
