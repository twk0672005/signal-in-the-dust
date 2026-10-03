// Deterministic shell checks only: no browser, renderer, game save or export.
import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';

const root = resolve(import.meta.dirname,'../..');
const html = readFileSync(resolve(root,'godot/web/shell.html'),'utf8');
const source = readFileSync(resolve(root,'godot/web/showcase.js'),'utf8');
const css = readFileSync(resolve(root,'godot/web/showcase.css'),'utf8');
const dictionary = vm.runInNewContext(source.slice(source.indexOf('  const COPY ='),source.indexOf('  const $ ='))+';COPY');

test('complete bilingual entry retains the action, DOM, motion and player-data boundaries', () => {
  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);
  assert.equal(new Set(ids).size,ids.length,'duplicate DOM ids');
  for (const match of source.matchAll(/\$\('([^']+)'\)/g)) assert.ok(ids.includes(match[1]),'missing '+match[1]);
  for (const match of html.matchAll(/data-copy="([^"]+)"/g)) {
    for (const language of ['en','zh_TW']) assert.equal(typeof dictionary[language][match[1]],'string',language+': '+match[1]);
  }
  assert.equal(dictionary.en.start,'Begin my journey');
  assert.equal(dictionary.zh_TW.start,'開啟我的旅程');
  assert.equal(dictionary.en.ready,'Drive a rover.\nExplore an alien planet.');
  assert.equal(dictionary.zh_TW.ready,'駕駛探索車，\n探索外星星球');
  assert.equal(dictionary.en.eyebrow,'ALIEN PLANET EXPLORATION GAME');
  assert.equal(dictionary.zh_TW.eyebrow,'外星星球探索遊戲');
  assert.match(dictionary.en.intro,/four alien regions/);
  assert.match(dictionary.en.intro,/observe creatures and investigate signals/);
  assert.match(dictionary.zh_TW.intro,/四個外星區域/);
  assert.match(dictionary.zh_TW.intro,/觀察生物與調查生命訊號/);
  assert.match(html,/SIGNAL IN THE DUST/);
  assert.match(html,/Drive a rover\.\r?\nExplore an alien planet\./);
  assert.equal(dictionary.en.downloadTitle,'Downloading\nthe game');
  assert.equal(dictionary.zh_TW.downloadTitle,'正在下載\n遊戲內容');
  assert.equal(dictionary.en.viewTitle,'Opening\nthe game view');
  assert.equal(dictionary.zh_TW.viewTitle,'正在開啟\n遊戲畫面');
  assert.match(dictionary.en.art,/In-game capture/);
  assert.match(dictionary.zh_TW.art,/遊戲實景/);
  assert.match(dictionary.en.studyArt,/In-game capture/);
  assert.match(dictionary.zh_TW.studyArt,/遊戲實景/);
  assert.equal(dictionary.en.habitat,'AURORA SHELF');
  assert.equal(dictionary.en.specimenHabitat,'VEIL MARSH');
  assert.equal(dictionary.zh_TW.habitat,'極光高原');
  assert.equal(dictionary.zh_TW.specimenHabitat,'濃霧沼澤');
  assert.ok(!/Concept|概念/.test(html));
  assert.ok(!ids.includes('continue'));
  assert.ok(!/localStorage|indexedDB|removeItem|clear\(/.test(source),'shell must not own player storage');
  assert.match(html,/setPointerCapture\(e.pointerId\)/);
  for (const event of ['pointerup','pointercancel','lostpointercapture']) assert.ok(html.includes(event));
  assert.match(css,/prefers-reduced-motion: reduce/);
  assert.match(css,/button:focus-visible/);
  assert.match(css,/@media \(orientation: portrait\)/);
  assert.match(css,/@media \(max-height: 450px\) and \(orientation: landscape\)/);
});

test('both runtime images and preloads match preserved capture provenance', () => {
  const provenance = JSON.parse(readFileSync(resolve(root,'evidence/alien-renewal-20260930T200644Z/delivery-images/image-provenance.json'),'utf8'));
  const hash = bytes=>createHash('sha256').update(bytes).digest('hex');
  assert.equal(provenance.captureRuntime.kind,'isolated_chromium_actual_web');
  assert.equal(provenance.images.length,2);
  for (const image of provenance.images) {
    const data=readFileSync(resolve(root,image.assetPath));
    assert.equal(hash(data),image.sha256);
    assert.equal(hash(readFileSync(resolve(root,image.sourcePath))),image.sourceSha256);
    assert.equal(data.subarray(0,4).toString(),'RIFF');
    assert.equal(data.subarray(8,12).toString(),'WEBP');
    const url=image.assetPath.replace('godot/web/','');
    assert.ok(html.includes('href="'+url+'"'),'missing preload: '+url);
    assert.ok(html.includes('src="'+url+'"'),'missing image: '+url);
    assert.equal(image.outputDimensions[0],image.crop[2]-image.crop[0]);
    assert.equal(image.outputDimensions[1],image.crop[3]-image.crop[1]);
  }
  assert.match(html,/<li class="featured"><span aria-hidden="true">01<\/span>/);
});

