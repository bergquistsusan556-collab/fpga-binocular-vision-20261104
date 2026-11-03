"""Reproducible vector target and companion intrinsic/stereo calibration grid."""
from pathlib import Path
import json,hashlib
import cv2
import numpy as np
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader

root=Path(__file__).resolve().parents[1]
out=root/'output/pdf';out.mkdir(parents=True,exist_ok=True)
assets=root/'calibration/target_v1';assets.mkdir(parents=True,exist_ok=True)
dictionary=cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
marker=cv2.aruco.generateImageMarker(dictionary,7,600)
cells=marker[50::100,50::100]//255
cv2.imwrite(str(assets/'marker_7.png'),marker)
pdfmetrics.registerFont(TTFont('TargetCN','C:/Windows/Fonts/simhei.ttf'))
pdf=out/'stereo_tracking_target_A4.pdf'
c=canvas.Canvas(str(pdf),pagesize=A4)
c.setTitle('双目目标跟踪靶标与标定板 / Target 07')
def text(x,y,s,size=10):
 c.setFont('TargetCN',size);c.drawString(x*mm,y*mm,s)
def matrix(data,x,y,size):
 h,w=data.shape
 for row in range(h):
  for col in range(w):
   if not data[row,col]:c.rect((x+col*size/w)*mm,(y+(h-1-row)*size/h)*mm,size/w*mm,size/h*mm,fill=1,stroke=0)
def ruler(y):
 c.setLineWidth(.5);c.line(55*mm,y*mm,155*mm,y*mm)
 for x in range(55,156,10):c.line(x*mm,(y-2)*mm,x*mm,(y+2)*mm)
 text(72,y-7,'校验线：实测应为100毫米',9)
text(20,282,'双目跟踪专用靶标 07',19)
text(20,273,'第1页：跟踪目标  |  A4纵向  |  按实际大小 / 100%打印',10)
matrix(cells,25,96,160)
text(25,82,'黑色外框边长160毫米；保持周围白边完整。',10)
# Independent high-frequency texture for stereo tests; does not alter marker bits.
texture=np.random.default_rng(7001).integers(0,2,(8,64),dtype=np.uint8)
for row in range(8):
 for col in range(64):
  if texture[row,col]==0:c.rect((25+col*2.5)*mm,(56+(7-row)*2.5)*mm,2.5*mm,2.5*mm,stroke=0,fill=1)
text(25,49,'下方为辅助匹配纹理，不要裁掉、涂改或折叠。',9)
text(20,38,'贴在平整硬板上；使用哑光纸，避免反光。不要选择“适应页面”。',10)
ruler(23)
text(20,7,'ArUco DICT_4X4_50 / ID 7  |  V1  |  屏幕显示请使用第1页并保留白边。',8)
c.showPage()
text(20,282,'双目标定辅助板',19)
text(20,272,'第2页：镜头与双目几何标定使用，不是跟踪目标。',10)
text(20,255,'9列 × 6行方格；每格20毫米；内部角点8列 × 5行。',11)
for row in range(6):
 for col in range(9):
  if (row+col)%2==0:c.rect((15+col*20)*mm,(110+(5-row)*20)*mm,20*mm,20*mm,stroke=0,fill=1)
text(20,94,'打印后量准方格，贴平；两颗摄像头应同时看到完整棋盘。',11)
text(20,80,'采集时会使用多个位置和倾角，摄像头之间的位置保持固定。',11)
text(20,66,'跟踪与测距的实际精度需要实测，本图案不代表已完成标定。',11)
text(20,47,'只需要准备跟踪目标时，打印第1页即可；建议同时保留本页。',10)
ruler(28)
text(20,8,'A4 210 × 297毫米  |  打印比例100%  |  禁止自动缩放',9)
c.save()
assert len(PdfReader(str(pdf)).pages)==2
for page in PdfReader(str(pdf)).pages:
 assert abs(float(page.mediabox.width)-A4[0])<.01
spec={'dictionary':'DICT_4X4_50','id':7,'marker_side_mm':160,'border_bits':1,
 'matrix_including_border':cells.tolist(),'board_squares':[9,6],'inner_corners':[8,5],
 'square_mm':20,'pdf_sha256':hashlib.sha256(pdf.read_bytes()).hexdigest(),
 'status':'reference target; new FPGA detector not yet deployed'}
(assets/'spec.json').write_text(json.dumps(spec,indent=2),encoding='utf-8')
print(pdf)
