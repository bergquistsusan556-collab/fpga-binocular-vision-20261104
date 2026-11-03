"""Independent arithmetic vectors, exhaustive RGB565 plus varied illumination/history."""
from pathlib import Path
import random,json
root=Path(__file__).resolve().parents[1]
rng=random.Random(5640)
def expand(p):
    r=(p>>11)&31;g=(p>>5)&63;b=p&31
    return (r<<3)|(r>>2),(g<<2)|(g>>4),(b<<3)|(b>>2)
def lum(p):
    r,g,b=expand(p);return (77*r+150*g+29*b)//256
def reference(p,s,w,h):
    r,g,b=expand(p);y=lum(p)
    reciprocal=round(4096/w)
    illumination=min(255,(s*reciprocal)//4096)
    gain=min(1024,round(256*(255/max(1,illumination))**0.6))
    boost=min(255,(y*gain)//256)
    # CDF must not reduce brightness: histogram is used for extra shadow detail.
    yy=boost if y<4 else max(boost,(7*boost+h)//8)
    cb=(-43*r-85*g+128*b)//256;cr=(128*r-107*g-21*b)//256
    clip=lambda v:max(0,min(255,v))
    rr=clip(yy+(359*cr)//256)
    gg=clip(yy-(88*cb+183*cr)//256)
    bb=clip(yy+(454*cb)//256)
    return ((rr>>3)<<11)|((gg>>2)<<5)|(bb>>3)
rows=[]
for p in range(65536):
    y=lum(p);rows.append((p,y,y*4,4,y,reference(p,y*4,4,y)))
for i in range(8192):
    p=rng.randrange(65536);y=lum(p);w=rng.randrange(4,13)
    s=rng.randrange(255*w+1);h=rng.randrange(256)
    rows.append((p,y,s,w,h,reference(p,s,w,h)))
path=root/'sim/lowlight_reference.txt'
path.write_text(''.join(f'{p:04x} {y:02x} {s:03x} {w:x} {h:02x} {o:04x}\n' for p,y,s,w,h,o in rows))
(root/'sim/reference_summary.json').write_text(json.dumps({'seed':5640,'exhaustive_rgb565':65536,'varied_illumination':8192,'total':len(rows)},indent=2))
print(f'Generated {len(rows)} independent enhancement vectors')
