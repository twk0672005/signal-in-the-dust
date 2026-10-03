// Isolated actual-browser checks for the new presentation only; never player storage.
import{mkdirSync,writeFileSync,readFileSync}from'node:fs';
import{resolve}from'node:path';
import{createHash}from'node:crypto';
const[url,folder,artifact]=process.argv.slice(2);const destination=new URL(url);if(!['127.0.0.1','localhost'].includes(destination.hostname))throw Error('Local presentation candidate only');
mkdirSync(folder,{recursive:true});
const{chromium}=await import('file:///C:/Users/tsang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
const browser=await chromium.launch({channel:'chrome',headless:true});const context=await browser.newContext({viewport:{width:1440,height:900}});const page=await context.newPage();const errors=[],checks=[];
page.on('pageerror',e=>errors.push(String(e)));const check=(name,pass)=>{checks.push({name,pass:!!pass});if(!pass)throw Error(name)};
let failure;
try{
 const response=await page.goto(url);const hash=data=>createHash('sha256').update(data).digest('hex');check('exact frozen entry served',hash(await response.body())===hash(readFileSync(resolve(artifact,'index.html'))));
 await page.locator('.hero-art').evaluate(img=>img.decode());await page.waitForTimeout(600);
 const requests=[];page.on('request',r=>requests.push(r.url()));
 check('home has no engine boot',await page.evaluate(()=>!window.__EXPEDITION_BOOT_REQUEST__&&typeof window.Engine==='undefined'));
 await page.mouse.move(1380,130);await page.waitForTimeout(100);
 check('bounded pointer parallax active',await page.locator('#veil').evaluate(node=>{const x=parseFloat(node.style.getPropertyValue('--drift-x'));return Math.abs(x)>1&&Math.abs(x)<=5}));
 await page.emulateMedia({reducedMotion:'reduce'});await page.waitForTimeout(100);
 check('reduced motion resets parallax',await page.locator('#veil').evaluate(node=>parseFloat(node.style.getPropertyValue('--drift-x'))===0));
 check('static full hero in reduced motion',await page.locator('.hero-art').evaluate(img=>getComputedStyle(img).transform==='none'&&getComputedStyle(img).animationName==='none'));
 await page.emulateMedia({reducedMotion:'no-preference'});
 const names=['aurora_shelf','ember_rift','veil_marsh','pale_decay'];
 for(const region of names){await page.locator('[data-region='+region+']').focus();await page.keyboard.press('Enter');await page.locator('#region-preview').evaluate(img=>img.decode());check(region+' keyboard preview semantic',await page.locator('[data-region='+region+']').getAttribute('aria-pressed')==='true'&&(await page.locator('#region-preview').getAttribute('src')).includes(region+'-actual.webp'));}
 check('preview never fetches game executable',!requests.some(x=>/index\.(js|wasm|pck)/.test(x)));
 await page.locator('[data-region=aurora_shelf]').click();await page.locator('.hero-art').evaluate(img=>img.decode());
 await page.screenshot({path:resolve(folder,'desktop-1440.png')});
 check('no horizontal overflow',await page.evaluate(()=>document.getElementById('veil').scrollWidth<=innerWidth));
 const reveal=await page.locator('#start').boundingBox();check('start visible and comfortably sized',reveal.y>=0&&reveal.y+reveal.height<=900&&reveal.height>=48);
 await page.keyboard.press('Tab');
 check('no console page errors',errors.length===0);
}catch(error){failure=String(error);process.exitCode=1;}finally{writeFileSync(resolve(folder,'receipt.json'),JSON.stringify({url,browser:browser.version(),checks,errors,failure,pass:!failure&&errors.length===0},null,2));await browser.close();}
