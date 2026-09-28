"""Sequential native probe runner; immutable source copies and exact logs."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'evidence/visual-upgrade-20260923/engine-specimen-probe'
PROJECT=OUT/'project'
ENGINE=Path('C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe')
parser=argparse.ArgumentParser();parser.add_argument('--kind',choices=['aeral','canopy','sails'],required=True)
args=parser.parse_args()
PROJECT.mkdir(parents=True,exist_ok=True)
if args.kind!='aeral':
    expected={'canopy':'bda00bda4e0992c2438f3f29b27be70b77080d556b53abb27ab27e9e2e3d9fe9','sails':'4dd0f8dd90fbc38f13c8315661da34ac2d6caeaa1a0171b9f732a5bc06ea1365'}[args.kind]
    source=ROOT/f'godot/assets/visual_flora/revision-b/{args.kind}.glb'
    assert hashlib.sha256(source.read_bytes()).hexdigest()==expected
    shutil.copy2(source,PROJECT/f'{args.kind}-b-probe.glb')
    data=source.read_bytes();length=int.from_bytes(data[12:16],'little');doc=json.loads(data[20:20+length])
    assert not any(image.get('uri') for image in doc.get('images',[])), 'External images need explicit scoped copy'
shutil.copy2(ROOT/'tools/engine_specimen_probe.gd',PROJECT/'probe.gd')
(PROJECT/'project.godot').write_text('''config_version=5
[application]
config/name="Immutable specimen import probe"
config/features=PackedStringArray("4.7", "GL Compatibility")
[display]
window/size/viewport_width=1440
window/size/viewport_height=1000
[rendering]
renderer/rendering_method="gl_compatibility"
''',encoding='utf-8')
evidence=OUT/args.kind;evidence.mkdir(parents=True,exist_ok=True)
commands=[['--headless','--path',str(PROJECT),'--editor','--import','--quit'],['--path',str(PROJECT),'--resolution','1440x1000','--script','res://probe.gd','--',f'--kind={args.kind}',f'--evidence-dir={evidence}']]
results=[]
for stage,arguments in zip(['import','graphical'],commands):
    result=subprocess.run([str(ENGINE),*arguments],capture_output=True,timeout=90)
    (evidence/f'{stage}.stdout.log').write_bytes(result.stdout)
    (evidence/f'{stage}.stderr.log').write_bytes(result.stderr)
    results.append({'stage':stage,'args':arguments,'exitCode':result.returncode})
    if result.returncode:
        print(result.stdout.decode('utf-8','replace')[-2000:]);print(result.stderr.decode('utf-8','replace')[-2000:]);break
asset=PROJECT/('aeral-v9-probe.glb' if args.kind=='aeral' else f'{args.kind}-b-probe.glb')
receipt={'kind':'native_single_specimen_import_probe','specimen':args.kind,'asset':str(asset),'assetSha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'scriptSha256':hashlib.sha256((PROJECT/'probe.gd').read_bytes()).hexdigest(),'commands':results,'reportExists':(evidence/'native-probe.json').is_file(),'visualAcceptance':False}
(evidence/'runner.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(receipt,indent=2))
raise SystemExit(0 if all(r['exitCode']==0 for r in results) and receipt['reportExists'] else 1)
