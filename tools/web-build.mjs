import { spawnSync } from 'node:child_process';
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, extname } from 'node:path';
import { gzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
const root=resolve(import.meta.dirname,'..');
const engine=process.env.GODOT_BIN || 'C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe';
const project=resolve(root,'godot');
const raw=resolve(project,'build/web');
const out=resolve(root,'out');
mkdirSync(raw,{recursive:true}); mkdirSync(out,{recursive:true});
for(const args of [['--version'],['--headless','--path',project,'--editor','--import','--quit'],['--headless','--path',project,'--export-release','Web',resolve(raw,'index.html')]]) {
  const result=spawnSync(engine,args,{stdio:'inherit',timeout:180000});
  if(result.error || result.status!==0) throw result.error || new Error(`Godot failed: ${result.status}`);
}
const files=[];
for(const entry of readdirSync(raw,{withFileTypes:true})) {
  if(!entry.isFile() || entry.name.endsWith('.import') || entry.name.startsWith('.')) continue;
  let data=readFileSync(resolve(raw,entry.name));
  if(extname(entry.name)==='.wasm') data=gzipSync(data,{level:9,mtime:0});
  writeFileSync(resolve(out,entry.name),data);
  files.push({name:entry.name,bytes:data.length,sha256:createHash('sha256').update(data).digest('hex')});
}
writeFileSync(resolve(out,'_headers'),'/index.wasm\n  Content-Type: application/wasm\n  Content-Encoding: gzip\n/index.pck\n  Content-Type: application/octet-stream\n');
writeFileSync(resolve(out,'build-manifest.json'),JSON.stringify({builtAt:new Date().toISOString(),engine:'4.7.2',files},null,2));
if(files.some(f=>f.bytes>25*1024*1024)) throw new Error('Sites asset exceeds 25 MiB');
console.log(JSON.stringify({out,files},null,2));
