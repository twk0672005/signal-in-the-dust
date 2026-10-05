import {readFileSync,writeFileSync,mkdirSync,copyFileSync,readdirSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
const root=resolve(import.meta.dirname,'..'),run=resolve(root,'evidence/alien-wander-20261004'),artifact=resolve(run,'candidate-h/web'),final=resolve(run,'delivery');
mkdirSync(final,{recursive:true});
const json=p=>JSON.parse(readFileSync(p,'utf8'));
const hash=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const release=json(resolve(artifact,'release-manifest.json'));
const baseline=json(resolve(run,'baseline-release-manifest.json'));
const validFiles=(manifest,directory,skipIndex=false)=>manifest.publishFiles.filter(f=>!skipIndex||f.path!=='index.html').every(f=>existsSync(resolve(directory,f.path))&&hash(resolve(directory,f.path))===f.sha256);
if(!validFiles(release,artifact)||!validFiles(release,resolve(root,'out')))throw Error('Delivered build differs from immutable manifest');
if(!validFiles(baseline,resolve(root,'out'),true))throw Error('Prior immutable release changed');
const nativeFiles=['native-physics_camera_regression/physics-camera.json','native-free_roam_regression/free-roam.json','native-ecology_regression/ecology.json','native-save_resume_regression/save-resume.json','native-save_flow_regression/save-flow.json'];
const native=nativeFiles.map(path=>{const data=json(resolve(root,'evidence',path));return {path,passed:data.passed,checks:Object.keys(data.checks).length,failures:Object.entries(data.checks).filter(([,v])=>!v).map(([k])=>k),sha256:hash(resolve(root,'evidence',path))};});
const desktop=json(resolve(run,'desktop-h/receipt.json')),touch=json(resolve(run,'touch-h/receipt.json'));
const loadingFull=json(resolve(run,'loading-h-full-isolated/receipt.json')),loadingLow=json(resolve(run,'loading-h-lighter-isolated/receipt.json'));
const ui=json(resolve(run,'native-ui-g/receipt.json'));
if(!native.every(r=>r.passed&&!r.failures.length)||![desktop,touch,loadingFull,loadingLow].every(r=>r.passed))throw Error('Required verification has failures');
const sourceNames=['godot/project.godot','godot/main.tscn','godot/export_presets.cfg','godot/config/brand.json','godot/assets/fonts/SignalSansTC.otf','godot/assets/fonts/PROVENANCE.json','package.json',
...readdirSync(resolve(root,'godot/scripts')).filter(f=>f.endsWith('.gd')).map(f=>'godot/scripts/'+f),
...readdirSync(resolve(root,'godot/shaders')).filter(f=>/\.gdshader(inc)?$/.test(f)).map(f=>'godot/shaders/'+f),
...['shell.html','showcase.js','showcase.css','showcase-art.js','showcase-grand.css'].map(f=>'godot/web/'+f)];
const source=Object.fromEntries(sourceNames.map(p=>[p,hash(resolve(root,p))]));
const timing=r=>{
 const shell=r.timings.shell,g=r.timings.godot.durations_usec;
 return {downloadSeconds:shell.durations_ms.engine_reported_download_ms/1000,worldSeconds:g.world_incremental_build/1e6,graphicsPreparationSeconds:g.renderer_first_use_warmup/1e6,entryFirstPaintSeconds:r.paint.entry.find(p=>p.name==='first-contentful-paint').ms/1000,firstUnobscuredGameSeconds:(r.paint.firstUnobscuredGameFrameMs-shell.timestamps_ms.launch_requested_ms)/1000,firstControlSeconds:shell.durations_ms.launch_to_first_interactive_ms/1000,preparationLowQuality:r.preparation.preparation_low_quality,renderer:r.renderer};
};
for(const [from,to]of [['desktop-h/04-off-road-look.png','rover-roaming.png'],['desktop-h/09b-observe-aeral.png','aeral-observation.png'],['desktop-h/08-world-tree-no-E.png','world-tree.png'],['desktop-h/02-entry-zh.png','entry-zh.png'],['touch-h/05-touch-observation.png','touch-observation.png']])copyFileSync(resolve(run,from),resolve(final,to));
copyFileSync(desktop.videoPath,resolve(final,'alien-wander-drive.webm'));
copyFileSync(touch.videoPath,resolve(final,'alien-wander-touch.webm'));
const visualReview=json(resolve(run,'final-visual-review.json'));
if(!visualReview.passed||visualReview.releaseId!==release.releaseId)throw Error('Final artifact needs matching visual review');
const decodedFrames=['desktop-h/video-proof-mid.png','touch-h/video-proof-at-20.png'];
if(!decodedFrames.every(p=>existsSync(resolve(run,p))&&readFileSync(resolve(run,p)).length>1000))throw Error('Video frame decode evidence missing');
const savedNamespace=readFileSync(resolve(root,'godot/project.godot'),'utf8').includes('config/name="Signal in the Dust');
const receipt={
 verdict:'PASS_LOCAL_PRODUCT',workingName:'Alien Wander / 異星漫遊 (proposal, not final brand approval)',
 releaseId:release.releaseId,url:'http://127.0.0.1:64818/',artifact,
 sourceBase:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),
 branch:execFileSync('git',['branch','--show-current'],{cwd:root,encoding:'utf8'}).trim(),
 sourceUncommitted:true,sourceHashes:source,
 priorImmutableRelease:{releaseId:baseline.releaseId,verifiedUnchanged:true,indexBackup:resolve(run,'baseline-index.html')},
 internalStorageIdentityPreserved:savedNamespace,
 native,desktop:{passed:desktop.passed,checks:desktop.checks,renderer:desktop.renderer,traceSamples:desktop.trace.length,noEArrival:desktop.noInteractionArrival.position,observations:desktop.final.observedEcology},
 touch:{passed:touch.passed,checks:touch.checks,viewport:touch.viewport,physicalDevice:false},
 nativeUi:ui,visualReview,loading:{environment:'Fresh Chromium contexts, local loopback server, RTX 4060 D3D11; no gameplay recorder during these samples. OS/driver caches were not cleared. No public-network claim.',full:timing(loadingFull),lighter:timing(loadingLow)},
 media:readdirSync(final).filter(f=>/\.(png|webm)$/.test(f)).map(f=>({file:f,sha256:hash(resolve(final,f))})),
 mediaDecodes:decodedFrames.map(file=>({file,sha256:hash(resolve(run,file))})),
 publication:'NOT_PUBLISHED: no push or deployment in this request',
 limitations:['Physical phone and Safari not tested','No universal FPS or public-network loading guarantee','Proxy visual review, not independent user acceptance'],
 verification:'No teleport, review camera or snapshot mutation in the recorded player journeys. Storage fault injection only after real touch journey, in a disposable browser context.'
};
writeFileSync(resolve(final,'receipt.json'),JSON.stringify(receipt,null,2));
console.log(JSON.stringify({verdict:receipt.verdict,releaseId:receipt.releaseId,nativeChecks:native.reduce((a,r)=>a+r.checks,0),desktopChecks:Object.keys(desktop.checks).length,touchChecks:Object.keys(touch.checks).length,loading:receipt.loading,final},null,2));
