"""Freeze a new native entry around the exact verified game. No import/export/save writes."""
import argparse,hashlib,json,os,re,shutil,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--destination',required=True,type=Path);a=p.parse_args()
root=Path(__file__).resolve().parents[1];dest=a.destination.resolve();assert root in dest.parents and not dest.exists();web=dest/'web';web.mkdir(parents=True)
source=root/'godot/web';parent=root/'out';game=json.loads((parent/'release-manifest.json').read_text(encoding='utf-8'))
hashfile=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
# All older immutable dependencies are reused as bytes, not regenerated or edited.
for row in game['publishFiles']:
 if row['path']=='index.html':continue
 origin=parent/row['path'];assert hashfile(origin)==row['sha256'];target=web/row['path'];target.parent.mkdir(parents=True,exist_ok=True);os.link(origin,target)
files=[source/n for n in ['showcase.js','showcase.css','showcase-grand.css','showcase-art.js']]
files += [f for f in (source/'assets').rglob('*') if f.is_file() and not f.name.endswith('.import')]
manifest=[{'path':f.relative_to(source).as_posix(),'bytes':f.stat().st_size,'sha256':hashfile(f)} for f in sorted(files)]
shell=(source/'shell.html').read_text(encoding='utf-8');release=hashlib.sha256((json.dumps(manifest)+shell+game['releaseId']).encode()).hexdigest()[:24];prefix='releases/'+release+'/'
for row in manifest:
 target=web/prefix/row['path'];target.parent.mkdir(parents=True,exist_ok=True)
 if row['path'].startswith('assets/'):os.link(source/row['path'],target)
 else:shutil.copy2(source/row['path'],target)
names={r['path'] for r in manifest};shell=re.sub(r'\b(src|href|data-src)=([\"\'])([^\"\']+)\2',lambda m:m.group(1)+'='+m.group(2)+(prefix+m.group(3) if m.group(3) in names else m.group(3))+m.group(2),shell)
parent_html=(parent/'index.html').read_text(encoding='utf-8');match=re.search(r'window\.__EXPEDITION_ENGINE_CONFIG__=(\{[^\n]*\});',parent_html);assert match;config=json.loads(match.group(1));title=re.search(r'<title>(.*?)</title>',parent_html).group(1)
shell=shell.replace('$GODOT_PROJECT_NAME',title).replace('$GODOT_HEAD_INCLUDE','').replace('$GODOT_CONFIG',json.dumps(config,separators=(',',':'))).replace('$GODOT_URL',config['executable']+'.js')
assert '$GODOT_' not in shell;(web/'index.html').write_text(shell,encoding='utf-8')
rows=[{'path':'index.html','bytes':(web/'index.html').stat().st_size,'sha256':hashfile(web/'index.html')}]+[{**r,'path':prefix+r['path']} for r in manifest]+[r for r in game['publishFiles'] if r['path']!='index.html']
record={'releaseId':release,'gameReleaseId':game['releaseId'],'executable':config['executable'],'publishFiles':rows,'publication':'New frontend release with reused immutable game dependencies; retain all prior aliases/releases.'}
(web/'release-manifest.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
body=(source/'showcase.js').read_bytes();before=(root/'evidence/home-grand-20261003/before/showcase.js').read_bytes();assert body==before,'Root launch/save/bootstrap body must remain byte-identical'
html_before=(root/'evidence/home-grand-20261003/before/shell.html').read_text(encoding='utf-8');touch=lambda s:s[s.index('/* Touch adapter:'):s.index('<script id="engine-source"')];assert touch(shell)==touch(html_before)
receipt={'at':time.time(),'releaseId':release,'gameReleaseId':game['releaseId'],'gamePckSha256':next(r['sha256'] for r in game['publishFiles'] if r['path'].endswith('/index.pck')),'unchangedGameBytes':True,'unchangedLaunchSaveJS':True,'unchangedTouchAdapter':True,'sourceFiles':[{'path':'godot/web/'+f.relative_to(source).as_posix(),'sha256':hashfile(f)} for f in files]+[{'path':'godot/web/shell.html','sha256':hashfile(source/'shell.html')}],'manifest':record}
(dest/'BUILD_RECEIPT.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8');print(json.dumps({'releaseId':release,'gameReleaseId':game['releaseId'],'files':len(rows),'gameBytesChanged':False}))
