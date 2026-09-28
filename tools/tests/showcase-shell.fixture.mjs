// Isolated frontend fixture. No Godot/import/export or game save access.
import { createServer } from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { resolve, extname, sep } from 'node:path';
const root = resolve(import.meta.dirname, '../..');
const port = Number(process.env.SHELL_FIXTURE_PORT || 4197);
const web = resolve(root, 'godot/web');
const fixtureScript = `
window.__fixture = { starts: 0, requests: [], touches: [], errors: [], gamePhaseWrites: 0 };
addEventListener('error', event => window.__fixture.errors.push(event.message));
addEventListener('unhandledrejection', event => window.__fixture.errors.push(String(event.reason)));
window.expeditionTouch = (...args) => window.__fixture.touches.push(args);
window.__EXPEDITION_STATE__ = { phase: 'menu', settings: { locale: 'en' } };
let options;
function fixtureSnapshot() {
 const readback = document.getElementById('fixture-readback');
 if (readback) readback.textContent = JSON.stringify({ ...window.__fixture, status: window.__EXPEDITION_BOOT_STATUS__, shellPhase: document.body.dataset.shellPhase, gamePhase: document.body.dataset.phase });
}
function fixtureStatus(stage, ready = false, requestId = window.__fixture.requests.at(-1)?.requestId) {
 window.__EXPEDITION_BOOT_STATUS__ = { version: 1, requestId, stage, firstFrameReady: ready, savedAvailable: true };
 fixtureSnapshot();
}
window.expeditionLaunch = raw => { window.__fixture.requests.push(JSON.parse(raw)); fixtureStatus('validating'); };
window.Engine = class {
 static getMissingFeatures() { return new URLSearchParams(location.search).has('unsupported') ? ['webgl'] : []; }
 constructor() { window.__fixture.starts++; }
 startGame(value) { options = value; window.__fixture.requests.push(window.__EXPEDITION_BOOT_REQUEST__); fixtureStatus('initializing'); return new Promise((resolve, reject) => { window.fixtureResolve = resolve; window.fixtureReject = reject; }); }
};
addEventListener('DOMContentLoaded', () => {
 const badge = document.createElement('aside'); badge.id = 'fixture-tools';
 badge.style = 'position:fixed;top:0;left:50%;transform:translateX(-50%);z-index:99;color:white;background:#152238;font:11px system-ui;max-width:95vw;';
 badge.innerHTML = '<details><summary style="padding:4px 10px">Shell fixture · no Godot runtime</summary><div style="padding:8px;display:flex;gap:4px;flex-wrap:wrap"><button data-fixture="download">Transfer 42%</button><button data-fixture="unknown">Unknown total</button><button data-fixture="compile">Transfer complete</button><button data-fixture="resolve">Resolve engine only</button><button data-fixture="stale">Stale first frame</button><button data-fixture="playing">Playing + first frame</button><button data-fixture="confirm">Confirm new + first frame</button><button data-fixture="home">Return home</button><button data-fixture="unavailable">Continue unavailable</button><button data-fixture="error">Game error</button><button data-fixture="fatal">Engine failure</button><button data-fixture="context">Lose graphics</button></div><output id="fixture-readback" style="display:block;max-width:700px;overflow-wrap:anywhere"></output></details>';
 document.body.append(badge);
 // Mirror main.gd's independent recurring snapshot writes. The previous fixture
 // omitted this engine-owned side effect and consequently missed the collision.
 const gameSnapshotTimer = setInterval(() => {
  if (window.__fixture.starts === 0) return;
  document.body.dataset.phase = window.__EXPEDITION_STATE__.phase;
  window.__fixture.gamePhaseWrites++;
 }, 33);
 addEventListener('pagehide', () => clearInterval(gameSnapshotTimer), {once:true});
 const runRegression = document.createElement('button');
 runRegression.type = 'button'; runRegression.textContent = 'Run phase ownership regression';
 runRegression.id = 'fixture-run-regression';
 const regressionStatus = document.createElement('output'); regressionStatus.id = 'fixture-regression-status';
 const regressionResults = document.createElement('pre'); regressionResults.id = 'fixture-regression-results';
 badge.querySelector('details').append(runRegression, regressionStatus, regressionResults);
 runRegression.addEventListener('click', async () => {
  runRegression.disabled = true; regressionStatus.textContent = 'RUNNING';
  const checks = [];
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  const check = (name, pass, observed) => checks.push({name,pass,observed});
  const state = () => ({shell:document.body.dataset.shellPhase, game:document.body.dataset.phase, writes:window.__fixture.gamePhaseWrites});
  try {
   document.getElementById('start').click();
   await delay(180);
   options.onProgress(42,100);
   await delay(160);
   check('download survives recurring menu snapshots', document.body.dataset.shellPhase === 'loading' && document.body.dataset.phase === 'menu' && document.getElementById('progress').getAttribute('value') === '42', {...state(),progress:document.getElementById('progress').getAttribute('value')});
   check('loading art and navigation keep loading styles', getComputedStyle(document.querySelector('.hero-art')).opacity === '0.25' && getComputedStyle(document.querySelector('.entry-tools')).visibility === 'hidden', {opacity:getComputedStyle(document.querySelector('.hero-art')).opacity,tools:getComputedStyle(document.querySelector('.entry-tools')).visibility});
   options.onProgress(100,100); window.fixtureResolve(); fixtureStatus('initializing');
   await delay(180);
   check('initialization stays indeterminate beneath game snapshots', !document.getElementById('progress').hasAttribute('value') && document.body.dataset.shellPhase === 'loading', {...state(),progress:document.getElementById('progress').getAttribute('value')});
   window.__EXPEDITION_STATE__.phase = 'exploring'; fixtureStatus('playing',true);
   await delay(680);
   check('matching frame completes fade despite recurring exploring snapshots', document.getElementById('veil').classList.contains('hidden') && document.body.dataset.shellPhase === 'game' && document.body.dataset.phase === 'exploring', {...state(),veilClass:document.getElementById('veil').className});
   const panel = document.getElementById('touch-controls');
   check('landscape touch remains visible during exploring snapshots', !!panel && getComputedStyle(panel).display === 'block', {touch:window.__EXPEDITION_TOUCH__,display:panel ? getComputedStyle(panel).display : 'no coarse pointer',...state()});
   window.__EXPEDITION_STATE__.phase = 'paused';
   await delay(170);
   check('game pause hides touch without replacing shell state', !!panel && getComputedStyle(panel).display === 'none' && document.body.dataset.shellPhase === 'game' && document.body.dataset.phase === 'paused', state());
   fixtureStatus('error',true);
   await delay(170);
   check('error presentation survives game snapshot writes', document.body.dataset.shellPhase === 'error' && document.body.dataset.phase === 'paused' && !document.getElementById('error-actions').hidden && getComputedStyle(document.querySelector('.hero-art')).opacity === '0.25', state());
   window.__EXPEDITION_STATE__.phase = 'menu'; fixtureStatus('home',true);
   await delay(170);
   check('home recovery preserves independent game menu phase', document.body.dataset.shellPhase === 'home' && document.body.dataset.phase === 'menu' && !document.getElementById('home').hidden && window.__fixture.starts === 1, {...state(),starts:window.__fixture.starts});
   check('existing Chinese title is unchanged', document.querySelector('.title-sub').textContent === '塵境回聲', document.querySelector('.title-sub').textContent);
  } catch (error) { checks.push({name:'regression execution',pass:false,observed:String(error)}); }
  fixtureSnapshot();
  regressionResults.textContent = JSON.stringify({kind:'shell-only-periodic-game-snapshot',checks,errors:window.__fixture.errors},null,2);
  regressionStatus.textContent = checks.every(check=>check.pass) ? 'PASSED' : 'FAILED';
 });
 badge.addEventListener('click', event => {
  const action = event.target.dataset.fixture;
  if (action === 'download') options.onProgress(42, 100);
  if (action === 'unknown') options.onProgress(42, 0);
  if (action === 'compile') options.onProgress(100, 100);
  if (action === 'resolve') { window.fixtureResolve?.(); fixtureStatus('initializing'); }
  if (action === 'stale') fixtureStatus('playing', true, 'stale-request');
  if (action === 'playing') { window.fixtureResolve?.(); window.__EXPEDITION_STATE__.phase = 'exploring'; fixtureStatus('playing', true); }
  if (action === 'confirm') { window.fixtureResolve?.(); window.__EXPEDITION_STATE__.phase = 'menu'; fixtureStatus('confirm-new', true); }
  if (action === 'home') { window.__EXPEDITION_STATE__.phase = 'menu'; fixtureStatus('home', true); }
  if (action === 'unavailable') { window.fixtureResolve?.(); fixtureStatus('continue-unavailable', true); }
  if (action === 'error') { window.fixtureResolve?.(); fixtureStatus('error', true); }
  if (action === 'fatal') window.fixtureReject?.(new Error('fixture engine failure'));
  if (action === 'context') document.getElementById('canvas').dispatchEvent(new Event('webglcontextlost'));
 });
});`;
const server = createServer((req, res) => {
 const url = new URL(req.url, 'http://127.0.0.1');
 if (url.pathname === '/fixture-noop.js') { res.setHeader('Content-Type','text/javascript'); res.end(''); return; }
 if (url.pathname === '/fixture-engine.js') { res.setHeader('Content-Type','text/javascript'); res.end(fixtureScript); return; }
 if (url.pathname === '/') {
  const before = url.searchParams.has('before-phase-fix');
  const source = before ? resolve(root,'evidence/visual-upgrade-20260923/shell/phase-isolation/before/shell.html') : url.searchParams.has('baseline') ? resolve(root,'evidence/visual-upgrade-20260923/shell/baseline-shell.html') : resolve(web,'shell.html');
  let html = readFileSync(source,'utf8').replaceAll('$GODOT_PROJECT_NAME','Signal in the Dust').replace('$GODOT_HEAD_INCLUDE','<script src="/fixture-engine.js"></script>').replaceAll('$GODOT_URL','/fixture-noop.js').replace('$GODOT_CONFIG','{"executable":"index"}');
  if (before) html = html.replace('href="showcase.css"','href="/before/showcase.css"').replace('src="showcase.js"','src="/before/showcase.js"');
  res.setHeader('Content-Type','text/html; charset=utf-8'); res.end(html); return;
 }
 if (['/before/showcase.css','/before/showcase.js'].includes(url.pathname)) {
  res.setHeader('Content-Type',url.pathname.endsWith('.css')?'text/css':'text/javascript');
  res.end(readFileSync(resolve(root,'evidence/visual-upgrade-20260923/shell/phase-isolation',url.pathname.slice(1)))); return;
 }
 const file = resolve(web, '.' + decodeURIComponent(url.pathname));
 if (!file.startsWith(web + sep) || !existsSync(file)) { res.writeHead(404); res.end('Not found'); return; }
 res.setHeader('Content-Type', ({'.css':'text/css','.js':'text/javascript','.png':'image/png'})[extname(file)] || 'application/octet-stream');
 res.end(readFileSync(file));
});
server.listen(port,'127.0.0.1',() => console.log(JSON.stringify({kind:'shell-only-fixture',pid:process.pid,port,root,web})));

