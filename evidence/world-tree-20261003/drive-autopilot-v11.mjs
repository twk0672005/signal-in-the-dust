import { chromium } from 'file:///C:/Users/tsang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import { mkdirSync, writeFileSync } from 'node:fs';
const out='C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906/evidence/world-tree-20261003/tree-journey-autopilot-v11'; mkdirSync(out,{recursive:true});
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--enable-gpu','--use-gl=angle','--use-angle=d3d11']});
const context=await browser.newContext({viewport:{width:1440,height:900},locale:'zh-TW'}); const page=await context.newPage();
const errors=[]; page.on('pageerror',e=>errors.push(String(e))); page.on('console',m=>{if(m.type()==='error')errors.push(m.text()); if(m.type()==='log'&&m.text().includes('CONTACT_STAGE')) console.log('BROWSER_'+m.text());});
await page.goto('http://127.0.0.1:52880/');
await page.evaluate(()=>localStorage.clear());
await page.reload({waitUntil:'domcontentloaded'});
await page.locator('#start').click();
await page.waitForFunction(()=>document.body.dataset.shellPhase==='game',null,{timeout:180000});
if(await page.evaluate(()=>window.__EXPEDITION_BOOT_STATUS__?.stage==='confirm-new')){await page.keyboard.press('Shift+Tab');await page.keyboard.press('Enter');}
await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='exploring',null,{timeout:180000});
await page.locator('#canvas').click();
const pathX=z=>18*Math.sin((150-z)*.012)+4*Math.sin((150-z)*.033); const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
const samples=[]; let steer=''; let midCaptured=false; const begin=Date.now(); await page.keyboard.down('w');
while(Date.now()-begin<150000){
  const state=await page.evaluate(()=>window.__EXPEDITION_STATE__||null); if(!state)break;
  const target=pathX(state.position.z); const tangent=pathX(state.position.z-12)-target; const desired=Math.atan2(tangent,12); const error=wrap(desired-state.heading);
  let next=Math.abs(error)>.035?(error>0?'d':'a'):'';
  if(state.targetDistance<34) next=error>0?'d':error<0?'a':'';
  if(state.speedMps<1&&state.collisions>0) next=error>=0?'d':'a';
  if(next!==steer){if(steer)await page.keyboard.up(steer);if(next)await page.keyboard.down(next);steer=next;}
  if(samples.length===0||Date.now()-samples.at(-1).at>3000)samples.push({at:Date.now(),z:state.position.z,x:state.position.x,target,targetDistance:state.targetDistance,speed:state.speedMps,collisions:state.collisions,phase:state.phase});
  if(!midCaptured&&state.targetDistance<180){await page.screenshot({path:out+'/approach-mid.png'});midCaptured=true;}
  if(state.targetDistance<19)break;
  await page.waitForTimeout(160);
}
await page.keyboard.up('w'); if(steer)await page.keyboard.up(steer); await page.waitForTimeout(700);
await page.screenshot({path:out+'/approach-near.png'});
for(let turn=0;turn<24;turn++){
  const aim=await page.evaluate(()=>{const s=window.__EXPEDITION_STATE__;const p=s.position;const dx=-p.x;const dz=-650-p.z;const desired=Math.atan2(dx,-dz);const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));return {error:wrap(desired-s.heading)};});
  if(Math.abs(aim.error)<0.08)break;
  const key=aim.error>0?'d':'a';await page.keyboard.down(key);await page.waitForTimeout(90);await page.keyboard.up(key);
}
await page.waitForTimeout(250);
const before=await page.evaluate(()=>window.__EXPEDITION_STATE__||null);
let readyToInteract=before?.interaction?.eligible===true;
if(!readyToInteract){await page.keyboard.press('v');await page.waitForTimeout(500);readyToInteract=await page.evaluate(()=>window.__EXPEDITION_STATE__?.interaction?.eligible===true);}
if(readyToInteract){await page.keyboard.press('e');await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='ending',null,{timeout:30000}).catch(()=>{});}
const finalState=await page.evaluate(()=>window.__EXPEDITION_STATE__||null); await page.screenshot({path:out+'/arrival.png'}); await page.keyboard.press('v'); await page.waitForTimeout(600); await page.screenshot({path:out+'/arrival-third-person.png'});
writeFileSync(out+'/receipt.json',JSON.stringify({samples,before,finalState,readyToInteract,completionObserved:finalState?.phase==='ending',errors,seconds:(Date.now()-begin)/1000,pass:errors.length===0&&readyToInteract&&finalState?.phase==='ending'},null,2)); console.log(JSON.stringify({seconds:(Date.now()-begin)/1000,readyToInteract,completionObserved:finalState?.phase==='ending',beforePosition:before?.position,finalPosition:finalState?.position,targetDistance:finalState?.targetDistance,errors,last:samples.slice(-5)})); await browser.close();

