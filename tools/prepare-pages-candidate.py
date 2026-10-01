"""Use the accepted game bytes with GitHub-compatible streaming pack parts."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--accepted',type=Path,required=True);p.add_argument('--destination',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];source=a.accepted.resolve();destination=a.destination.resolve()
assert root in source.parents and root in destination.parents and not destination.exists()
destination.mkdir(parents=True)
manifest=json.loads((source/'release-manifest.json').read_text(encoding='utf-8'))
prefix='releases/'+manifest['releaseId']+'/'
hashfile=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for row in manifest['publishFiles']:
 path=row['path'];assert path=='index.html' or path.startswith(prefix)
 assert hashfile(source/path)==row['sha256']
 name=path.removeprefix(prefix)
 if name=='index.pck':continue
 target=destination/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/path,target)
shutil.copy2(root/'godot/web/showcase.js',destination/'showcase.js')
html=(destination/'index.html').read_text(encoding='utf-8').replace(prefix,'')
match=re.search(r'window\.__EXPEDITION_ENGINE_CONFIG__=(\{[^\n]*\});',html);assert match
config=json.loads(match.group(1));assert config['executable']=='index'
parts=[];pack=source/'index.pck';digest=hashlib.sha256()
with pack.open('rb') as stream:
 while data:=stream.read(64*1024*1024):
  name='index.pck.part-'+str(len(parts)).zfill(3);(destination/name).write_bytes(data);digest.update(data)
  parts.append({'name':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
assert len(parts)==2 and digest.hexdigest()==hashfile(pack)
config['mainPack']='index.pck';config['packParts']=[{k:r[k] for k in ['name','bytes']} for r in parts]
assert config['fileSizes']['index.pck']==sum(r['bytes'] for r in parts)
html=html[:match.start(1)]+json.dumps(config,separators=(',',':'))+html[match.end(1):]
(destination/'index.html').write_text(html,encoding='utf-8',newline='\n')
subprocess.run(['node',str(root/'tools/finalize-web-release.mjs'),str(destination)],check=True)
published=json.loads((destination/'release-manifest.json').read_text(encoding='utf-8'))
assert all(r['bytes']<104857600 for r in published['publishFiles'])
record={'acceptedReleaseId':manifest['releaseId'],'publishedReleaseId':published['releaseId'],'acceptedPckSha256':digest.hexdigest(),'packBytes':pack.stat().st_size,'parts':parts,'gameContentChanged':False,'change':'Only transport loader/config and physical PCK parts; all decoded game bytes retained','files':len(published['publishFiles'])}
(destination.parent/'TRANSPORT_RECEIPT.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps(record))
