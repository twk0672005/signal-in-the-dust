"""Run existing game regressions in a named isolated snapshot, without touching saves."""
from pathlib import Path
import argparse, json, subprocess, time

p=argparse.ArgumentParser();p.add_argument('--project',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
engine='C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe'
a.output.mkdir(parents=True,exist_ok=True)
rows=[]
for suite in ['physics_camera_regression','interaction_regression','ecology_regression','save_resume_regression','save_flow_regression','activity_logic_runner','thermal_checks','wetland_checks']:
    out=a.output/suite;out.mkdir(exist_ok=True);started=time.time()
    command=[engine,'--headless','--path',str(a.project.resolve()),'--script',f'res://tests/{suite}.gd','--','--evidence-dir='+str(out.resolve())]
    with (out/'output.log').open('w',encoding='utf-8') as log:
        try:r=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=120);code=r.returncode
        except subprocess.TimeoutExpired:code=-1
    log=(out/'output.log').read_text(encoding='utf-8');errors=[line for line in log.splitlines() if any(x in line for x in ['SCRIPT ERROR','Parse Error','Assertion failed'])]
    row={'suite':suite,'exitCode':code,'seconds':time.time()-started,'errors':errors,'passed':code==0 and not errors};rows.append(row)
    (a.output/'receipt.json').write_text(json.dumps({'project':str(a.project.resolve()),'checks':rows,'passed':all(x['passed'] for x in rows)},indent=2),encoding='utf-8')
    print(json.dumps(row),flush=True)
raise SystemExit(0 if all(x['passed'] for x in rows) else 1)
