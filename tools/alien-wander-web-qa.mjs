// Project-owned isolated Chromium journey. No connection to a user browser.
// State is read-only: every movement, observation and camera change uses player input.
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const args = Object.fromEntries(process.argv.slice(2).map(a => {const [k,...v]=a.replace(/^--/,'').split('=');return [k,v.join('=')||true];}));
const url=String(args.url||'http://127.0.0.1:64818/');
const targetUrl=new URL(url);
const localTarget=['localhost','127.0.0.1'].includes(targetUrl.hostname);
const publicTarget=targetUrl.protocol==='https:'&&targetUrl.hostname==='twk0672005.github.io'&&targetUrl.pathname==='/signal-in-the-dust/';
if(!localTarget&&!publicTarget)throw Error('Only the project local preview or authorized public game can be tested');
const out=resolve(String(args.output||'evidence/alien-wander-20261004/browser-desktop'));
mkdirSync(out,{recursive:true});
const touch=!!args.touch;
const viewport=touch?{width:844,height:390}:{width:1440,height:900};
const {chromium}=await import(pathToFileURL(process.env.PLAYWRIGHT_MODULE||'C:/Users/tsang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs'));
const browser=await chromium.launch({headless:!args.headed,args:['--enable-gpu','--use-gl=angle','--use-angle=d3d11','--force_high_performance_gpu']});
const context=await browser.newContext({viewport,deviceScaleFactor:1,hasTouch:touch,isMobile:touch,locale:'en-US',...(args['timing-only']?{}:{recordVideo:{dir:resolve(out,'video'),size:viewport}})});
await context.addInitScript(()=>{
  const measured={firstUnobscuredGameFrameMs:null};
  window.__WANDER_PAINT_MEASUREMENTS__=measured;
  addEventListener('DOMContentLoaded',()=>{
    let waiting=false;
    const observe=()=>{
      if(document.body.dataset.shellPhase!=='game'||waiting||measured.firstUnobscuredGameFrameMs!==null)return;
      waiting=true;
      const check=()=>{
        const cover=document.getElementById('veil');
        if(cover.classList.contains('hidden')||Number(getComputedStyle(cover).opacity)<.01){
          requestAnimationFrame(()=>{measured.firstUnobscuredGameFrameMs=performance.now();});
        }else requestAnimationFrame(check);
      };
      requestAnimationFrame(check);
    };
    new MutationObserver(observe).observe(document.body,{attributes:true,attributeFilter:['data-shell-phase']});
  });
});
const page=await context.newPage();
const errors=[],checks={},trace=[],events=[];
const receipt={url,viewport,touch,physicalPhone:false,safari:false,kind:'real_player_input_no_teleport_no_review_camera',checks,trace,events,errors};
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const state=()=>page.evaluate(()=>window.__EXPEDITION_STATE__);
const pathX=z=>18*Math.sin((150-z)*.012)+4*Math.sin((150-z)*.033);
const wrap=x=>Math.atan2(Math.sin(x),Math.cos(x));
const cdp=await context.newCDPSession(page);
let held=new Set(),touchPoints=new Map(),touchSequence=1;
async function controls(wanted){
  const next=new Set(wanted);
  if([...held].sort().join()===[...next].sort().join())return;
  if(touch){
    const map={w:'drive_forward',s:'drive_reverse',a:'turn_left',d:'turn_right',Space:'brake'};
    if(held.size)await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    touchPoints.clear();
    for(const k of next){
      const b=await page.locator('[data-action="'+map[k]+'"]').boundingBox();
      if(!b)throw Error('Missing touch control '+k);
      touchPoints.set(k,{x:b.x+b.width/2,y:b.y+b.height/2,id:touchSequence++});
    }
    if(touchPoints.size)await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[...touchPoints.values()]});
  }else{
    for(const k of held)if(!next.has(k))await page.keyboard.up(k);
    for(const k of next)if(!held.has(k))await page.keyboard.down(k);
  }
  if([...held].sort().join()!==[...next].sort().join())events.push({at:Date.now(),input:[...next]});
  held=next;
}
async function tap(key,action){
  if(touch)await page.locator('[data-action="'+action+'"]').tap();
  else await page.keyboard.press(key);
  events.push({at:Date.now(),tap:touch?action:key});
}
async function stop(){await controls(['Space']);await page.waitForTimeout(850);await controls([]);}
async function shot(name){
  await page.screenshot({path:resolve(out,name+'.png')});
  writeFileSync(resolve(out,'progress.json'),JSON.stringify({capture:name,state:await state(),checks},null,2));
  console.log('Captured '+name);
}
async function driveTo(x,z,tolerance=4,subject=''){
  const deadline=Date.now()+80000;
  while(Date.now()<deadline){
    const s=await state();
    if(s.phase!=='exploring')throw Error('Driving interrupted: '+s.phase);
    const distance=Math.hypot(x-s.position.x,z-s.position.z);
    trace.push({at:Date.now(),position:s.position,heading:s.heading,speed:s.speed,region:s.region,phase:s.phase,transmitCount:s.transmitCount,observed:s.observedEcology,landmarks:s.observedLandmarks});
    if(distance<tolerance){await stop();return s;}
    if(subject&&s.interaction?.subject===subject&&s.interaction.distance<8&&s.interaction.reason!=='blocked'){await stop();return s;}
    const desired=Math.atan2(x-s.position.x,s.position.z-z),error=wrap(desired-s.heading);
    const limit=Math.abs(error)>.45?(distance<12?1.0:3.5):Math.min(12,Math.max(2.0,distance*.55));
    const keys=s.speed>limit+.4?['Space']:['w'];
    if(error>.045)keys.push('d');else if(error<-.045)keys.push('a');
    await controls(keys);
    await page.waitForTimeout(100);
  }
  throw Error('Route timeout '+JSON.stringify({target:{x,z},state:await state()}));
}
async function roadTo(z){
  const p=(await state()).position;
  const step=p.z>z?-24:24;
  for(let q=p.z+step;step<0?q>z:q<z;q+=step)await driveTo(pathX(q),q,7);
  await driveTo(pathX(z),z,5);
}
async function look(dx,dy){
  const x=viewport.width*.50,y=viewport.height*.44;
  if(touch){
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:98}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x+dx,y:y+dy,id:98}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  }else{
    await page.mouse.move(x,y);await page.mouse.down({button:'right'});
    await page.mouse.move(x+dx,y+dy,{steps:10});await page.mouse.up({button:'right'});
  }
  events.push({at:Date.now(),look:{dx,dy}});
}
async function waitPlaying(){await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.ready&&window.__EXPEDITION_STATE__.phase==='exploring'&&document.body.dataset.shellPhase==='game',null,{timeout:180000});await page.waitForTimeout(800);}
async function aimAt(x,z){
  const s=await state(),desired=Math.atan2(x-s.position.x,s.position.z-z);
  const delta=wrap(desired-s.heading+s.camera.yaw);
  const chunks=Math.max(1,Math.ceil(Math.abs(delta/.003)/300));
  for(let i=0;i<chunks;i++)await look(delta/.003/chunks,0);
  await page.waitForTimeout(450);
}
try{
  await page.goto(url);
  await page.locator('#start').waitFor();
  checks.title=await page.title()==='Alien Wander';
  checks.freeExplorationEntry=(await page.locator('#title').innerText()).includes('freely');
  await shot('01-entry-en');
  await page.locator('#language-toggle').click();await shot('02-entry-zh');
  checks.chineseEntry=(await page.locator('#title').innerText())==='自由探索外星世界';
  await page.locator('#language-toggle').click();
  if(touch||args.lighter){await page.locator('#open-settings').click();await page.locator('#setting-quality').selectOption('true');await page.locator('#settings-done').click();}
  await page.locator('#start').click();await waitPlaying();
  receipt.timings=await page.evaluate(()=>window.__EXPEDITION_BOOT_TIMINGS__);
  receipt.paint=await page.evaluate(()=>({entry:performance.getEntriesByType('paint').map(e=>({name:e.name,ms:e.startTime})),...window.__WANDER_PAINT_MEASUREMENTS__}));
  receipt.renderer=await page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2');const ext=gl.getExtension('WEBGL_debug_renderer_info');return {renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),vendor:ext?gl.getParameter(ext.UNMASKED_VENDOR_WEBGL):gl.getParameter(gl.VENDOR)};});
  checks.directDriving=(await state()).mode==='free_roam';
  checks.touchDetected=!touch||(await state()).touchEnabled;
  checks.lighterSelected=!(touch||args.lighter)||(await state()).settings.low_quality;
  receipt.preparation=await page.evaluate(()=>window.__EXPEDITION_METRICS__?.worldBuild);
  checks.lighterDuringPreparation=!(touch||args.lighter)||receipt.preparation.preparation_low_quality===true;
  await shot('03-aurora-start');
  if(!args['timing-only']){
  await driveTo(pathX(132),132,5);
  await driveTo(pathX(105)-18,114,3);
  const parked=await state();
  checks.offRoad=Math.abs(parked.position.x-pathX(parked.position.z))>9;
  await look(130,20);await page.waitForTimeout(300);
  const looked=(await state()).camera;
  await page.waitForTimeout(1600);
  checks.parkedLookRetained=Math.abs((await state()).camera.yaw-looked.yaw)<.01&&Math.abs(looked.yaw)>.1;
  await tap('v','toggle_camera');await page.waitForTimeout(500);
  checks.viewSwitch=(await state()).view==='third_person';
  await shot('04-off-road-look');
  await look(-130,-20);await page.waitForTimeout(400);
  if(touch||args.short){
    // A complete off-road observation loop, using the selected physical input surface.
    await driveTo(pathX(105)-18,110,3,'aurora_lode');
    await tap('v','toggle_camera');await page.waitForTimeout(300);
    await aimAt(pathX(105)-18,105);
    const candidate=await state();
    receipt.touchObservationContext=candidate.interaction;
    checks.touchObservationPrompt=candidate.interaction?.eligible===true;
    if(candidate.interaction?.eligible){await tap('e','interact');await page.waitForTimeout(850);}
    checks.touchObservation=Object.keys((await state()).observedLandmarks||{}).length>0;
    await shot('05-touch-observation');
    await driveTo(pathX(98),98,6);
  }else{
    await driveTo(pathX(99),99,6);
    await roadTo(-78);await shot('05-ember');
    await roadTo(-270);await shot('06-veil');
    await roadTo(-462);await shot('07-pale');
    await roadTo(-645);await shot('08-world-tree-no-E');
    const tree=await state();
    receipt.noInteractionArrival=tree;
    checks.fourHabitatsNoE=new Set(trace.map(t=>t.region)).size===4&&!events.some(e=>e.tap==='e')&&tree.activityCount===0;
    checks.treeReachedWithoutE=tree.position.z< -635&&tree.transmitCount===0&&Object.keys(tree.observedEcology).length===0;
    // Turn and depart with real steering, then return for the optional tree observation.
    await driveTo(pathX(-630)+11,-631,4);
    checks.leftTreeFreely=(await state()).phase==='exploring';
    await driveTo(pathX(-650),-653,3);
    await tap('v','toggle_camera');await page.waitForTimeout(500);
    await aimAt(pathX(-650),-676);
    let treeAction=await state();
    if(!treeAction.interaction.eligible){await look(0,-20);await page.waitForTimeout(300);treeAction=await state();}
    checks.treePrompt=treeAction.interaction.subject==='world_tree'&&treeAction.interaction.eligible;
    receipt.optionalTreeContext=treeAction.interaction;
    if(checks.treePrompt){await tap('e','interact');await page.waitForTimeout(900);}
    const reply=await state();
    checks.optionalTreeKeepsControl=reply.phase==='exploring'&&reply.activeCamera==='FirstPersonCamera'&&reply.observedLandmarks?.world_tree===true;
    await shot('09-optional-tree-observation');
    await driveTo(pathX(-622)+13,-620,4);
    checks.continuedAfterObservation=(await state()).phase==='exploring';
    await roadTo(-302);
    await driveTo(pathX(-285)-3,-275,4);
    await aimAt(pathX(-285)-2.5,-285);
    await page.waitForTimeout(4500);
    const animal=await state();
    checks.creaturePrompt=animal.interaction.kind==='ecology'&&animal.interaction.eligible;
    if(checks.creaturePrompt){
      await tap('e','interact');await page.waitForTimeout(900);
      const observed=await state();
      checks.creatureResponse=observed.observedEcology.aeral===true&&observed.ecologyResponses.some(r=>r.kind==='aeral'&&r.pulse>0);
      await shot('09b-observe-aeral');
      await page.waitForTimeout(1800);
    }
    await roadTo(-250);
    checks.driveAfterCreature=(await state()).phase==='exploring';
  }
  await stop();
  const saved=await state();
  await tap('Escape','pause_mission');await page.waitForTimeout(300);await shot('10-paused');
  checks.paused=(await state()).phase==='paused';
  // Native overlay buttons use keyboard focus; Escape returns through the same pause action.
  if(touch)await page.touchscreen.tap(155,130);
  else await tap('Escape','pause_mission');
  await page.waitForTimeout(300);
  checks.resume=(await state()).phase==='exploring';
  await tap('Escape','pause_mission');await page.waitForTimeout(300);
  if(touch)await page.touchscreen.tap(400,185);
  else {await page.keyboard.press('Tab');await page.keyboard.press('Tab');await page.keyboard.press('Tab');await page.keyboard.press('Enter');}
  await page.waitForFunction(()=>document.body.dataset.shellPhase==='home',null,{timeout:10000});
  checks.returnToTitle=await page.locator('#continue').isVisible();
  await shot('10b-return-title');
  await page.locator('#continue').click();await waitPlaying();
  checks.titleContinue=(await state()).phase==='exploring';
  await tap('Escape','pause_mission');await page.waitForTimeout(200);
  await page.reload();await page.locator('#continue').waitFor({state:'visible',timeout:15000});
  await page.locator('#continue').click();await waitPlaying();
  const restored=await state();
  checks.reloadContinue=Math.hypot(restored.position.x-saved.position.x,restored.position.z-saved.position.z)<1.5;
  checks.observationsRetained=JSON.stringify(restored.observedLandmarks)===JSON.stringify(saved.observedLandmarks);
  await shot('11-continued');
  if(args['storage-fault']){
    // Fault injection only in this disposable context, after the real driving video.
    await tap('Escape','pause_mission');await page.waitForTimeout(200);
    await page.evaluate(()=>{
      const key='signal-in-the-dust:expedition:v2:user://expedition_state.json';
      localStorage.setItem(key+'.bak',localStorage.getItem(key));
      localStorage.setItem(key,'{interrupted');
    });
    await page.reload();await page.locator('#continue').waitFor({state:'visible'});
    await page.locator('#continue').click();await waitPlaying();
    checks.backupRecoveredThroughEntry=Object.keys((await state()).observedLandmarks).length>0;
    receipt.storageFault='Corrupted primary in disposable browser only; backup came from this real journey';
  }
  }
  receipt.final=await state();receipt.metrics=await page.evaluate(()=>window.__EXPEDITION_METRICS__);
  checks.noPageErrors=errors.length===0;
  receipt.passed=Object.values(checks).every(Boolean);
}catch(e){receipt.error=String(e.stack||e);receipt.final=await state().catch(()=>null);await shot('failure').catch(()=>{});receipt.passed=false;}
finally{
  await controls([]).catch(()=>{});
  receipt.videoPath=page.video()?await page.video().path():null;
  await context.close();await browser.close();
  writeFileSync(resolve(out,'receipt.json'),JSON.stringify(receipt,null,2));
}
console.log(JSON.stringify({passed:receipt.passed,checks,error:receipt.error,output:out}));
process.exitCode=receipt.passed?0:1;
