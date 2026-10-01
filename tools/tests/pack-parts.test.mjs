import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync,mkdirSync,mkdtempSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {finalizeWebRelease} from '../finalize-web-release.mjs';
const root=resolve(import.meta.dirname,'../..');
const source=readFileSync(resolve(root,'godot/web/showcase.js'),'utf8');
const decoder=source.slice(source.indexOf('  function installWasmDecode('),source.indexOf('  function withBootFailures('));
const config={executable:'releases/a/index',mainPack:'releases/a/index.pck',fileSizes:{'releases/a/index.pck':8},packParts:[{name:'index.pck.part-000',bytes:4},{name:'index.pck.part-001',bytes:4}]};
function setup(fetch,settings=config){
 const context=vm.createContext({window:{fetch},URL,Request,Response,ReadableStream,Headers,DecompressionStream,location:{href:'https://example.test/game/'},config:settings,markBootTiming:()=>0,completeBootTiming:()=>0});
 vm.runInContext(decoder+';installWasmDecode(config);',context);return context.window.fetch;
}
test('split PCK streams in order before download finishes, preserving exact bytes and length',async()=>{
 let first;
 const calls=[];
 const fetch=setup(async url=>{
  calls.push(String(url));
  return String(url).endsWith('000')?new Response(new ReadableStream({start(c){first=c;c.enqueue(Uint8Array.of(71,68));}})):new Response(Uint8Array.of(1,2,3,4));
 });
 const response=await fetch('releases/a/index.pck');
 assert.equal(response.headers.get('Content-Length'),'8');assert.equal(calls.length,1);
 first.enqueue(Uint8Array.of(80,67));first.close();
 assert.deepEqual(new Uint8Array(await response.arrayBuffer()),Uint8Array.of(71,68,80,67,1,2,3,4));
 assert.deepEqual(calls,['https://example.test/game/releases/a/index.pck.part-000','https://example.test/game/releases/a/index.pck.part-001']);
});
test('failed and truncated later parts reject the package instead of completing it',async()=>{
 for(const mode of ['failed','truncated','oversized']){
  const fetch=setup(async url=>String(url).endsWith('000')?new Response(new Uint8Array(4)):mode==='failed'?new Response('missing',{status:404}):new Response(new Uint8Array(mode==='truncated'?3:5)));
  const response=await fetch('releases/a/index.pck');
  await assert.rejects(response.arrayBuffer(),/download failed|Truncated|size mismatch/);
 }
});
test('invalid order/path/size is rejected before any network request',async()=>{
 for(const changed of [{...config,packParts:[{name:'../other',bytes:4},config.packParts[1]]},{...config,fileSizes:{'releases/a/index.pck':9}},{...config,packParts:[config.packParts[1],config.packParts[0]]}]){
  let calls=0;const fetch=setup(()=>{calls++;return new Response('bad');},changed);
  await assert.rejects(fetch('releases/a/index.pck'),/Invalid game package/);assert.equal(calls,0);
 }
});
test('cancelling a package stops its current reader and does not fetch later parts',async()=>{
 let cancelled=false,calls=0;
 const fetch=setup(async()=>{calls++;return new Response(new ReadableStream({pull(){},cancel(){cancelled=true;}}));});
 const response=await fetch('releases/a/index.pck');await response.body.cancel();assert.ok(cancelled);assert.equal(calls,1);
});
test('release manifest ships physical parts with an immutable logical pack URL',()=>{
 const folder=resolve(root,'evidence/push-main-20261001/chunk-fixture');mkdirSync(folder,{recursive:true});
 const staged=mkdtempSync(resolve(folder,'candidate-'));
 const local={executable:'index',mainPack:'index.pck',fileSizes:{'index.wasm':8,'index.pck':8},packParts:config.packParts};
 const files={'index.html':'<script>window.__EXPEDITION_ENGINE_CONFIG__='+JSON.stringify(local)+';</script>','index.js':'engine','index.wasm':Uint8Array.of(0,97,115,109,1,0,0,0),'showcase.js':'loader','showcase.css':'body{}','index.pck.part-000':new Uint8Array(4),'index.pck.part-001':new Uint8Array(4)};
 for(const [name,bytes] of Object.entries(files))writeFileSync(resolve(staged,name),bytes);
 const result=finalizeWebRelease(staged),html=readFileSync(resolve(staged,'index.html'),'utf8');
 assert.equal(result.publishFiles.length,7);assert.ok(!result.publishFiles.some(f=>f.path.endsWith('index.pck')));
 const final=JSON.parse(html.match(/__EXPEDITION_ENGINE_CONFIG__=(\{.*\});/)[1]);
 assert.equal(final.mainPack,result.executable+'.pck');assert.equal(final.fileSizes[final.mainPack],8);assert.deepEqual(final.packParts,config.packParts);
});
