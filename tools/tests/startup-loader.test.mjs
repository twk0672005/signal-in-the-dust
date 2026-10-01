import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { gzipSync } from 'node:zlib';
import { finalizeWebRelease } from '../finalize-web-release.mjs';
import { packageWebExport } from '../web-build.mjs';

const root = resolve(import.meta.dirname,'../..');
const source = readFileSync(resolve(root,'godot/web/showcase.js'),'utf8');
const decoder = source.slice(source.indexOf('  function installWasmDecode('),source.indexOf('  function withBootFailures('));
const boundary = source.slice(source.indexOf('  function withBootFailures('),source.indexOf('  async function initialize('));
const wasm = Uint8Array.from([0,97,115,109,1,0,0,0]);
function decoderContext(fetch) {
  const window = {fetch};
  return vm.createContext({window, URL, Request, Response, ReadableStream, Headers, DecompressionStream,
    location: {href:'https://example.test/game/'}, markBootTiming:()=>0, completeBootTiming:()=>0});
}

for (const kind of ['raw','gzip','host-decoded']) {
  test(`WASM ${kind} response is returned before download ends, including a split signature`, {timeout:1500}, async () => {
    const bytes = kind === 'gzip' ? gzipSync(wasm) : wasm;
    let download;
    const response = new Response(new ReadableStream({start(controller) {
      download = controller;
      controller.enqueue(bytes.subarray(0,1));
      controller.enqueue(bytes.subarray(1,2));
      controller.enqueue(bytes.subarray(2,4));
    }}), {headers: {'Content-Length':String(bytes.length), ...(kind === 'host-decoded' ? {'Content-Encoding':'gzip'} : {})}});
    const original = () => Promise.resolve(response), context = decoderContext(original);
    vm.runInContext(decoder + ';globalThis.restore = installWasmDecode({executable:"releases/a/index"});',context);
    const decoded = await context.window.fetch('releases/a/index.wasm');
    assert.equal(decoded.headers.get('Content-Type'),'application/wasm');
    if (kind !== 'raw') assert.equal(decoded.headers.get('Content-Length'),null);
    assert.equal(decoded.headers.get('Content-Encoding'),null);
    download.enqueue(bytes.subarray(4)); download.close();
    assert.deepEqual(new Uint8Array(await decoded.arrayBuffer()),wasm);
    context.restore(); assert.equal(context.window.fetch,original);
  });
}

test('invalid WASM fails promptly; unrelated PCK response is untouched', async () => {
  let response = new Response('not a wasm file');
  const context = decoderContext(() => Promise.resolve(response));
  vm.runInContext(decoder + ';installWasmDecode({executable:"index"});',context);
  await assert.rejects(context.window.fetch('index.wasm'),/Invalid game engine download/);
  response = new Response('package');
  assert.equal(await context.window.fetch('index.pck'),response);
});

test('generated-engine unhandled failure rejects a stuck boot and removes scoped listeners', async () => {
  const listeners = new Map();
  const window = {addEventListener:(type,fn)=>listeners.set(type,fn),removeEventListener:(type)=>listeners.delete(type)};
  const context = vm.createContext({window});
  vm.runInContext(boundary,context);
  const pending = context.withBootFailures(() => new Promise(()=>{}));
  const error = new Error('bad engine import');
  listeners.get('unhandledrejection')({reason:error});
  await assert.rejects(pending,error);
  assert.equal(listeners.size,0);
  assert.equal(await context.withBootFailures(()=>Promise.resolve('ready')),'ready');
  assert.equal(listeners.size,0);
  await assert.rejects(context.withBootFailures(()=>{throw new Error('sync boot error');}),/sync boot error/);
  assert.equal(listeners.size,0);
});

test('repeated launch clicks and fatal retry never create a second engine', async () => {
  const launch = source.slice(source.indexOf('  async function launch('),source.indexOf('  function inspectStatus('));
  const context = vm.createContext({setTimeout:()=>1,clearTimeout:()=>{},window:{},JSON,performance});
  vm.runInContext(`let busy=false, fatal=false, started=false, pending=null, lastStatus='', lastAction='', guard=0, restoreFetch=null, startPromise=null, errorKey='error';
    let bootDeadline=0,lastBootProgress=0,lastTransferBytes=0;
    globalThis.count=0; globalThis.resolveBoot=null;
    const request=action=>({action}); const resetBootTimings=()=>{}; const $=()=>({});
    const showLoading=()=>{}; const setProgress=()=>{};
    const refreshBootGuard=()=>{};
    const fail=()=>{fatal=true;busy=false;};
    const initialize=()=>{count++;return new Promise(resolve=>{resolveBoot=()=>{started=true;busy=false;resolve();};});};
    ${launch}`,context);
  const first = context.launch('new');
  await context.launch('new'); assert.equal(context.count,1);
  context.resolveBoot(); await first;
  await context.launch('continue'); // Missing launch callback is fatal, never another instance.
  await context.launch('new'); assert.equal(context.count,1);
});

