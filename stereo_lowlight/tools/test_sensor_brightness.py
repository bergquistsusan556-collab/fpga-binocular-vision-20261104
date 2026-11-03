from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
bin_dir=Path(r'C:\Xilinx\Vivado\2019.1\bin')
sim=root/'sim'
top='tb_sensor_brightness'
commands=[('xvlog',[str(root/'variants/brightness/rtl/i2c_ov5640_rgb565_cfg.v'),str(sim/(top+'.v'))]),
          ('xelab',[top,'-s',top+'_sim','-timescale','1ns/1ps']),
          ('xsim',[top+'_sim','-runall'])]
for name,args in commands:
    p=subprocess.run([str(bin_dir/(name+'.bat')),*args],cwd=sim,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    log=p.stdout.decode('utf-8',errors='replace')
    (sim/f'{top}_{name}.log').write_text(log,encoding='utf-8')
    if p.returncode or 'FATAL' in log.upper() or 'ERROR:' in log:
        raise SystemExit(log)
    if name=='xsim':
        if 'PASS sensor:' not in log:raise SystemExit(log)
        print(next(line for line in log.splitlines() if 'PASS sensor:' in line))
