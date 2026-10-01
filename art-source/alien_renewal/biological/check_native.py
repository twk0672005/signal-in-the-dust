"""CPU-only fixture. Imports only an evidence-local project, never the live cache."""
import hashlib, json, os, shutil, subprocess, time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
SOURCE=Path(__file__).resolve().parent
EVID=ROOT/'evidence/alien-renewal-20260930T200644Z/biological'
PROJECT=EVID/'native-project'
ENGINE=Path('C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe')
files=['scripts/creature_visual.gd','scripts/rover.gd','shaders/bioceramic.gdshader','shaders/creature_previous.gdshader','shaders/creature_authored_factors.gdshader',
       'assets/visual_fauna/veyra_runtime.glb','assets/visual_fauna/morrow_runtime.glb','assets/visual_fauna/aeral_runtime.glb','assets/models/rover.glb']
for name in files:
    target=PROJECT/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'godot'/name,target)
shutil.copytree(ROOT/'godot/assets/visual_fauna/surface_maps',PROJECT/'assets/visual_fauna/surface_maps',dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.import'))
shutil.copy2(SOURCE/'probe.gd',PROJECT/'probe.gd')
(PROJECT/'project.godot').write_text('''config_version=5
[application]
config/name="Listening Reefs isolated biological checks"
config/features=PackedStringArray("4.7", "GL Compatibility")
[rendering]
renderer/rendering_method="gl_compatibility"
''',encoding='utf-8')
env=os.environ.copy();env['APPDATA']=str(EVID/'appdata/native');Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
stages=[]
for label,args in [('import',['--headless','--path',str(PROJECT),'--editor','--import','--quit']),
                   ('probe',['--headless','--path',str(PROJECT),'--script','res://probe.gd','--',f'--evidence-dir={EVID}'])]:
    start=time.time()
    with (EVID/f'native-{label}.log').open('w',encoding='utf-8') as log:
        result=subprocess.run([str(ENGINE),*args],stdout=log,stderr=subprocess.STDOUT,env=env,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
    text=(EVID/f'native-{label}.log').read_text(encoding='utf-8')
    errors=[line for line in text.splitlines() if 'ERROR' in line or 'Shader compilation failed' in line]
    stages.append({'stage':label,'exit':result.returncode,'seconds':time.time()-start,'errors':errors})
    print(json.dumps(stages[-1]),flush=True)
    if result.returncode or errors:break
receipt={'passed':all(s['exit']==0 and not s['errors'] for s in stages) and len(stages)==2,
         'engine':str(ENGINE),'project':str(PROJECT),'stages':stages,'visual_acceptance':False,
         'probe_sha256':hashlib.sha256((SOURCE/'probe.gd').read_bytes()).hexdigest(),
         'source_hashes':{name:hashlib.sha256((ROOT/'godot'/name).read_bytes()).hexdigest() for name in files}}
(EVID/'native-runner.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
raise SystemExit(0 if receipt['passed'] else 1)
