// Project-owned isolated browser regression: measure unfiltered main-thread stalls during boot.
import {mkdirSync, writeFileSync, appendFileSync, readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const options=Object.fromEntries(process.argv.slice(2).map(a=>{const [k,...v]=a.replace(/^--/,'').split('=');return [k,v.join('=')||true]}));
const url=String(options.url||'http://127.0.0.1:4234/');
if(!['localhost','127.0.0.1','twk0672005.github.io'].includes(new URL(url).hostname))throw Error('Unexpected test destination');
if(new URL(url).hostname==='twk0672005.github.io'&&!new URL(url).pathname.startsWith('/signal-in-the-dust/'))throw Error('Unexpected public project');
const output=resolve(String(options.output));mkdirSync(output,{recursive:true});
const {chromium}=await import(pathToFileURL(process.env.PLAYWRIGHT_MODULE||'C:/Users/tsang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs'));
const browser=await chromium.launch({channel:'chrome',headless:!options.headed,args:['--enable-gpu','--use-gl=angle','--use-angle=d3d11','--force_high_performance_gpu']});
const context=await browser.newContext({viewport:{width:1280,height:720},locale:'en-US'});
const page=await context.newPage();
const errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('crash',()=>errors.push('renderer crash'));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());appendFileSync(resolve(output,'console.jsonl'),JSON.stringify({at:Date.now(),type:m.type(),text:m.text()})+'\n')});
await page.addInitScript(()=>{
  window.__BOOT_QA__={gaps:[],longTasks:[],gl:[]};let last=performance.now();
  setInterval(()=>{const now=performance.now();window.__BOOT_QA__.gaps.push({at:now,duration:now-last});last=now},50);
  new PerformanceObserver(list=>{for(const e of list.getEntries())window.__BOOT_QA__.longTasks.push({at:e.startTime,duration:e.duration})}).observe({type:'longtask',buffered:true});
});
if(options['profile-gl'])await page.addInitScript(()=>{
 for(const proto of [WebGLRenderingContext.prototype,WebGL2RenderingContext.prototype]){
  for(const method of ['compileShader','linkProgram','getProgramParameter','getShaderParameter','texImage2D','compressedTexImage2D','bufferData','finish']){
   const original=proto[method];if(!original)continue;
   proto[method]=function(...args){const at=performance.now();try{return original.apply(this,args)}finally{const duration=performance.now()-at;if(duration>5)window.__BOOT_QA__.gl.push({method,at,duration})}};
  }
 }
});
const receipt={url,at:new Date().toISOString(),browser:browser.version(),headless:!options.headed,runs:[],errors,maxAllowedStallMs:2000};
const save=()=>writeFileSync(resolve(output,'receipt.json'),JSON.stringify(receipt,null,2));
try{
 if(options.artifact){
  const expected=readFileSync(resolve(String(options.artifact),'index.html'));
  const actual=Buffer.from(await(await fetch(new URL('index.html',url))).arrayBuffer());
  const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
  receipt.artifact={directory:resolve(String(options.artifact)),expectedHtmlSha256:sha(expected),servedHtmlSha256:sha(actual)};
  if(sha(expected)!==sha(actual))throw Error('Served HTML does not match the candidate; refuse stale/shared port');
 }
 if(options.fault){
  if(!['wasm','pck'].includes(options.fault))throw Error('Unknown fault fixture');
  await page.route('**/*.'+options.fault,route=>route.fulfill({status:options.fault==='pck'?404:200,contentType:'application/wasm',body:'invalid-test-download'}));
  await page.goto(url,{waitUntil:'domcontentloaded'});
  const started=Date.now();await page.locator('#start').click();
  await page.waitForFunction(()=>document.body.dataset.shellPhase==='error',null,{timeout:20000});
  receipt.fault={kind:options.fault,errorAfterMs:Date.now()-started,reloadAvailable:await page.locator('#reload').isVisible(),retryAvailable:await page.locator('#retry').isVisible()};
  receipt.pass=receipt.fault.errorAfterMs<15000&&(receipt.fault.reloadAvailable||receipt.fault.retryAvailable);save();
  if(!receipt.pass)process.exitCode=1;
 }else{
 for(const action of options['cold-only']?['cold']:['cold','warm']){
  const started=Date.now();
  if(action==='cold')await page.goto(url,{waitUntil:'domcontentloaded'});else await page.reload({waitUntil:'domcontentloaded'});
  await page.locator(action==='cold'?'#start':'#continue').click();
  await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='exploring'&&document.body.dataset.shellPhase==='game',null,{timeout:180000});
  await page.waitForTimeout(500);
  const data=await page.evaluate(()=>({qa:window.__BOOT_QA__,boot:window.__EXPEDITION_BOOT_TIMINGS__,position:window.__EXPEDITION_STATE__.position,resources:performance.getEntriesByType('resource').filter(x=>/\.(pck|wasm)/.test(x.name)).map(x=>({name:x.name,bytes:x.decodedBodySize,duration:x.duration}))}));
  const maxStallMs=Math.max(0,...data.qa.gaps.map(x=>x.duration),...data.qa.longTasks.map(x=>x.duration));
  const before=await page.evaluate(()=>window.__EXPEDITION_STATE__.position);
  await page.keyboard.down('w');await page.waitForTimeout(2500);await page.keyboard.up('w');
  const after=await page.evaluate(()=>window.__EXPEDITION_STATE__.position);
  await page.keyboard.press('Escape');await page.waitForFunction(()=>window.__EXPEDITION_STATE__.phase==='paused');
  receipt.runs.push({action,seconds:(Date.now()-started)/1000,maxStallMs,responsive:maxStallMs<=receipt.maxAllowedStallMs,drove:Math.hypot(after.x-before.x,after.z-before.z)>1,...data});save();
  console.log(JSON.stringify({action,seconds:receipt.runs.at(-1).seconds,maxStallMs,responsive:receipt.runs.at(-1).responsive}));
 }
 receipt.pass=receipt.runs.every(x=>x.responsive&&x.drove)&&errors.length===0;
 if(!receipt.pass)process.exitCode=1;
 }
}catch(e){receipt.failure=String(e);receipt.pass=false;process.exitCode=1;}
finally{save();await browser.close();}