test('measured bytes and preparation stay distinct from rendered-frame readiness', () => {
  function node() {
    const attributes = new Map();
    return {textContent:'',hidden:false,dataset:{},children:[],setAttribute:(key,value)=>attributes.set(key,String(value)),
      removeAttribute:key=>attributes.delete(key),hasAttribute:key=>attributes.has(key),getAttribute:key=>attributes.get(key)??null};
  }
  const nodes = Object.fromEntries(['loading-title','status','loading-stages','phase-detail','waiting-elapsed','wait-note','specimen-note'].map(id=>[id,node()]));
  nodes['loading-stages'].children = [node(),node(),node()];
  const progress = node();
  const document = {body:{dataset:{shellPhase:'loading'}}};
  const window = {};
  const context = vm.createContext({COPY:dictionary,document,window,progress,performance:{now:()=>61000},$:id=>nodes[id],
    locale:'en',phaseKey:'downloading',transferCurrent:5*1048576,transferTotal:10*1048576,lastLoadingSignature:'',
    bootTiming:{timestampsMs:{launch_requested_ms:1000}}});
  const loading = source.slice(source.indexOf('  function updateLoadingExperience('),source.indexOf('  function blockGame('));
  vm.runInContext(loading,context);
  progress.setAttribute('value','50'); context.updateLoadingExperience();
  assert.equal(nodes['phase-detail'].textContent,'Game files · 5.0 MiB / 10.0 MiB');
  assert.equal(document.body.dataset.preparationStage,'download');
  assert.equal(nodes['waiting-elapsed'].textContent,'01:00');
  assert.equal(nodes['wait-note'].hidden,false);
  context.transferTotal=0; progress.removeAttribute('value'); context.updateLoadingExperience();
  assert.equal(nodes['phase-detail'].textContent,'Game files · 5.0 MiB received');
  assert.equal(progress.hasAttribute('value'),false);
  context.locale='zh_TW'; context.updateLoadingExperience();
  assert.equal(nodes['phase-detail'].textContent,'遊戲內容 · 5.0 MiB 已接收');
  context.phaseKey='preparing'; window.__EXPEDITION_PREPARATION__={version:1,phase:'materials',completed:3,total:9};
  context.updateLoadingExperience();
  assert.equal(nodes['phase-detail'].textContent,'表面準備 · 3 / 9');
  assert.equal(document.body.dataset.preparationStage,'materials');
  assert.equal(nodes['loading-stages'].children[1].getAttribute('aria-current'),'step');
  window.__EXPEDITION_PREPARATION__.completed=10; context.updateLoadingExperience();
  assert.equal(nodes['phase-detail'].textContent,dictionary.zh_TW.materialHint,'invalid counts must never become progress');
  window.__EXPEDITION_PREPARATION__={version:1,phase:'first-view'}; context.updateLoadingExperience();
  assert.equal(nodes['loading-stages'].children[2].getAttribute('aria-current'),'step');
  assert.equal(progress.hasAttribute('value'),false);

  let finished=0;
  Object.assign(context,{pending:{requestId:'current'},fatal:false,lastStatus:'',busy:true,started:true,lastBootProgress:0,
    translate:()=>{},setProgress:()=>{},refreshBootGuard:()=>{},finishOnFrame:()=>finished++,showHome:()=>{},fail:()=>{}});
  vm.runInContext(source.slice(source.indexOf('  function inspectStatus('),source.indexOf("  $('start').addEventListener")),context);
  window.__EXPEDITION_BOOT_STATUS__={version:1,requestId:'stale',stage:'playing',firstFrameReady:true}; context.inspectStatus();
  assert.equal(finished,0);
  window.__EXPEDITION_BOOT_STATUS__={version:1,requestId:'current',stage:'playing',firstFrameReady:false}; context.inspectStatus();
  assert.equal(finished,0);
  window.__EXPEDITION_BOOT_STATUS__.firstFrameReady=true; context.inspectStatus();
  assert.equal(finished,1);
  const failures=[];
  context.fail=(...args)=>failures.push(args);
  window.__EXPEDITION_BOOT_STATUS__={version:1,requestId:'current',stage:'error',firstFrameReady:false,fatal:true};
  context.inspectStatus();
  assert.deepEqual(failures,[['error',null,true]],'failed graphics initialization requires visible reload without releasing the first-frame gate');
  assert.equal(finished,1);
});
