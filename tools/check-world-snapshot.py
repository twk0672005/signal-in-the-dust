"""Run existing game regressions in a named isolated snapshot, without touching saves."""
from pathlib import Path
import argparse, json, os, subprocess, time

p=argparse.ArgumentParser();p.add_argument('--project',required=True,type=Path);p.add_argument('--output',required=True,type=Path);p.add_argument('--suites',nargs='+');a=p.parse_args()
engine='C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe'
a.output.mkdir(parents=True,exist_ok=True)
rows=[]
for suite in a.suites or ['physics_camera_regression','interaction_regression','ecology_regression','save_resume_regression','save_flow_regression','activity_logic_runner','thermal_checks','wetland_checks']:
    if not suite.replace('_','').isalnum() or not (a.project/'tests'/f'{suite}.gd').is_file():
        raise SystemExit('Select an existing project test: '+suite)
    out=a.output/suite;out.mkdir(exist_ok=True);started=time.time()
    command=[engine,'--headless','--path',str(a.project.resolve()),'--script',f'res://tests/{suite}.gd','--','--evidence-dir='+str(out.resolve())]
    with (out/'output.log').open('w',encoding='utf-8') as log:
        try:r=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=120,env={**os.environ,'APPDATA':str((a.output/'native-userdata').resolve())});code=r.returncode
        except subprocess.TimeoutExpired:code=-1
    log=(out/'output.log').read_text(encoding='utf-8');errors=[line for line in log.splitlines() if any(x in line for x in ['ERROR:','Parse Error','Assertion failed'])]
    expected=[line for line in errors if suite=='save_flow_regression' and 'ERROR: Failed to open' in line and str(out.resolve()).replace('\\','/') in line.replace('\\','/') and 'copy-failure-' in line and '.json.bak' in line and '"backup_failure_keeps_primary":true' in log.replace(' ','')]
    confirmed='"passed":true' in log.replace(' ','')
    if suite=='journal_checks' and (out/'journal.json').is_file():
        confirmed=json.loads((out/'journal.json').read_text(encoding='utf-8')).get('passed') is True
    row={'suite':suite,'exitCode':code,'seconds':time.time()-started,'errors':[line for line in errors if line not in expected],'expectedErrors':expected,'passed':code==0 and len(errors)==len(expected) and confirmed};rows.append(row)
    (a.output/'receipt.json').write_text(json.dumps({'project':str(a.project.resolve()),'checks':rows,'passed':all(x['passed'] for x in rows)},indent=2),encoding='utf-8')
    print(json.dumps(row),flush=True)
raise SystemExit(0 if all(x['passed'] for x in rows) else 1)
