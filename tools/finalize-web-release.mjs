import { createHash } from 'node:crypto';
import { copyFileSync, existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function filesIn(folder, prefix = '') {
  return readdirSync(folder, { withFileTypes: true }).flatMap(entry => {
    if (entry.name.startsWith('.') || (!prefix && ['releases','release-manifest.json','_headers'].includes(entry.name))) return [];
    if (entry.isSymbolicLink()) throw new Error('Linked release asset: ' + entry.name);
    const name = prefix + entry.name;
    return entry.isDirectory() ? filesIn(resolve(folder,entry.name),name + '/') : [name];
  }).sort();
}

export function finalizeWebRelease(folder) {
  folder = resolve(folder);
  const htmlPath = resolve(folder,'index.html');
  let html = readFileSync(htmlPath,'utf8');
  const configMatch = html.match(/window\.__EXPEDITION_ENGINE_CONFIG__=(\{[^\n]*\});/);
  if (!configMatch) throw new Error('Exported engine configuration missing');
  const config = JSON.parse(configMatch[1]);
  if (config.executable !== 'index') throw new Error('Expected an unfinalized index export');
  const sourceFiles = filesIn(folder).map(path => {
    const bytes = readFileSync(resolve(folder,path));
    return { path, bytes: bytes.length, sha256: hash(bytes) };
  });
  for (const required of ['index.js','index.wasm','index.pck','showcase.js','showcase.css']) {
    if (!sourceFiles.some(file => file.path === required)) throw new Error('Missing release asset: ' + required);
  }
  const releaseId = hash(JSON.stringify(sourceFiles)).slice(0,24);
  const prefix = `releases/${releaseId}/`;
  const payload = sourceFiles.filter(file => file.path !== 'index.html');
  const releasesPath = resolve(folder,'releases');
  if (existsSync(releasesPath) && lstatSync(releasesPath).isSymbolicLink()) throw new Error('Linked releases directory');
  // Preserve root aliases for local tooling. Publication copies only publishFiles
  // and retains old aliases/releases, so cached older HTML remains self-consistent.
  for (const file of payload) {
    const destination = resolve(folder,prefix + file.path);
    let component = dirname(destination);
    while (component !== folder) {
      if (existsSync(component) && lstatSync(component).isSymbolicLink()) throw new Error('Linked release directory');
      component = dirname(component);
    }
    mkdirSync(dirname(destination),{ recursive: true });
    if (existsSync(destination)) {
      if (lstatSync(destination).isSymbolicLink() || hash(readFileSync(destination)) !== file.sha256) throw new Error('Immutable release collision: ' + destination);
    } else copyFileSync(resolve(folder,file.path),destination);
  }
  const names = new Set(payload.map(file => file.path));
  html = html.replace(/\b(src|href|data-src)=(['"])([^'"]+)\2/g, (match,attribute,quote,url) =>
    names.has(url) ? `${attribute}=${quote}${prefix}${url}${quote}` : match);
  config.executable = prefix + config.executable;
  if (config.mainPack) config.mainPack = prefix + config.mainPack;
  config.fileSizes = Object.fromEntries(Object.entries(config.fileSizes || {}).map(([name,size]) => [prefix + name,size]));
  html = html.replace(configMatch[0],`window.__EXPEDITION_ENGINE_CONFIG__=${JSON.stringify(config)};`);
  writeFileSync(htmlPath,html);
  const publishFiles = [{ path: 'index.html', bytes: Buffer.byteLength(html), sha256: hash(html) },
    ...payload.map(file => ({ ...file, path: prefix + file.path }))];
  const manifest = { releaseId, executable: config.executable, publishFiles,
    publication: 'Copy publishFiles plus this manifest; retain prior releases and legacy root aliases. Never replace old immutable release contents.' };
  writeFileSync(resolve(folder,'release-manifest.json'),JSON.stringify(manifest,null,2) + '\n');
  return manifest;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (!process.argv[2]) throw new Error('Usage: node tools/finalize-web-release.mjs <export-directory>');
  const manifest = finalizeWebRelease(process.argv[2]);
  console.log(JSON.stringify({releaseId: manifest.releaseId, files: manifest.publishFiles.length}));
}
