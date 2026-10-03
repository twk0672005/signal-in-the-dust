// Project-owned isolated browser regression: measure unfiltered main-thread stalls during boot.
import {mkdirSync, writeFileSync, appendFileSync, readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const options=Object.fromEntries(process.argv.slice(2).map(a=>{const [k,...v]=a.replace(/^--/,'').split('=');return [k,v.join('=')||true]}));
if(options.quality && !['standard','low'].includes(options.quality))throw Error('Unknown quality fixture');
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
if(options.fault==='scene-shader')await page.addInitScript(()=>{
  const shaders=new WeakSet();const proto=WebGL2RenderingContext.prototype;
  const source=proto.shaderSource,status=proto.getShaderParameter;let injected=false;
  proto.shaderSource=function(shader,code){if(String(code).includes('m_pool_center'))shaders.add(shader);return source.call(this,shader,code);};
  proto.getShaderParameter=function(shader,parameter){
    if(!injected&&parameter===this.COMPILE_STATUS&&shaders.has(shader)){injected=true;window.__SCENE_SHADER_FAULT_INJECTED__=true;return false;}
    return status.call(this,shader,parameter);
  };
});
if(options.fault==='sync-shader')await page.addInitScript(()=>{
 const original=WebGL2RenderingContext.prototype.getShaderParameter;let injected=false;
 WebGL2RenderingContext.prototype.getShaderParameter=function(shader,parameter){if(!injected&&parameter===this.COMPILE_STATUS){injected=true;window.__SYNC_SHADER_FAULT_INJECTED__=true;return false;}return original.call(this,shader,parameter);};
});
if(options['no-parallel'])await page.addInitScript(()=>{
 for(const proto of [WebGLRenderingContext.prototype,WebGL2RenderingContext.prototype]){
  const extension=proto.getExtension,supported=proto.getSupportedExtensions;
  proto.getExtension=function(name){return name==='KHR_parallel_shader_compile'?null:extension.call(this,name);};
  proto.getSupportedExtensions=function(){return supported.call(this).filter(name=>name!=='KHR_parallel_shader_compile');};
 }
});
const receipt={url,at:new Date().toISOString(),browser:browser.version(),headless:!options.headed,quality:options.quality||'saved',runs:[],errors,maxAllowedStallMs:2000,
 coldDefinition:'Fresh isolated browser/profile, new engine instance and empty HTTP cache. OS/GPU driver caches are not modified and remain uncontrolled.',
 targetStartupSeconds:options['target-seconds']?Number(options['target-seconds']):null};
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
  if(!['wasm','pck','scene-shader','sync-shader'].includes(options.fault))throw Error('Unknown fault fixture');
  if(['wasm','pck'].includes(options.fault))await page.route('**/*.'+options.fault,route=>route.fulfill({status:options.fault==='pck'?404:200,contentType:'application/wasm',body:'invalid-test-download'}));
  await page.goto(url,{waitUntil:'domcontentloaded'});
  const started=Date.now();await page.locator('#start').click();
  await page.waitForFunction(()=>document.body.dataset.shellPhase==='error',null,{timeout:20000});
  receipt.fault={kind:options.fault,errorAfterMs:Date.now()-started,reloadAvailable:await page.locator('#reload').isVisible(),retryAvailable:await page.locator('#retry').isVisible()};
  if(options.fault==='scene-shader')receipt.fault.driverStatusFault=await page.evaluate(()=>({injected:window.__SCENE_SHADER_FAULT_INJECTED__===true,firstFrameReady:window.__EXPEDITION_BOOT_STATUS__?.firstFrameReady,fatal:window.__EXPEDITION_BOOT_STATUS__?.fatal,shader:window.__EXPEDITION_BOOT_TIMINGS__?.godot?.shader_compilation}));
  if(options.fault==='sync-shader')receipt.fault.syncStatusFault=await page.evaluate(()=>({injected:window.__SYNC_SHADER_FAULT_INJECTED__===true,flag:window.__EXPEDITION_FATAL_BOOT_ERROR__===true,shell:document.body.dataset.shellPhase,canvasHidden:document.getElementById('canvas').getAttribute('aria-hidden')==='true'}));
  receipt.pass=receipt.fault.errorAfterMs<15000&&(receipt.fault.reloadAvailable||receipt.fault.retryAvailable);save();
  if(options.fault==='scene-shader'){receipt.pass=receipt.pass&&receipt.fault.driverStatusFault.injected&&receipt.fault.driverStatusFault.firstFrameReady===false&&receipt.fault.driverStatusFault.fatal===true&&receipt.fault.driverStatusFault.shader.failed>0;save();}
  if(options.fault==='sync-shader'){receipt.pass=receipt.pass&&receipt.fault.syncStatusFault.injected&&receipt.fault.syncStatusFault.flag&&receipt.fault.syncStatusFault.canvasHidden;save();}
  if(options.recover){
   await page.unroute('**/*.'+options.fault);
   const priorErrors=errors.length;
   await Promise.all([page.waitForNavigation({waitUntil:'domcontentloaded'}),page.locator('#retry').click()]);
   await page.locator('#start').click();
   await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='exploring'&&document.body.dataset.shellPhase==='game',null,{timeout:180000});
   receipt.fault.recoveredThroughVisibleRetry=true;
   receipt.fault.recoveryErrors=errors.slice(priorErrors);
   receipt.pass=receipt.pass&&receipt.fault.recoveryErrors.length===0;save();
  }
  if(!receipt.pass)process.exitCode=1;
 }else{
 for(const action of options['cold-only']?['cold']:['cold','warm']){
  const started=Date.now();
  if(action==='cold')await page.goto(url,{waitUntil:'domcontentloaded'});else await page.reload({waitUntil:'domcontentloaded'});
  if(options.quality){
   await page.locator('#open-settings').click();
   await page.locator('#setting-quality').selectOption(options.quality==='low'?'true':'false');
   await page.locator('#settings-done').click();
  }
  const clickedAt=Date.now();
  await page.locator('#start').click();
  await page.waitForFunction(()=>document.body.dataset.shellPhase==='game',null,{timeout:180000});
  if(await page.evaluate(()=>window.__EXPEDITION_BOOT_STATUS__?.stage==='confirm-new')){
   await page.keyboard.press('Shift+Tab');await page.keyboard.press('Enter');
  }
  await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='exploring'&&document.body.dataset.shellPhase==='game',null,{timeout:180000});
  const playableAt=Date.now();
  await page.waitForTimeout(500);
  const data=await page.evaluate(()=>{const gl=document.getElementById('canvas').getContext('webgl2');const debug=gl?.getExtension('WEBGL_debug_renderer_info');return {qa:window.__BOOT_QA__,boot:window.__EXPEDITION_BOOT_TIMINGS__,gpu:{renderer:debug?gl.getParameter(debug.UNMASKED_RENDERER_WEBGL):null,vendor:debug?gl.getParameter(debug.UNMASKED_VENDOR_WEBGL):null,parallelCompile:!!gl?.getExtension('KHR_parallel_shader_compile')},position:window.__EXPEDITION_STATE__.position,quality:window.__EXPEDITION_STATE__.settings.low_quality?'low':'standard',display:window.__EXPEDITION_METRICS__.display,resources:performance.getEntriesByType('resource').filter(x=>/\.(pck|wasm)/.test(x.name)).map(x=>({name:x.name,bytes:x.decodedBodySize,duration:x.duration}))};});
  const maxStallMs=Math.max(0,...data.qa.gaps.map(x=>x.duration),...data.qa.longTasks.map(x=>x.duration));
  const before=await page.evaluate(()=>window.__EXPEDITION_STATE__.position);
  await page.keyboard.down('w');await page.waitForTimeout(2500);await page.keyboard.up('w');
  const after=await page.evaluate(()=>window.__EXPEDITION_STATE__.position);
  await page.keyboard.press('Escape');await page.waitForFunction(()=>window.__EXPEDITION_STATE__.phase==='paused');
  receipt.runs.push({action,seconds:(Date.now()-started)/1000,startupSeconds:(playableAt-clickedAt)/1000,pageStartupSeconds:(playableAt-started)/1000,measurementWindow:'unfiltered navigation through 500ms after exploring; seconds also includes drive/pause checks',maxStallMs,responsive:maxStallMs<=receipt.maxAllowedStallMs,drove:Math.hypot(after.x-before.x,after.z-before.z)>1,...data});save();
  console.log(JSON.stringify({action,startupSeconds:receipt.runs.at(-1).startupSeconds,seconds:receipt.runs.at(-1).seconds,maxStallMs,responsive:receipt.runs.at(-1).responsive}));
 }
 receipt.startupTargetPassed=receipt.targetStartupSeconds===null?null:receipt.runs.every(x=>x.startupSeconds<=receipt.targetStartupSeconds);
 if(options['no-parallel'])receipt.fallbackCompatibility={fixture:'Simulated missing KHR on the same NVIDIA hardware; not a physical unsupported device',pass:receipt.runs.every(x=>x.drove&&x.boot.godot.shader_compilation.available===true&&x.boot.godot.shader_compilation.async_enabled===false&&x.boot.godot.shader_compilation.pending===0)&&errors.length===0};
 receipt.pass=receipt.runs.every(x=>x.responsive&&x.drove&&(!options.quality||x.quality===options.quality))&&errors.length===0&&receipt.startupTargetPassed!==false;
 if(!receipt.pass)process.exitCode=1;
 }
}catch(e){receipt.failure=String(e);receipt.pass=false;process.exitCode=1;}
finally{save();await browser.close();}
