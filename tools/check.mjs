import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
const engine=process.env.GODOT_BIN || 'C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe';
const result=spawnSync(engine,['--headless','--path',resolve(import.meta.dirname,'../godot'),'--check-only','--script','res://scripts/main.gd'],{stdio:'inherit',timeout:60000});
process.exit(result.status??1);
