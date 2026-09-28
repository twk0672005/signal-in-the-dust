import { spawnSync } from 'node:child_process';
import { mkdirSync, readdirSync, readFileSync, writeFileSync, rmSync, existsSync, lstatSync, realpathSync } from 'node:fs';
import { resolve, extname, relative, isAbsolute, sep, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { finalizeWebRelease } from './finalize-web-release.mjs';
const root = resolve(import.meta.dirname,'..');

// Validate existing path components before recursive writes/deletion. A checkout
// junction must not redirect an ordinary rebuild outside its actual owner.
export function assertCheckoutTarget(checkout, target) {
  const base = realpathSync(checkout), candidate = resolve(target);
  const local = relative(resolve(checkout), candidate);
  if (!local || local === '..' || local.startsWith('..' + sep) || isAbsolute(local)) throw new Error('Target is outside checkout: ' + candidate);
  let current = resolve(checkout);
  for (const part of local.split(sep)) {
    current = resolve(current,part);
    if (existsSync(current)) {
      if (lstatSync(current).isSymbolicLink()) throw new Error('Refusing linked build path: ' + current);
      const resolved = relative(base,realpathSync(current));
      if (resolved === '..' || resolved.startsWith('..' + sep) || isAbsolute(resolved)) throw new Error('Resolved target leaves checkout: ' + current);
    }
  }
  return candidate;
}

function fileEntries(directory, prefix = '') {
  const files = [];
  for (const entry of readdirSync(directory,{withFileTypes:true})) {
    if (entry.name.startsWith('.') || entry.name.endsWith('.import')) continue;
    if (entry.isSymbolicLink()) throw new Error('Refusing linked web asset: ' + entry.name);
    const name = prefix + entry.name;
    if (entry.isDirectory()) files.push(...fileEntries(resolve(directory,entry.name), name + '/'));
    else if (entry.isFile()) files.push(name);
  }
  return files.sort();
}

export function copyShellAssets(checkout, target) {
  assertCheckoutTarget(checkout,target);
  const source = resolve(checkout,'godot/web');
  const names = ['showcase.css','showcase.js', ...fileEntries(resolve(source,'assets'),'assets/')];
  for (const name of names) {
    const destination = assertCheckoutTarget(checkout,resolve(target,name));
    mkdirSync(dirname(destination),{recursive:true});
    writeFileSync(destination,readFileSync(resolve(source,name)));
  }
  return names;
}

function manifestEntry(name,data) {
  return {name,bytes:data.length,sha256:createHash('sha256').update(data).digest('hex')};
}

export function packageWebExport(checkout, raw, out) {
  assertCheckoutTarget(checkout,raw); assertCheckoutTarget(checkout,out);
  const files = [], rawFiles = [];
  for (const name of fileEntries(raw).filter(name => !name.startsWith('releases/') && name !== 'release-manifest.json')) {
    const source = readFileSync(resolve(raw,name));
    rawFiles.push(manifestEntry(name,source));
    const data = extname(name) === '.wasm' ? gzipSync(source,{level:9,mtime:0}) : source;
    const destination = assertCheckoutTarget(checkout,resolve(out,name));
    mkdirSync(dirname(destination),{recursive:true});
    writeFileSync(destination,data);
    files.push(manifestEntry(name,data));
  }
  return {files,rawFiles};
}

function main() {
  const engine = process.env.GODOT_BIN || 'C:/Users/tsang/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe';
  const project = resolve(root,'godot');
  const raw = assertCheckoutTarget(root,resolve(project,'build/web'));
  const out = assertCheckoutTarget(root,resolve(root,'out'));
  mkdirSync(raw,{recursive:true});
  rmSync(out,{recursive:true,force:true});
  mkdirSync(out,{recursive:true});
  for (const args of [['--version'],['--headless','--path',project,'--editor','--import','--quit'],['--headless','--path',project,'--export-release','Web',resolve(raw,'index.html')]]) {
    const result = spawnSync(engine,args,{stdio:'inherit',timeout:180000});
    if (result.error || result.status !== 0) throw result.error || new Error('Godot failed: ' + result.status);
  }
  // External HTML resources must exist standalone in both outputs, not PCK-only.
  const standaloneAssets = copyShellAssets(root,raw);
  packageWebExport(root,raw,out);
  const rawRelease = finalizeWebRelease(raw), release = finalizeWebRelease(out);
  const headers = `/${release.executable}.wasm\n  Content-Type: application/wasm\n  Content-Encoding: gzip\n/${release.executable}.pck\n  Content-Type: application/octet-stream\n/index.wasm\n  Content-Type: application/wasm\n  Content-Encoding: gzip\n`;
  writeFileSync(resolve(out,'_headers'),headers);
  const files = fileEntries(out).map(name => manifestEntry(name,readFileSync(resolve(out,name))));
  const rawFiles = fileEntries(raw).map(name => manifestEntry(name,readFileSync(resolve(raw,name))));
  mkdirSync(resolve(root,'evidence'),{recursive:true});
  writeFileSync(resolve(root,'evidence','web-build-manifest.json'),JSON.stringify({builtAt:new Date().toISOString(),engine:'4.7.2',files,rawFiles,standaloneAssets,release,rawRelease,headers},null,2));
  // Retained historical hosting gate. Changing hosting policy belongs to PM.
  if (files.some(f=>f.bytes>25*1024*1024)) throw new Error('Sites asset exceeds 25 MiB');
  console.log(JSON.stringify({out,files},null,2));
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
