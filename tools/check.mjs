import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { readFileSync } from 'node:fs';
import { Script } from 'node:vm';
const web=resolve(import.meta.dirname,'../godot/web');
for(const name of ['showcase.js','showcase-art.js']) new Script(readFileSync(resolve(web,name),'utf8'),{filename:name});
const shell=readFileSync(resolve(web,'shell.html'),'utf8');
for(const [index,match] of [...shell.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].entries()) {
  new Script(match[1].replaceAll('$GODOT_CONFIG','{}'),{filename:'shell-inline-'+index});
}
const engine=process.env.GODOT_BIN || 'C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe';
for (const script of ['main_web_20261003','world','interface','rover','living_habitat','contact']) {
  const result=spawnSync(engine,['--headless','--path',resolve(import.meta.dirname,'../godot'),'--check-only','--script','res://scripts/'+script+'.gd'],{stdio:'inherit',timeout:60000});
  if (result.error || result.status !== 0) process.exit(result.status??1);
}
