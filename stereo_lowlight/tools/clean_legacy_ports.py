from pathlib import Path
import re
p=Path(__file__).resolve().parents[1]/'rtl/ddr3_rw.v'
b=p.read_bytes().replace(b'\r\n',b'\n')
for name in ['app_addr','rfifo_wdata_1','rfifo_wdata_2','rfifo_wren_1','rfifo_wren_2']:
 b=re.sub(rb'(output\s+)(?!reg\b)((?:\[[^\]]+\]\s*)?)'+name.encode()+rb'\b',rb'\1reg \2'+name.encode(),b)
 b=re.sub(rb'^reg\s+(?:\[[^\]]+\]\s*)?'+name.encode()+rb'\s*;[^\n]*\n',b'',b,flags=re.M)
p.write_bytes(b)
print('Normalized legacy ANSI output declarations')
