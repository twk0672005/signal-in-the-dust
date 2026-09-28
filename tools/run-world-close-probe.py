"""Root-owned isolated actual-render material probe using the existing view fixture."""
import argparse, json, shutil, subprocess, time
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);a=p.parse_args()
root=Path(__file__).resolve().parents[1];out=a.output.resolve()
if root not in out.parents or out.exists():raise SystemExit('A new worktree-local output is required')
project=out/'project';out.mkdir(parents=True)
shutil.copytree(root/'godot',project,ignore=shutil.ignore_patterns('build','evidence'))
shutil.copy2(root/'evidence/world-upgrade-20260926/world-art/world_environment_close.gd',project/'tests/world_environment_close.gd')
engine='C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe'
rows=[]
for name,args in [('import',['--headless','--path',str(project),'--editor','--import','--quit']),('close',['--path',str(project),'--script','res://tests/world_environment_close.gd','--resolution','1280x720','--','--evidence-dir='+str(out/'views')])]:
    started=time.time()
    with (out/(name+'.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run([engine,*args],stdout=log,stderr=subprocess.STDOUT,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
    errors=[line for line in (out/(name+'.log')).read_text(encoding='utf-8').splitlines() if 'ERROR' in line or 'Shader compilation failed' in line]
    rows.append({'stage':name,'exit':result.returncode,'seconds':time.time()-started,'errors':errors})
    (out/'receipt.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows[-1]),flush=True)
    if result.returncode or errors:raise SystemExit(1)
