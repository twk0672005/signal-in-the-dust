// Project-owned isolated browser test. Never attaches to a user/browser-tool session.
import { mkdirSync, writeFileSync, appendFileSync, readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const options = Object.fromEntries(process.argv.slice(2).map(arg => {const [k,...v]=arg.replace(/^--/,'').split('=');return [k,v.join('=')||true];}));
const url = String(options.url || 'http://127.0.0.1:4216/?review=1');
if (!['127.0.0.1','localhost'].includes(new URL(url).hostname)) throw Error('Local candidate only');
const output = resolve(String(options.output || 'evidence/world-upgrade-20260926/web-smoke'));
mkdirSync(output,{recursive:true});
const modulePath = process.env.PLAYWRIGHT_MODULE || 'C:/Users/tsang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
const { chromium } = await import(pathToFileURL(modulePath));
const start = Date.now();
const events=[]; const checks={}; const partialReasons=[];
const log = (type,data) => { const item={at:new Date().toISOString(),type,data}; events.push(item);appendFileSync(resolve(output,'events.jsonl'),JSON.stringify(item)+'\n'); };
const markPartial = (id, detail) => { const item={id,detail}; partialReasons.push(item); log('partial',item); };
const launchArgs = ['--enable-gpu','--use-gl=angle','--use-angle='+String(options.angle||'d3d11'),'--force_high_performance_gpu'];
const [width,height]=String(options.viewport||'1280x720').split('x').map(Number);
const browser = await chromium.launch({channel:String(options.channel||'chromium'),headless: !options.headed,args:launchArgs});
const touchContext=options.mode==='touch'||!!options.touch;
const contextOptions={viewport:{width,height},deviceScaleFactor:1,locale:'en-US',hasTouch:touchContext,isMobile:touchContext,...(options.video?{recordVideo:{dir:resolve(output,'video'),size:{width,height}}}:{})};
let context = await browser.newContext(contextOptions);
let page = await context.newPage();
function observePage(target){
  target.on('console',message=>log('console',{level:message.type(),text:message.text()}));
  target.on('pageerror',error=>log('pageerror',error.message));
  target.on('crash',()=>log('crash','renderer crashed'));
  target.on('requestfailed',request=>log('requestfailed',{url:request.url(),failure:request.failure()}));
}
observePage(page);
let receipt={url,output,harnessSha256:createHash('sha256').update(readFileSync(new URL(import.meta.url))).digest('hex'),pid:process.pid,browser:browser.version(),headless:!options.headed,launchArgs,checks,kind:'isolated_chromium_actual_web',mode:options.mode||'smoke',physicalMobile:false};
if(options.artifact){const folder=resolve(String(options.artifact));receipt.artifactFiles=readdirSync(folder).filter(n=>/\.(pck|wasm|html|js|css)$/.test(n)).sort().map(name=>{const bytes=readFileSync(resolve(folder,name));return {name,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')}});}
const save = () => writeFileSync(resolve(output,'receipt.json'),JSON.stringify({...receipt,seconds:(Date.now()-start)/1000,events},null,2));
const state = () => page.evaluate(()=>({state:window.__EXPEDITION_STATE__,probe:window.__WORLD_REVIEW_PROBE__,review:window.__WORLD_REVIEW__}));
const command = async data => {
  const accepted=await page.evaluate(data=>window.expeditionReview(JSON.stringify(data)),data);
  if(accepted===false)throw Error('Inspection queue refused request');
  if(data.action==='view')await page.waitForFunction(id=>window.__WORLD_REVIEW__?.view===id,data.id,{timeout:15000});
};
let held=new Set();
async function keys(next){const desired=new Set(next);for(const key of held)if(!desired.has(key))await page.keyboard.up(key);for(const key of desired)if(!held.has(key))await page.keyboard.down(key);if([...desired].sort().join()!==[...held].sort().join())log('keys',[...desired]);held=desired;}
const pathX=z=>18*Math.sin((150-z)*.012)+4*Math.sin((150-z)*.033);
const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
const waitExploring=()=>page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='exploring'&&document.body.dataset.shellPhase==='game',null,{timeout:150000});
const browserFocusState=()=>page.evaluate(()=>({visibilityState:document.visibilityState,hidden:document.hidden,hasFocus:document.hasFocus(),activeElement:document.activeElement?.id||document.activeElement?.tagName||null,shellPhase:document.body.dataset.shellPhase}));
async function captureBilingualUi(){
  const capture=()=>page.evaluate(()=>({lang:document.documentElement.lang,shellPhase:document.body.dataset.shellPhase,homeHidden:document.getElementById('home').hidden,start:document.getElementById('start').textContent.trim(),continue:document.getElementById('continue').textContent.trim(),toggle:document.getElementById('language-toggle').textContent.trim(),toggleLabel:document.getElementById('language-toggle').getAttribute('aria-label')}));
  const english=await capture(); await page.screenshot({path:resolve(output,'ui-home-en.png')});
  await page.locator('#language-toggle').click();
  await page.waitForFunction(()=>document.documentElement.lang==='zh-Hant'&&document.getElementById('start').textContent.includes('開始探索'));
  const traditionalChinese=await capture(); await page.screenshot({path:resolve(output,'ui-home-zh-TW.png')});
  await page.locator('#language-toggle').click();
  await page.waitForFunction(()=>document.documentElement.lang==='en'&&document.getElementById('start').textContent.includes('Start exploring'));
  const restoredEnglish=await capture(); receipt.bilingualUi={english,traditionalChinese,restoredEnglish};
  checks.bilingualUi=english.lang==='en'&&english.shellPhase==='home'&&!english.homeHidden&&english.start==='Start exploring'&&english.continue==='Continue'&&english.toggle==='繁中'&&traditionalChinese.lang==='zh-Hant'&&traditionalChinese.start==='開始探索'&&traditionalChinese.continue==='繼續旅程'&&traditionalChinese.toggle==='EN'&&restoredEnglish.lang==='en'&&restoredEnglish.start==='Start exploring';
}
async function driveToRegion(region,targetZ,trace){
  const deadline=Date.now()+150000;
  while(Date.now()<deadline){
    const sample=await state(); const s=sample.state; const p=s?.position;
    if(s?.phase!=='exploring') throw Error(`Performance travel interrupted by phase ${s?.phase}`);
    const current=sample.probe?.region;
    trace.push({at:Date.now(),region:current,...p,heading:s.heading,speed:s.speed});
    if(current===region&&p.z<=targetZ+18){await keys(['Space']);await page.waitForTimeout(750);await keys([]);return await state();}
    const look=10; const desired=Math.atan2(pathX(p.z-look)-p.x,look); const error=wrap(desired-s.heading);
    const next=[]; if(Math.abs(error)<.25||Math.abs(s.speed)<10)next.push('w'); if(error>.025)next.push('d');else if(error<-.025)next.push('a'); if(Math.abs(error)<.1)next.push('Shift');
    await keys(next); await page.waitForTimeout(90);
  }
  throw Error(`Timed out travelling to ${region} by real keyboard input`);
}

async function movingWorkload(region,nearZ,farZ,seconds){
  const trace=[],inputs=[],started=Date.now();let forward=true,interaction=false,camera=false,backCamera=false,distance=0,last=null;
  const encounterZ={ember_rift:-65,veil_marsh:-272,pale_decay:-457}[region];
  while(Date.now()-started<(seconds+25)*1000){
    const sample=await state(),s=sample.state,p=s.position,t=(Date.now()-started)/1000;
    if(s.phase!=='exploring')throw Error('Workload interrupted: '+s.phase);
    if(sample.review.measurement.status==='complete')break;
    if(last)distance+=Math.hypot(p.x-last.x,p.z-last.z);last=p;
    trace.push({seconds:t,region:sample.probe.region,position:p,speed:s.speed,heading:s.heading,view:s.view,interactionTarget:sample.probe.interactionTarget,observed:s.observedEcology});
    if(p.z<=farZ)forward=false;if(p.z>=nearZ)forward=true;
    if(!camera&&t>=6){await page.keyboard.press('v');camera=true;inputs.push('camera');}
    if(!backCamera&&t>=23){await page.keyboard.press('v');backCamera=true;inputs.push('camera-return');}
    if(!interaction&&((encounterZ!==undefined&&forward&&p.z<=encounterZ+5)||t>=14)){
      await keys(['Space']);await page.waitForTimeout(650);
      const before=await state();await page.keyboard.press('e');await page.waitForTimeout(250);
      const after=await state();inputs.push('interact');interaction=true;
      log('workload-interaction',{region,before:before.probe,after:after.probe,beforeObserved:before.state.observedEcology,afterObserved:after.state.observedEcology});
    }
    const look=8;
    const desired=forward?Math.atan2(pathX(p.z-look)-p.x,look):Math.atan2(p.x-pathX(p.z+look),look);
    const error=wrap(desired-s.heading),steer=error*(s.speed<-.1?-1:1);
    const next=[forward?'w':'s'];
    if(steer>.03)next.push('d');else if(steer<-.03)next.push('a');
    await keys(next);await page.waitForTimeout(120);
  }
  await keys(['Space']);await page.waitForTimeout(500);await keys([]);
  const final=await state();if(final.review.measurement.status!=='complete')throw Error('Moving profile never completed');
  return {method:'real keyboard road shuttle with steering, V camera, E interaction attempt; no teleport; all intervals retained',trace,inputs,distance,movingFraction:trace.filter(x=>Math.abs(x.speed)>1).length/Math.max(1,trace.length)};
}

try {
  await page.goto(url,{waitUntil:'domcontentloaded',timeout:30000});
  await captureBilingualUi();
  if(options.low||options.profile==='low720'){
    await page.locator('#open-settings').click();
    await page.locator('#setting-quality').selectOption('true');
    await page.locator('#settings-done').click();
  }
  if(options.locale==='zh_TW')await page.locator('#language-toggle').click();
  await page.locator('#start').click();
  await waitExploring();
  checks.boot=true; receipt.bootSeconds=(Date.now()-start)/1000; receipt.bootTimings=await page.evaluate(()=>window.__EXPEDITION_BOOT_TIMINGS__||null);
  if(options.locale)checks.gameLocale=(await state()).state.settings.locale===options.locale;
  if(options.low){await command({action:'quality',low:true});await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.settings?.low_quality===true);}
  receipt.runtime=await page.evaluate(()=>{const canvas=document.getElementById('canvas');const gl=canvas.getContext('webgl2');const ext=gl?.getExtension('WEBGL_debug_renderer_info');return {userAgent:navigator.userAgent,viewport:[innerWidth,innerHeight],canvas:[canvas.width,canvas.height],dpr:devicePixelRatio,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,vendor:ext?gl.getParameter(ext.UNMASKED_VENDOR_WEBGL):null,state:window.__EXPEDITION_STATE__,review:window.__WORLD_REVIEW__};});
  await page.screenshot({path:resolve(output,'spawn.png')});
  save(); console.log(JSON.stringify({stage:'boot',seconds:receipt.bootSeconds,renderer:receipt.runtime.renderer}));
  if(options.mode==='capture') {
    receipt.views=[];
    for(const id of (options.views?String(options.views).split(','):['aurora_shelf','aurora_shelf_reverse','aurora_shelf_side','ember_rift','ember_rift_reverse','ember_rift_side','veil_marsh','veil_marsh_reverse','veil_marsh_side','pale_decay','pale_decay_reverse','pale_decay_side','veyra','aeral','morrow','shore','microfauna'])){
      await command({action:'view',id});
      await page.waitForTimeout(1200);
      await page.screenshot({path:resolve(output,id+'.png')});
      receipt.views.push(await page.evaluate(()=>({review:window.__WORLD_REVIEW__,state:window.__EXPEDITION_STATE__,metrics:window.__EXPEDITION_METRICS__})));
    }
    checks.allViewsCaptured=receipt.views.length===(options.views?String(options.views).split(',').length:17);
  }
  if(options.mode==='motion'){
    receipt.motion={method:'fixed inspection views; real runtime time and read-only pose snapshots, not player-interaction proof',samples:[]};
    for(const species of ['veyra','aeral','morrow']){
      await command({action:'view',id:species}); await page.waitForTimeout(1500);
      for(let frame=0;frame<6;frame++){
        const id=`${species}-${frame}`;
        await command({action:'inspect_ecology',id});
        await page.waitForFunction(id=>window.__WORLD_REVIEW__?.ecologyInspection?.id===id,id);
        const inspection=await page.evaluate(()=>window.__WORLD_REVIEW__.ecologyInspection);
        await page.screenshot({path:resolve(output,`motion-${id}.png`)});
        receipt.motion.samples.push({species,frame,inspection}); await page.waitForTimeout(450);
      }
    }
    const poses=species=>receipt.motion.samples.filter(s=>s.species===species).map(s=>s.inspection.creatures.find(c=>c.visual.species===species)?.visual);
    checks.motionSamples=receipt.motion.samples.length===18&&['veyra','aeral','morrow'].every(s=>poses(s).every(Boolean));
    checks.aeralWingMotion=new Set(poses('aeral').map(p=>JSON.stringify(p?.wing_angles))).size>1;
    checks.morrowCrownMotion=new Set(poses('morrow').map(p=>JSON.stringify(p?.crown_angles))).size>1;
    checks.veyraBreathing=new Set(poses('veyra').map(p=>p?.body_position)).size>1;
    const feet=poses('veyra').flatMap(p=>p?.feet||[]).filter(f=>f.lift<.001);
    receipt.motion.plantedFootClearance={samples:feet.length,maxAbsolute:Math.max(...feet.map(f=>Math.abs(f.clearance)))};
    checks.veyraPlantedContact=feet.length>0&&feet.every(f=>Math.abs(f.clearance)<.15);
  }
  if(options.mode==='performance' && options.video)throw Error('Video is forbidden during profiling');
  if(options.mode==='performance'){
    receipt.performanceMethod={camera:'player camera only',travel:'real keyboard travel plus continuous forward/reverse road shuttle, steering, camera and interaction input throughout each sample',measurement:'monotonic engine callback intervals including stalls',screenshotsDuringProfiling:false,reviewCameraCommands:false,declaredWorkload:options.workload||null};
    receipt.profiles=[]; receipt.performanceTravel=[];
    const targets=[['aurora_shelf',100,120,15],['ember_rift',-40,-25,-140],['veil_marsh',-215,-200,-320],['pale_decay',-400,-385,-530]];
    const requestedProfiles=[{name:'standard1080',width:1920,height:1080,low:false},{name:'low720',width:1280,height:720,low:true}].filter(p=>!options.profile||p.name===options.profile);
    if(!requestedProfiles.length)throw Error('Unknown performance profile');
    receipt.performanceMethod.requestedProfiles=requestedProfiles.map(p=>p.name);
    receipt.profileRuntime=[];
    for(const [index,profile] of requestedProfiles.entries()){
      if(index){
        // 每個品質配置使用全新測試存檔，避免觸發既有旅程的重設確認。
        await keys([]); await context.close();
        context=await browser.newContext(contextOptions); page=await context.newPage(); observePage(page);
        await page.goto(url,{waitUntil:'domcontentloaded',timeout:30000});
        await page.getByRole('button',{name:'Start exploring',exact:true}).click();
        await waitExploring();
      }
      await page.setViewportSize({width:profile.width,height:profile.height});
      await command({action:'quality',low:profile.low});
      await page.waitForFunction(low=>window.__EXPEDITION_STATE__?.settings?.low_quality===low,profile.low);
      receipt.profileRuntime.push(await page.evaluate(name=>{const c=document.getElementById('canvas'),gl=c.getContext('webgl2'),e=gl.getExtension('WEBGL_debug_renderer_info');return {profile:name,renderer:e?gl.getParameter(e.UNMASKED_RENDERER_WEBGL):null,visibility:document.visibilityState,focused:document.hasFocus(),canvas:[c.width,c.height],dpr:devicePixelRatio};},profile.name));
      for(const [region,targetZ,nearZ,farZ] of targets){
        const travel=[]; const atRegion=await driveToRegion(region,targetZ,travel); receipt.performanceTravel.push({profile:profile.name,region,travel});
        await page.waitForTimeout(3000); // fixed warm-up, excluded from measured workload
        const before=await state();
        if(before.review?.view!=='play') throw Error(`Performance sample ${profile.name}/${region} used review camera`);
        const seconds=Number(options.duration||30);
        await command({action:'measure',seconds});
        await page.waitForFunction(()=>window.__WORLD_REVIEW__?.measurement?.status==='measuring');
        const workload=await movingWorkload(region,nearZ,farZ,seconds);
        const sample=await state(); const m=sample.review.measurement;
        const canvas=await page.locator('#canvas').evaluate(c=>({width:c.width,height:c.height,clientWidth:c.clientWidth,clientHeight:c.clientHeight}));
        receipt.profiles.push({profile:profile.name,region,canvas,measurement:m,workload,warmupSeconds:3,playerBefore:before.state.position,playerAfter:sample.state.position,review:sample.review,travelCompletedAt:atRegion.state.position});
        save();log('profile',{profile:profile.name,region,fps:m.meanFps,p95:m.p95ms,view:sample.review.view,low:m.low});
      }
    }
    const standard=receipt.profiles.filter(p=>p.profile==='standard1080'); const low=receipt.profiles.filter(p=>p.profile==='low720');
    const complete=rows=>rows.length===4&&rows.every(p=>p.measurement?.status==='complete'&&Array.isArray(p.measurement.rawFrameMs)&&p.measurement.rawFrameMs.length>0);
    const playerWorkload=rows=>rows.every(p=>p.review?.view==='play'&&p.measurement?.fixedViewNotJourney===false&&p.travelCompletedAt&&p.playerBefore&&p.playerAfter&&p.workload?.distance>35&&p.workload?.movingFraction>.55&&p.workload?.trace.every(x=>x.region===p.region)&&p.workload?.inputs.includes('camera')&&p.workload?.inputs.includes('interact'));
    checks.hardwareRenderer=!/SwiftShader|llvmpipe|software/i.test(receipt.runtime.renderer||'software');
    checks.performanceSamplesComplete=requestedProfiles.every(p=>complete(receipt.profiles.filter(row=>row.profile===p.name)));
    checks.performanceUsesPlayerWorkload=playerWorkload(receipt.profiles)&&receipt.performanceTravel.length===requestedProfiles.length*4&&receipt.performanceTravel.every(sample=>sample.travel.length>0);
    checks.lowQualityApplied=receipt.profiles.length===requestedProfiles.length*4&&receipt.profiles.every(p=>p.measurement?.low===(p.profile==='low720'));
    if(standard.length)checks.standard1080=complete(standard)&&standard.every(p=>p.measurement.meanFps>=59&&p.measurement.p95ms<=25&&p.canvas.width===1920&&p.canvas.height===1080);
    if(low.length)checks.low720=complete(low)&&low.every(p=>p.measurement.meanFps>=30&&p.canvas.width===1280&&p.canvas.height===720);
  }
  if(options.mode==='journey'){
    // All movement below is keyboard input. No inspection view command/teleport.
    await page.locator('#canvas').click({position:{x:width*.5,y:height*.3}});
    const trace=[];const visited=new Set();const observations=[];let lastRegion='';let changedView=false;
    receipt.routeTrace=trace;receipt.observationTransitions=observations;
    // Authored roadside habitats; stop before querying the speed-gated prompt.
    const stops=[{z:-65,kind:'veyra'},{z:-272,kind:'aeral'},{z:-457,kind:'root_choir'}];
    const routeStart=Date.now();const initial=await state();receipt.journeyInitial=initial;
    if(initial.state.position.z<130)throw Error('Journey did not begin at real spawn');
    while(Date.now()-routeStart<150000){
      const sample=await state();const s=sample.state;const p=s.position;
      if(s.phase!=='exploring')throw Error('Driving interrupted by phase '+s.phase);
      const region=sample.probe?.region||(p.z>-10?'aurora_shelf':p.z>-170?'ember_rift':p.z>-350?'veil_marsh':'pale_decay');
      visited.add(region);trace.push({at:Date.now(),...s.position,heading:s.heading,speed:s.speed,region,observed:s.observedEcology,view:s.view});
      if(trace.length%50===0)save();
      if(region!==lastRegion){await page.screenshot({path:resolve(output,'journey-'+region+'.png')});lastRegion=region;log('entered',region);}
      if(p.z<-560)break;
      if(!changedView&&p.z<100){await page.keyboard.press('v');changedView=true;}
      if(stops.length&&p.z<stops[0].z){
        const stop=stops.shift();await keys(['Space']);await page.waitForTimeout(1700);let pre=await state();
        const approach=[];
        // Wall-time input and shader stalls vary the braking endpoint. Approach
        // by real keys until the unchanged speed/distance/facing/LOS gate shows E.
        for(let attempt=0;attempt<7&&pre.probe?.interactionTarget!=='ecology';attempt++){
          approach.push({attempt,state:pre.state,probe:pre.probe});
          await keys(['w']);await page.waitForTimeout(450);
          await keys(['Space']);await page.waitForTimeout(850);await keys([]);
          pre=await state();
        }
        if(pre.probe?.interactionTarget==='ecology'){await page.keyboard.press('e');await page.waitForTimeout(500);}
        const post=await state();
        observations.push({kind:stop.kind,target:pre.probe?.interactionTarget,before:pre.state.observedEcology,after:post.state.observedEcology,position:post.state.position,approach});
        await page.screenshot({path:resolve(output,'observe-'+stop.kind+'.png')});save();
        if(options.video){
          await keys(['Space']);await page.mouse.move(width*.5,height*.45);await page.mouse.down({button:'right'});
          await page.mouse.move(width*.5+240,height*.45-55,{steps:24});await page.waitForTimeout(650);
          await page.mouse.move(width*.5-260,height*.45+30,{steps:36});await page.waitForTimeout(650);
          await page.mouse.up({button:'right'});await page.waitForTimeout(500);log('real-pointer-look',{kind:stop.kind,state:await state()});
        }
      }
      const look=10;const desired=Math.atan2(pathX(p.z-look)-p.x,look);const error=wrap(desired-s.heading);
      const next=[];if(Math.abs(error)<.25||Math.abs(s.speed)<10)next.push('w');
      if(error>.025)next.push('d');else if(error<-.025)next.push('a');
      if(p.z<125&&p.z>100&&Math.abs(error)<.10)next.push('Shift');
      await keys(next);await page.waitForTimeout(90);
    }
    await keys(['Space']);await page.waitForTimeout(700);await keys([]);
    const stopped=await state();receipt.journeyFinal=stopped;receipt.routeTrace=trace;receipt.observationTransitions=observations;
    checks.fourRegionRealInput=visited.size===4&&stopped.state.position.z<-560;
    checks.noInspectionTeleport=stopped.review.view==='play'&&stopped.review.revision===0;
    checks.cameraSwitch=changedView&&stopped.state.view!==initial.state.view;
    checks.ecologyInteraction=Object.keys(stopped.state.observedEcology||{}).length>Object.keys(initial.state.observedEcology||{}).length;
    checks.allSpeciesObserved=['veyra','aeral','root_choir'].every(kind=>stopped.state.observedEcology?.[kind]===true);
    checks.brakeStopped=Math.abs(stopped.state.speed)<.05;
    await page.keyboard.press('v');await page.waitForTimeout(500);const firstPerson=await state();
    await page.screenshot({path:resolve(output,'journey-first-person.png')});
    await page.keyboard.press('v');await page.waitForTimeout(500);const thirdPerson=await state();
    checks.cameraRoundTrip=firstPerson.state.view==='first_person'&&thirdPerson.state.view==='third_person';
    await keys(['s']);await page.waitForTimeout(900);const reversed=await state();receipt.reverse=reversed;
    checks.reverseInput=reversed.state.speed<-.5&&Math.hypot(reversed.state.position.x-stopped.state.position.x,reversed.state.position.z-stopped.state.position.z)>1;
    await keys(['Space']);await page.waitForTimeout(600);await keys([]);
    await keys(['w','Shift']);await page.waitForTimeout(600);await page.keyboard.press('Escape');await keys([]);
    await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='paused');
    const paused=await state();await page.waitForTimeout(500);const heldPause=await state();receipt.paused=paused;
    checks.pauseReleased=paused.state.phase==='paused'&&Math.hypot(heldPause.state.position.x-paused.state.position.x,heldPause.state.position.z-paused.state.position.z)<.03&&!heldPause.state.boosting;
    await page.screenshot({path:resolve(output,'paused.png')});
    await page.reload({waitUntil:'domcontentloaded'});
    const continueHome=await page.locator('#continue').evaluate(button=>({visible:!button.hidden&&getComputedStyle(button).display!=='none',disabled:button.disabled,text:button.textContent.trim(),savedAvailable:button.dataset.savedAvailable||null}));
    receipt.continueHome=continueHome;
    checks.saveContinueAvailable=continueHome.visible&&!continueHome.disabled&&continueHome.text==='Continue';
    await page.screenshot({path:resolve(output,'continue-home.png')});
    await page.locator('#continue').click();await waitExploring();
    const continued=await state();receipt.continued=continued;
    checks.saveContinueRestored=Math.hypot(continued.state.position.x-paused.state.position.x,continued.state.position.z-paused.state.position.z)<.3&&continued.state.view===paused.state.view&&JSON.stringify(continued.state.observedEcology)===JSON.stringify(paused.state.observedEcology);
    await page.screenshot({path:resolve(output,'continued.png')});
    receipt.focusCoverage={status:'not-run',reason:'Focus requires --mode=focus so an unsupported browser foreground transition cannot invalidate input/save journey evidence.'};
  }
  if(options.mode==='shorejourney'){
    await page.locator('#canvas').click({position:{x:width*.5,y:height*.3}});
    const trace=[];receipt.shoreTrace=trace;receipt.shoreStops=[];
    const initial=await state();
    if(initial.state.position.z<130)throw Error('Shore journey must begin at real spawn');
    await driveToRegion('veil_marsh',-310,trace);
    const pool={x:pathX(-342)-32,z:-342};
    async function drivePoint(target,label){
      const end=Date.now()+65000;
      let reached=false;
      while(Date.now()<end){
        const sample=await state(),s=sample.state,p=s.position;
        if(s.phase!=='exploring')throw Error('Shore route interrupted by '+s.phase);
        const distance=Math.hypot(target.x-p.x,target.z-p.z);
        trace.push({label,at:Date.now(),position:p,speed:s.speed,heading:s.heading,distance});
        if(distance<2.5){reached=true;break;}
        const desired=Math.atan2(target.x-p.x,p.z-target.z),error=wrap(desired-s.heading);
        const next=[];
        if((Math.abs(error)>.5&&Math.abs(s.speed)>3)||(distance<7&&Math.abs(s.speed)>4))next.push('Space');else next.push('w');
        if(error>.045)next.push('d');else if(error<-.045)next.push('a');
        await keys(next);await page.waitForTimeout(100);
      }
      await keys(['Space']);await page.waitForTimeout(650);await keys([]);
      const stopped=await state();receipt.shoreStops.push({label,target,reached,state:stopped});save();
      if(!reached)throw Error('Real driving did not reach shore waypoint '+label);
      await page.screenshot({path:resolve(output,label+'.png')});
    }
    await drivePoint({x:pool.x+19,z:pool.z+19},'shore-entry');
    await drivePoint({x:pool.x+8,z:pool.z+5},'shore-near');
    await page.keyboard.press('e');await page.waitForTimeout(400);
    receipt.shoreInteraction={kind:'real E input; resulting state recorded without asserting quest completion',sample:await state()};
    await page.keyboard.press('v');await page.waitForTimeout(500);
    await page.screenshot({path:resolve(output,'shore-third-person.png')});
    await drivePoint({x:pool.x+15,z:pool.z-11},'shore-side');
    await page.mouse.move(width*.5,height*.45);await page.mouse.down({button:'right'});
    await page.mouse.move(width*.5+390,height*.42,{steps:32});await page.waitForTimeout(500);
    await page.screenshot({path:resolve(output,'shore-lookback-input.png')});
    await page.mouse.up({button:'right'});
    const beforeReverse=await state();await keys(['s']);await page.waitForTimeout(1300);await keys(['Space']);await page.waitForTimeout(700);await keys([]);
    const afterReverse=await state();receipt.shoreFinal=afterReverse;
    checks.shoreRealApproach=receipt.shoreStops.length===3&&receipt.shoreStops.every(s=>s.reached);
    checks.shoreNoInspectionTeleport=afterReverse.review.view==='play'&&afterReverse.review.revision===0;
    checks.shoreReverseMovement=Math.hypot(afterReverse.state.position.x-beforeReverse.state.position.x,afterReverse.state.position.z-beforeReverse.state.position.z)>.5;
    await page.keyboard.press('Escape');await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='paused');
    const saved=await state();await page.reload({waitUntil:'domcontentloaded'});await page.locator('#continue').click();await waitExploring();
    const resumed=await state();receipt.shoreResumed=resumed;
    checks.shoreContinue=Math.hypot(saved.state.position.x-resumed.state.position.x,saved.state.position.z-resumed.state.position.z)<.3;
  }
  if(options.mode==='focus'){
    // A second Playwright page is only a calibration attempt. Never synthesize a
    // visibility/blur event or call a page foregrounded when the browser says it is not.
    const focusCdp=await context.newCDPSession(page);
    // Playwright enables focus emulation in CRPage initialization. Disable it
    // in this isolated test page so visibility/focus represent the real window.
    await focusCdp.send('Emulation.setFocusEmulationEnabled',{enabled:false});
    receipt.focusEmulationDisabled=true;
    await page.bringToFront();
    await page.locator('#canvas').click({position:{x:width*.5,y:height*.3}});
    await page.waitForTimeout(300);
    if((await state()).state.phase==='paused'){await page.keyboard.press('Escape');await waitExploring();}
    await keys(['w','Shift']); await page.waitForTimeout(600);
    const beforeDriving=await state();receipt.focusBeforeDriving=beforeDriving;
    if(beforeDriving.state.phase!=='exploring'||beforeDriving.state.speed<.5)throw Error('Focus fixture did not begin in actual moving play');
    const before=await browserFocusState();
    const other=await context.newPage(); await other.goto('about:blank'); await other.bringToFront(); await other.waitForTimeout(800);
    let backgrounded=await browserFocusState();
    let minimizedWindow=null;
    if(!backgrounded.hidden&&backgrounded.hasFocus&&options.headed){
      const windowCdp=await context.newCDPSession(page);
      const info=await windowCdp.send('Browser.getWindowForTarget');
      await windowCdp.send('Browser.setWindowBounds',{windowId:info.windowId,bounds:{windowState:'minimized'}});
      await new Promise(r=>setTimeout(r,1000));
      backgrounded=await browserFocusState();minimizedWindow={cdp:windowCdp,id:info.windowId};
      receipt.actualWindowMinimized=true;
    }
    const transitionObserved=before.hasFocus===true&&before.hidden===false&&(backgrounded.visibilityState==='hidden'||backgrounded.hidden===true||backgrounded.hasFocus===false);
    receipt.focusCalibration={method:'actual browser visibilityState/document.hasFocus observations around Playwright bringToFront; no injected DOM events',before,backgrounded,transitionObserved};
    if(!transitionObserved){
      markPartial('focus-transition-unavailable','A real focused/visible to unfocused/hidden transition was not observed; focus pause was not asserted.');
    }else{
      await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='paused',null,{timeout:5000,polling:100});
      const paused=await state(); receipt.focusLoss=paused;
      checks.focusLossPaused=paused.state.phase==='paused'&&!paused.state.boosting&&Math.abs(paused.state.speed)<.05;
      if(minimizedWindow)await minimizedWindow.cdp.send('Browser.setWindowBounds',{windowId:minimizedWindow.id,bounds:{windowState:'normal'}});
      await page.bringToFront(); const foregrounded=await browserFocusState(); receipt.focusCalibration.foregrounded=foregrounded;
      if(foregrounded.hasFocus!==true) markPartial('focus-foreground-unavailable','The game page could not regain observed browser focus after calibration.');
      else {
        await keys([]); await page.keyboard.press('Escape'); await waitExploring(); await page.waitForTimeout(700);
        const resumed=await state(); receipt.focusResumed=resumed;
        checks.focusResumeNoStickyInput=Math.abs(resumed.state.speed)<.05&&!resumed.state.boosting;
      }
    }
    if(minimizedWindow)await minimizedWindow.cdp.send('Browser.setWindowBounds',{windowId:minimizedWindow.id,bounds:{windowState:'normal'}}).catch(()=>{});
    await keys([]); await other.close();
    await focusCdp.detach();
  }
  if(options.mode==='touch'){
    const cdp=await context.newCDPSession(page);
    const expectedActions=['drive_forward','drive_reverse','brake','drive_boost','turn_left','turn_right','toggle_camera','pause_mission','interact','slow'];
    const controls=await page.locator('#touch-controls [data-action]').evaluateAll(buttons=>buttons.map(button=>({action:button.dataset.action,text:button.textContent.trim(),visible:getComputedStyle(button).display!=='none'})));
    const boxes=Object.fromEntries(await page.locator('#touch-controls [data-action]').evaluateAll(buttons=>buttons.map(button=>{const box=button.getBoundingClientRect();return [button.dataset.action,{x:box.x+box.width/2,y:box.y+box.height/2}]})));
    const touch=(actions,type)=>cdp.send('Input.dispatchTouchEvent',{type,touchPoints:actions.map(([action,id])=>({...boxes[action],id}))});
    if(expectedActions.some(action=>!boxes[action])) throw Error('Required touch control missing');
    const initial=await state();
    await touch([['drive_forward',1]],'touchStart'); await page.waitForTimeout(1600); await touch([],'touchEnd'); await page.waitForTimeout(350);
    const driven=await state();
    await touch([['drive_forward',1],['turn_right',2]],'touchStart'); await page.waitForTimeout(700); await touch([],'touchEnd'); await page.waitForTimeout(300);
    const steered=await state();
    await touch([['drive_forward',1],['drive_boost',2]],'touchStart'); await page.waitForTimeout(700);
    const boosted=await state(); await touch([],'touchEnd'); await page.waitForTimeout(300);
    receipt.touch={initial,driven,steered,boosted,controls};
    checks.touchControlsPresent=expectedActions.every(action=>controls.some(control=>control.action===action&&control.visible));
    checks.touchEnabled=driven.state.touchEnabled;
    checks.touchDrove=Math.hypot(driven.state.position.x-initial.state.position.x,driven.state.position.z-initial.state.position.z)>1;
    checks.touchSteered=Math.abs(wrap(steered.state.heading-driven.state.heading))>.01;
    checks.touchBoosted=boosted.state.boosting&&boosted.state.speed>.5;
    await touch([['brake',1]],'touchStart');await page.waitForTimeout(700);await touch([],'touchEnd');
    const touchBraked=await state();checks.touchBrake=Math.abs(touchBraked.state.speed)<.3;
    await touch([['drive_reverse',1]],'touchStart');await page.waitForTimeout(900);await touch([],'touchEnd');
    const touchReversed=await state();checks.touchReverse=touchReversed.state.speed<-.5;
    await touch([['brake',1]],'touchStart');await page.waitForTimeout(700);await touch([],'touchEnd');
    await page.locator('#touch-controls [data-action="toggle_camera"]').tap();await page.waitForTimeout(350);
    const touchCamera=await state();checks.touchCamera=touchCamera.state.view!==touchReversed.state.view;
    await page.locator('#touch-controls [data-action="toggle_camera"]').tap();await page.waitForTimeout(350);
    receipt.touch.moreControls={touchBraked,touchReversed,touchCamera};
    const pause=page.locator('#touch-controls [data-action="pause_mission"]'); await pause.tap();
    await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='paused'); checks.touchPause=true;
    await page.setViewportSize({width:720,height:1280});
    await page.waitForFunction(()=>innerHeight>innerWidth&&getComputedStyle(document.getElementById('rotate-phone')).display==='flex');
    const portrait=await state(); const portraitUi=await page.evaluate(()=>({viewport:[innerWidth,innerHeight],rotateDisplay:getComputedStyle(document.getElementById('rotate-phone')).display,touchDisplay:getComputedStyle(document.getElementById('touch-controls')).display}));
    await page.screenshot({path:resolve(output,'touch-portrait-paused.png')});
    await page.setViewportSize({width:1280,height:720});
    await page.waitForFunction(()=>innerWidth>=innerHeight&&getComputedStyle(document.getElementById('rotate-phone')).display==='none');
    const pausedLandscape=await state();
    // 暫停時隱藏駕駛按鍵是正確行為；先驗暫停，再以真輸入恢復。
    await page.keyboard.press('Escape'); await waitExploring();
    await page.waitForFunction(()=>getComputedStyle(document.getElementById('touch-controls')).display==='block');
    const landscapeUi=await page.evaluate(()=>({viewport:[innerWidth,innerHeight],rotateDisplay:getComputedStyle(document.getElementById('rotate-phone')).display,touchDisplay:getComputedStyle(document.getElementById('touch-controls')).display}));
    receipt.viewportResize={portrait:{state:portrait,ui:portraitUi},pausedLandscape,landscape:landscapeUi};
    checks.viewportResizeSafety=portrait.state.phase==='paused'&&pausedLandscape.state.phase==='paused'&&portraitUi.rotateDisplay==='flex'&&landscapeUi.rotateDisplay==='none'&&landscapeUi.touchDisplay==='block';
    await page.screenshot({path:resolve(output,'touch-landscape.png')});
  }

  if(options.mode==='material'){
    receipt.materialPairs=[];
    for(const target of [{view:'rock_material',scope:'world',modes:['authored','original']},{view:'flora_material',scope:'world',modes:['authored','original']},...['veyra','aeral','morrow'].map(view=>({view,scope:'creature',modes:['current','previous','authored_factors']}))]){
      await command({action:'view',id:target.view});await page.waitForTimeout(1600);
      await command({action:'freeze',enabled:true});await page.waitForFunction(()=>window.__WORLD_REVIEW__?.frozen===true);
      // Compile each actual material once before measuring the frozen comparison.
      for(const mode of target.modes){await command({action:'material',scope:target.scope,mode});await page.waitForFunction(mode=>window.__WORLD_REVIEW__?.materialComparison?.mode===mode,mode);await page.waitForTimeout(800);}
      const rows=[];
      for(const mode of target.modes){
        await command({action:'material',scope:target.scope,mode});await page.waitForFunction(mode=>window.__WORLD_REVIEW__?.materialComparison?.mode===mode,mode);
        await page.waitForTimeout(1000);const id=target.view+'-'+mode;
        await command({action:'diagnostics',id});await page.waitForFunction(id=>window.__WORLD_REVIEW__?.diagnostics?.id===id,id);
        const before=await state();await page.screenshot({path:resolve(output,'material-'+id+'.png')});
        rows.push({mode,state:before,metrics:await page.evaluate(()=>window.__EXPEDITION_METRICS__)});
      }
      const first=rows[0].state.review;
      const matched=rows.every(row=>row.state.review.frozen&&row.state.review.cameraPosition===first.cameraPosition&&row.state.review.cameraRotation===first.cameraRotation&&row.state.review.materialComparison.geometry.hash===first.materialComparison.geometry.hash&&row.state.review.materialComparison.world_clock===first.materialComparison.world_clock&&row.state.review.diagnostics.draw_calls===first.diagnostics.draw_calls&&row.state.review.materialComparison.results.length>0&&row.state.review.materialComparison.results.every(r=>r.applied));
      receipt.materialPairs.push({...target,rows,matchedGeometryCameraTimeDraws:matched});save();
      await command({action:'material',scope:target.scope,mode:target.modes[0]});
      await command({action:'freeze',enabled:false});await page.waitForFunction(()=>window.__WORLD_REVIEW__?.frozen===false);
    }
    checks.materialConditionsMatched=receipt.materialPairs.length===5&&receipt.materialPairs.every(x=>x.matchedGeometryCameraTimeDraws);
  }
  if(options.mode==='startup'){
    receipt.startupSamples=[];
    const bootSample=async label=>{
      const cdp=await context.newCDPSession(page);
      const heap=await cdp.send('Runtime.getHeapUsage');
      const details=await page.evaluate(()=>({timings:window.__EXPEDITION_BOOT_TIMINGS__,resources:performance.getEntriesByType('resource').map(r=>({name:r.name,startTime:r.startTime,duration:r.duration,transferSize:r.transferSize,encodedBodySize:r.encodedBodySize,decodedBodySize:r.decodedBodySize})),navigation:performance.getEntriesByType('navigation').map(n=>({type:n.type,duration:n.duration,domContentLoaded:n.domContentLoadedEventEnd,transferSize:n.transferSize})),jsHeap:performance.memory?{usedJSHeapSize:performance.memory.usedJSHeapSize,totalJSHeapSize:performance.memory.totalJSHeapSize,jsHeapSizeLimit:performance.memory.jsHeapSizeLimit}:null}));
      await cdp.detach();return {label,details,cdpHeap:heap,at:new Date().toISOString(),limits:'New isolated context is cold at browser HTTP cache boundary; OS file and GPU driver caches uncontrolled. Warm reload reuses context but server Cache-Control:no-cache. Heap/backing storage not isolated WASM or GPU allocation.'};
    };
    receipt.startupSamples.push(await bootSample('cold-context-first-launch'));
    for(let i=1;i<=2;i++){
      await keys(['w']);await page.waitForTimeout(1500);await keys(['Space']);await page.waitForTimeout(700);await keys([]);
      await page.keyboard.press('Escape');await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='paused');await page.waitForTimeout(500);
      await page.reload({waitUntil:'domcontentloaded',timeout:60000});await page.locator('#continue').click();await waitExploring();
      receipt.startupSamples.push(await bootSample('warm-context-reload-continue-'+i));save();
    }
    checks.startupRecorded=receipt.startupSamples.length===3&&receipt.startupSamples.every(x=>x.details.timings?.godot&&Number.isFinite(x.details.timings.shell?.durations_ms?.launch_to_first_interactive_ms));
  }
  if(options.mode==='memory'){
    receipt.memorySamples=[];receipt.memoryTrace=[];receipt.memoryTraversals=[];
    const cdp=await context.newCDPSession(page);
    const sampleMemory=async label=>{
      const heap=await cdp.send('Runtime.getHeapUsage');
      await command({action:'diagnostics',id:label});await page.waitForFunction(id=>window.__WORLD_REVIEW__?.diagnostics?.id===id,label);
      const snapshot=await state();
      receipt.memorySamples.push({label,at:new Date().toISOString(),heap,engine:snapshot.review.diagnostics,position:snapshot.state.position});save();
    };
    await sampleMemory('initial');
    for(let lap=0;lap<3;lap++){
      const south=lap%2===0,limit=Date.now()+240000;
      while(Date.now()<limit){
        const x=await state(),st=x.state,p=st.position;
        if(st.phase!=='exploring')throw Error('Memory journey interrupted '+st.phase);
        if((south&&p.z< -560)||(!south&&p.z>125))break;
        const look=9,desired=south?Math.atan2(pathX(p.z-look)-p.x,look):Math.atan2(pathX(p.z+look)-p.x,-look);
        const error=wrap(desired-st.heading),next=[];
        if(Math.abs(error)<.3||Math.abs(st.speed)<3)next.push('w');else next.push('Space');
        if(error>.04)next.push('d');else if(error<-.04)next.push('a');
        await keys(next);receipt.memoryTrace.push({lap,at:Date.now(),position:p,region:x.probe.region,speed:st.speed});await page.waitForTimeout(150);
      }
      await keys(['Space']);await page.waitForTimeout(1000);await keys([]);
      const end=await state();const lapRows=receipt.memoryTrace.filter(row=>row.lap===lap);
      receipt.memoryTraversals.push({lap,south,reachedEndpoint:south?end.state.position.z< -550:end.state.position.z>115,regions:[...new Set(lapRows.map(row=>row.region))],end:end.state.position});
      await sampleMemory('traversal-'+(lap+1));
    }
    await cdp.detach();checks.memoryTraversalsRecorded=receipt.memorySamples.length===4&&receipt.memoryTraversals.every(t=>t.reachedEndpoint&&t.regions.length===4);
    receipt.memoryLimits='Three actual forward/reverse-direction world traversals; CDP JS/embedder/backing-storage counters and engine counters retained. No isolated WASM allocation or process GPU allocation, no long-run leak/no-leak conclusion.';
  }

  checks.noPageErrors=!events.some(e=>e.type==='pageerror'||e.type==='crash'||e.type==='console'&&(e.data.level==='error'||/SCRIPT ERROR|Parse Error/.test(e.data.text)));
  const strictPass=Object.values(checks).every(Boolean);
  receipt.partialReasons=partialReasons;
  receipt.outcome=strictPass?(partialReasons.length?'partial':'pass'):'fail';
  receipt.passed=receipt.outcome==='pass';
} catch(error) {
  receipt.passed=false; receipt.error=String(error.stack||error);
  log('failure',receipt.error);
  receipt.failureState=await state().catch(()=>null);
  receipt.failureShell=await page.evaluate(()=>({phase:document.body.dataset.shellPhase,boot:window.__EXPEDITION_BOOT_STATUS__,errors:window.__EXPEDITION_ERRORS__})).catch(()=>null);
  await page.screenshot({path:resolve(output,'failure.png'),timeout:5000}).catch(()=>{});
} finally {await keys([]).catch(()=>{});if(options.video&&page.video())receipt.videoPath=await page.video().path();save(); await context.close(); await browser.close();}
console.log(JSON.stringify({passed:receipt.passed,checks,output,seconds:(Date.now()-start)/1000,error:receipt.error}));
process.exitCode=receipt.passed?0:1;
