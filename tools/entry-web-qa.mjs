// Isolated real Web entry journey: no injected save, game state or fake engine.
import {mkdirSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
const [url, directory] = process.argv.slice(2);
const destination=new URL(url);
assert(['127.0.0.1', 'localhost'].includes(destination.hostname)||
  destination.hostname==='twk0672005.github.io'&&destination.pathname==='/signal-in-the-dust/');
const output = resolve(directory); mkdirSync(output, {recursive:true});
const {chromium} = await import('file:///C:/Users/tsang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
const browser = await chromium.launch({channel:'chrome', headless:true, args:['--enable-gpu','--use-gl=angle','--use-angle=d3d11']});
const context = await browser.newContext({viewport:{width:1440,height:900}, locale:'zh-TW'});
const page = await context.newPage(); const errors=[]; const checks=[]; let completed=false;
page.on('pageerror', e=>errors.push(String(e)));
await page.addInitScript(() => {
  window.__ENTRY_QA_SAMPLES__ = [];
  const timer = setInterval(() => {
    const shell = document.body?.dataset.shellPhase;
    if (!shell || shell === 'home') return;
    const status = window.__EXPEDITION_BOOT_STATUS__;
    const preparation = window.__EXPEDITION_PREPARATION__;
    const progress = document.getElementById('progress');
    const previous = window.__ENTRY_QA_SAMPLES__.at(-1);
    const sample = {shell, stage:preparation?.phase, value:progress?.getAttribute('value'), detail:document.getElementById('phase-detail')?.textContent,
      ready:status?.firstFrameReady, request:status?.requestId, expected:window.__EXPEDITION_BOOT_REQUEST__?.requestId};
    if (!previous || JSON.stringify(previous) !== JSON.stringify(sample)) window.__ENTRY_QA_SAMPLES__.push(sample);
  }, 100);
  addEventListener('pagehide', () => clearInterval(timer), {once:true});
});
const shot = async name=>{
  await page.waitForFunction(()=>document.body.dataset.shellPhase!=='home'||['h1','#start'].every(selector=>{
    let opacity=1;
    for(let node=document.querySelector(selector);node;node=node.parentElement){
      const style=getComputedStyle(node);
      if(style.display==='none'||style.visibility==='hidden')return false;
      opacity*=Number(style.opacity);
    }
    return opacity>.99;
  }),null,{timeout:10000});
  return page.screenshot({path:resolve(output,name+'.png')});
};
const check = (name,value)=>{checks.push({name,pass:!!value});assert(value,name);};
const launchTimeout=destination.hostname==='twk0672005.github.io'?360000:180000;
const game = async()=>{await page.waitForFunction(()=>document.body.dataset.shellPhase==='game'&&document.getElementById('veil').classList.contains('hidden'),null,{timeout:launchTimeout});};
const exploring = ()=>page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='exploring',null,{timeout:30000});
try {
  await page.goto(url); await page.locator('.hero-art').evaluate(img=>img.decode());
  const hero=await page.locator('.hero-art').evaluate(img=>({source:img.currentSrc,width:img.naturalWidth,height:img.naturalHeight}));
  check('actual Aurora runtime hero decoded',hero.source.includes('aurora-web-6da6c8ca.webp')&&hero.width>0&&hero.height>0);
  check('Chinese runtime artwork credit',await page.locator('.art-credit').innerText()==='極光高原 · 遊戲實景');
  check('Chinese rover and alien planet invitation', (await page.locator('h1').innerText()).replace(/\s+/g,' ').trim()==='駕駛探索車， 探索外星星球');
  check('Chinese explicit game label',await page.locator('.home .eyebrow').innerText()==='外星星球探索遊戲');
  check('Chinese exploration loop',await page.locator('.intro').innerText()==='駕駛探索車穿越四個外星區域，減速停車，觀察生物與調查生命訊號。');
  check('Chinese journey action',await page.locator('#start [data-copy=start]').innerText()==='開啟我的旅程');
  check('Continue removed',await page.locator('#continue').count()===0);
  check('home does not launch engine',await page.evaluate(()=>!window.__EXPEDITION_BOOT_REQUEST__));
  await shot('home-zh-desktop');
  await page.locator('#language-toggle').click(); await shot('home-en-desktop');
  check('English rover and alien planet invitation',(await page.locator('h1').innerText()).replace(/\s+/g,' ').trim()==='Drive a rover. Explore an alien planet.');
  check('English explicit game label',await page.locator('.home .eyebrow').innerText()==='ALIEN PLANET EXPLORATION GAME');
  check('English exploration loop',await page.locator('.intro').innerText()==='Drive across four alien regions. Stop to observe creatures and investigate signals.');
  check('English journey action',await page.locator('#start [data-copy=start]').innerText()==='Begin my journey');
  await page.locator('#language-toggle').click();
  for(const [language,title] of [['zh','駕駛探索車， 探索外星星球'],['en','Drive a rover. Explore an alien planet.']]) {
    if(await page.locator('html').getAttribute('lang')!==(language==='zh'?'zh-Hant':'en')) await page.locator('#language-toggle').click();
    for(const [width,height,name] of [[390,844,'portrait'],[844,390,'landscape']]) {
      await page.setViewportSize({width,height}); await shot('home-'+language+'-'+name);
      const label=language+' '+name;
      check(label+' explicit rover and planet heading',(await page.locator('h1').innerText()).replace(/\s+/g,' ').trim()===title);
      const heading=await page.locator('h1').boundingBox();
      check(label+' heading visible without scrolling',heading.y>=0&&heading.y+heading.height<=height);
      const box=await page.locator('#start').boundingBox();
      check(label+' start visible without scrolling',box.y>=0&&box.y+box.height<=height);
      check(label+' no horizontal overflow',await page.evaluate(()=>document.getElementById('veil').scrollWidth<=innerWidth));
      check(label+' journey action meets touch target',box.height>=44&&box.width>=44);
    }
  }
  await page.locator('#language-toggle').click();
  await page.setViewportSize({width:1440,height:900});
  await page.locator('#open-settings').click();
  await page.locator('#close-settings').focus(); await page.keyboard.press('Shift+Tab');
  check('preferences keyboard focus remains in modal',await page.evaluate(()=>document.activeElement.id==='settings-done'));
  await page.keyboard.press('Tab');
  check('preferences keyboard focus wraps to first control',await page.evaluate(()=>document.activeElement.id==='close-settings'));
  await page.keyboard.press('Escape');
  check('preferences Escape returns focus',await page.evaluate(()=>document.activeElement.id==='open-settings'));
  await page.emulateMedia({reducedMotion:'reduce'});
  await page.waitForFunction(()=>document.body.dataset.reducedMotion==='true');
  check('reduced motion stops artwork animation',await page.locator('.hero-art').evaluate(img=>getComputedStyle(img).animationName==='none'));
  await shot('home-zh-reduced-motion');
  await page.emulateMedia({reducedMotion:'no-preference'});
  await page.locator('#start').click(); await game(); await exploring();
  const samples=await page.evaluate(()=>window.__ENTRY_QA_SAMPLES__);
  writeFileSync(resolve(output,'loading-observed.json'),JSON.stringify(samples,null,2));
  await page.locator('.specimen-art').evaluate(img=>img.decode());
  const specimen=await page.locator('.specimen-art').evaluate(img=>({source:img.currentSrc,width:img.naturalWidth,height:img.naturalHeight}));
  check('actual Aeral runtime specimen decoded',specimen.source.includes('aeral-web-6da6c8ca.webp')&&specimen.width>0&&specimen.height>0);
  writeFileSync(resolve(output,'loaded-artwork.json'),JSON.stringify({hero,specimen},null,2));
  check('real loading samples observed',samples.some(sample=>sample.shell==='loading'));
  const preparationSamples=samples.filter(sample=>sample.shell==='loading'&&['world','materials','first-view'].includes(sample.stage));
  check('preparation keeps transfer progress indeterminate',preparationSamples.length>0&&preparationSamples.every(sample=>sample.value===null));
  const gameSamples=samples.filter(sample=>sample.shell==='game');
  check('game opens only on matching first frame',gameSamples.length>0&&gameSamples.every(sample=>sample.ready===true&&sample.request===sample.expected));
  check('no reported engine errors',await page.evaluate(()=>window.__EXPEDITION_ERRORS__.length===0));
  await shot('new-journey');
  const before=await page.evaluate(()=>window.__EXPEDITION_STATE__.position);
  await page.keyboard.down('w'); await page.waitForTimeout(2500); await page.keyboard.up('w');
  const after=await page.evaluate(()=>window.__EXPEDITION_STATE__.position);
  check('real driving',Math.hypot(after.x-before.x,after.z-before.z)>1);
  await page.keyboard.press('Escape');
  await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='paused');
  check('saved during pause',await page.evaluate(()=>window.__EXPEDITION_STATE__.saveAvailable));
  await page.reload(); await page.locator('#start').click(); await game();
  check('existing save opens invitation',await page.evaluate(()=>window.__EXPEDITION_BOOT_STATUS__.stage==='confirm-new'));
  await shot('invitation-zh-desktop');
  await page.setViewportSize({width:844,height:390}); await page.waitForTimeout(500); await shot('invitation-zh-landscape');
  await page.setViewportSize({width:1440,height:900}); await page.waitForTimeout(500);
  await page.keyboard.press('Escape');
  await page.waitForFunction(()=>document.body.dataset.shellPhase==='home');
  check('cancel returns home',await page.locator('#start').isVisible());
  await page.locator('#start').click(); await game();
  check('cancel preserved old progress',await page.evaluate(()=>window.__EXPEDITION_BOOT_STATUS__.stage==='confirm-new'));
  // The safe Back to title action has initial focus; the preceding action begins.
  await page.keyboard.press('Shift+Tab'); await page.keyboard.press('Enter'); await exploring();
  check('confirmed new journey',await page.evaluate(()=>window.__EXPEDITION_STATE__.resetCount===1));
  await page.keyboard.press('r'); await page.waitForFunction(()=>window.__EXPEDITION_STATE__.phase==='confirm_reset');
  await shot('restart-zh-desktop');
  await page.keyboard.press('Escape'); await exploring();
  check('restart cancel resumes play',true);
  await page.keyboard.press('Escape');
  await page.waitForFunction(()=>window.__EXPEDITION_STATE__.phase==='paused');
  await page.waitForTimeout(700);
  const touch=await browser.newContext({viewport:{width:844,height:390},locale:'zh-TW',hasTouch:true,isMobile:true,storageState:await context.storageState({indexedDB:true})});
  const phone=await touch.newPage(); phone.on('pageerror',e=>errors.push(String(e)));
  await phone.goto(url); await phone.locator('#start').tap();
  await phone.waitForFunction(()=>document.body.dataset.shellPhase==='game'&&document.getElementById('veil').classList.contains('hidden'),null,{timeout:launchTimeout});
  check('touch mode uses the saved-progress invitation',await phone.evaluate(()=>window.__EXPEDITION_STATE__.touchEnabled&&window.__EXPEDITION_BOOT_STATUS__.stage==='confirm-new'));
  await phone.screenshot({path:resolve(output,'invitation-zh-touch.png')});
  await touch.close();
  check('no JS errors',errors.length===0); completed=true;
} finally {
  writeFileSync(resolve(output,'receipt.json'),JSON.stringify({url,browser:browser.version(),checks,errors,pass:completed&&checks.length>=13&&checks.every(x=>x.pass)&&errors.length===0},null,2));
  await browser.close();
}
