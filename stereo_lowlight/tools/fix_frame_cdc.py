from pathlib import Path
p=Path(__file__).resolve().parents[1]/'rtl/ddr3_rw.v'
b=p.read_bytes().replace(b'\r\n',b'\n')
for name in ['rd_load','wr_load_1','wr_load_2']:
 a=f'reg           {name}_d0;'.encode()
 if a in b:
  b=b.replace(a,f'(* ASYNC_REG="TRUE" *) reg {name}_d0;\n(* ASYNC_REG="TRUE" *) reg {name}_d2;'.encode())
 a=f'reg           {name}_d1;'.encode()
 b=b.replace(a,f'(* ASYNC_REG="TRUE" *) reg {name}_d1;'.encode())
 a=f'{name}_d1 <= 0;'.encode()
 b=b.replace(a,f'{name}_d1 <= 0;\n        {name}_d2 <= 0;'.encode())
 a=f'{name}_d1 <= {name}_d0;'.encode()
 b=b.replace(a,f'{name}_d1 <= {name}_d0;\n        {name}_d2 <= {name}_d1;'.encode())
 a=f'{name}_d0 && !{name}_d1'.encode()
 b=b.replace(a,f'{name}_d1 && !{name}_d2'.encode())
p.write_bytes(b)
print('Frame events use settled two-stage CDC before edge detection')
