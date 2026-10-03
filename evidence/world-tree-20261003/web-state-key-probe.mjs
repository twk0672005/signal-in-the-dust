import { chromium } from 'file:///C:/Users/tsang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--enable-gpu','--use-gl=angle','--use-angle=d3d11']});
const context=await browser.newContext({viewport:{width:1280,height:720},locale:'en-US'}); const page=await context.newPage();
const errors=[]; page.on('pageerror',e=>errors.push(String(e))); page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
await page.goto('http://127.0.0.1:52880/'); await page.evaluate(()=>localStorage.clear()); await page.reload({waitUntil:'domcontentloaded'}); await page.locator('#start').click();
await page.waitForFunction(()=>document.body.dataset.shellPhase==='game',null,{timeout:180000});
if(await page.evaluate(()=>window.__EXPEDITION_BOOT_STATUS__?.stage==='confirm-new')){await page.keyboard.press('Shift+Tab');await page.keyboard.press('Enter');}
await page.waitForFunction(()=>window.__EXPEDITION_STATE__?.phase==='exploring',null,{timeout:180000});
await page.waitForTimeout(1000);
const state=await page.evaluate(()=>window.__EXPEDITION_STATE__); console.log(JSON.stringify({keys:Object.keys(state||{}).sort(),phase:state?.phase,activeCamera:state?.activeCamera,errors})); await browser.close();