test('boot timeout follows actual completed work but retains the ten-minute ceiling', () => {
  const guard = source.slice(source.indexOf('  function refreshBootGuard('),source.indexOf('  async function launch('));
  const inspect = source.slice(source.indexOf('  function inspectStatus('),source.indexOf("  $('start').addEventListener"));
  let now = 0, timer, failures = 0;
  const context = vm.createContext({window:{},performance:{now:()=>now},
    setTimeout:(callback,delay)=>{timer={callback,delay};return 1;},clearTimeout:()=>{},
    fail:()=>failures++,updateLoadingExperience:()=>{}});
  vm.runInContext(`let guard=0,bootDeadline=600000,lastBootProgress=0,busy=true,restoreFetch=null,started=false,pending=null;${guard}${inspect}`,context);
  context.refreshBootGuard(); assert.equal(timer.delay,120000);
  const firstTimer = timer;
  now = 110000; context.inspectStatus(); assert.equal(timer,firstTimer);
  context.window.__EXPEDITION_BOOT_PROGRESS__=1; context.inspectStatus();
  assert.notEqual(timer,firstTimer); assert.equal(timer.delay,120000);
  now = 590000; context.window.__EXPEDITION_BOOT_PROGRESS__=2; context.inspectStatus();
  assert.equal(timer.delay,10000);
  timer.callback(); assert.equal(failures,1);
});

test('raw and gzip build paths bind shell, engine, worklets and art to immutable release URLs', () => {
  const evidence = resolve(root,'evidence/startup-freeze-20260928T173012Z/loader-tests');
  mkdirSync(evidence,{recursive:true});
  const folder = mkdtempSync(resolve(evidence,'release-'));
  const raw = resolve(folder,'raw'), packed = resolve(folder,'packed');
  mkdirSync(raw); mkdirSync(packed); mkdirSync(resolve(raw,'assets'));
  const html = `<link href="showcase.css"><img src="assets/art.png"><script data-src="index.js"></script><script>window.__EXPEDITION_ENGINE_CONFIG__={"executable":"index","fileSizes":{"index.wasm":8,"index.pck":3}};</script><script src="showcase.js"></script>`;
  const files = {'index.html':html,'index.js':'engine','index.wasm':wasm,'index.pck':'old',
    'showcase.js':'shell','showcase.css':'body{background:url(assets/art.png)}','assets/art.png':'art',
    'index.audio.worklet.js':'audio','index.audio.position.worklet.js':'position'};
  for (const [name,bytes] of Object.entries(files)) writeFileSync(resolve(raw,name),bytes);
  packageWebExport(root,raw,packed);
  const old = finalizeWebRelease(raw), compressed = finalizeWebRelease(packed);
  assert.notEqual(old.releaseId,compressed.releaseId);
  for (const [directory,release] of [[raw,old],[packed,compressed]]) {
    const page = readFileSync(resolve(directory,'index.html'),'utf8');
    const prefix = `releases/${release.releaseId}/`;
    const config = JSON.parse(page.match(/__EXPEDITION_ENGINE_CONFIG__=(\{.*\});/)[1]);
    assert.equal(config.executable,prefix+'index');
    assert.equal(config.fileSizes[prefix+'index.wasm'],8);
    for (const url of ['showcase.css','showcase.js','index.js','assets/art.png']) assert.ok(page.includes('"'+prefix+url+'"'));
    for (const suffix of ['wasm','pck','js','audio.worklet.js','audio.position.worklet.js']) {
      assert.ok(release.publishFiles.some(file=>file.path===config.executable+'.'+suffix));
    }
    assert.equal(release.publishFiles.filter(file=>!file.path.startsWith(prefix)).length,1);
  }
  const oldPck = readFileSync(resolve(raw,old.executable+'.pck'));
  writeFileSync(resolve(raw,'index.html'),html);
  writeFileSync(resolve(raw,'index.pck'),'new');
  const current = finalizeWebRelease(raw);
  assert.notEqual(current.releaseId,old.releaseId);
  assert.deepEqual(readFileSync(resolve(raw,old.executable+'.pck')),oldPck);
  assert.equal(readFileSync(resolve(raw,current.executable+'.pck'),'utf8'),'new');
  assert.notEqual(current.executable,old.executable); // Old HTTP cache keys cannot satisfy the new release.
  writeFileSync(resolve(folder,'receipt.json'),JSON.stringify({old,current,compressed},null,2));
});
