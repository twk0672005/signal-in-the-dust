"""Root-owned snapshot/export. Keeps prior artifacts and binds source to Web bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--source', required=True, type=Path)
parser.add_argument('--destination', required=True, type=Path)
parser.add_argument('--baseline-adapter', type=Path)
args = parser.parse_args()
source = args.source.resolve()
destination = args.destination.resolve()
project_root = Path(__file__).resolve().parents[1]
if project_root not in destination.parents or destination.exists():
    raise SystemExit('Destination must be a new directory under the current worktree.')
engine = Path('C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe')
destination.mkdir(parents=True)
snapshot = destination / 'candidate-project' / 'godot'
shutil.copytree(source / 'godot', snapshot, ignore=shutil.ignore_patterns('build', 'evidence'))
if args.baseline_adapter:
    # Same adapter in both builds; no world, renderer, creature or player changes.
    shutil.copy2(args.baseline_adapter / 'godot/scripts/world_review.gd', snapshot / 'scripts/world_review.gd')
    main = snapshot / 'scripts/main.gd'
    text = main.read_text(encoding='utf-8')
    if 'const WorldReview = ' not in text:
        text = text.replace('const ShowcaseBoot = preload("res://scripts/showcase_boot.gd")', 'const ShowcaseBoot = preload("res://scripts/showcase_boot.gd")\nconst WorldReview = preload("res://scripts/world_review.gd")')
        text = text.replace('func _ready() -> void:\n', 'func _ready() -> void:\n\tvar local_review := WorldReview.enabled_in_browser()\n\tif local_review: save_path = "user://world-review-expedition.json"\n', 1)
        text = text.replace('\t_install_web_launch()\n', '\t_install_web_launch()\n\tif local_review:\n\t\tvar review := WorldReview.new()\n\t\tadd_child(review)\n\t\treview.setup(self)\n', 1)
    main.write_text(text, encoding='utf-8')

web = destination / 'web'
web.mkdir()
receipt = {'source': str(source), 'snapshot': str(snapshot), 'startedAt': time.time(), 'baselineAdapterOnly': bool(args.baseline_adapter), 'commands': []}
for stage, command in [('version', ['--version']), ('import', ['--headless', '--path', str(snapshot), '--editor', '--import', '--quit']), ('export', ['--headless', '--path', str(snapshot), '--export-release', 'Web', str(web / 'index.html')])]:
    started = time.time()
    with (destination / (stage + '.log')).open('w', encoding='utf-8') as log:
        try:
            result = subprocess.run([str(engine), *command], stdout=log, stderr=subprocess.STDOUT, timeout=300)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = -1
    receipt['commands'].append({'stage': stage, 'exitCode': code, 'seconds': time.time()-started})
    (destination / 'build-receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    log_text = (destination / (stage + '.log')).read_text(encoding='utf-8')
    if code != 0 or 'SCRIPT ERROR:' in log_text or 'Parse Error:' in log_text or 'ERROR: Failed' in log_text:
        raise SystemExit('Stage failed: ' + stage)
for name in ['showcase.css', 'showcase.js']:
    shutil.copy2(snapshot / 'web' / name, web / name)
shutil.copytree(snapshot / 'web/assets', web / 'assets', ignore=shutil.ignore_patterns('*.import'))
subprocess.run(['node', str(project_root / 'tools/finalize-web-release.mjs'), str(web)], check=True)

def manifest(folder):
    return [{'path': p.relative_to(folder).as_posix(), 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in sorted(folder.rglob('*')) if p.is_file() and not any(part in ['.godot', 'build', 'evidence'] for part in p.relative_to(folder).parts)]

receipt.update({'completedAt': time.time(), 'sourceFiles': manifest(snapshot), 'webFiles': manifest(web),
                'release': json.loads((web / 'release-manifest.json').read_text(encoding='utf-8')),
                'rendering': 'Godot 4.7.2 Compatibility single-thread Web'})
(destination / 'build-receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
print(json.dumps({'artifact': str(web), 'files': len(receipt['webFiles']), 'bytes': sum(item['bytes'] for item in receipt['webFiles']), 'seconds': time.time()-receipt['startedAt']}))
