/* Presentation only. The existing shell retains game/save/launch ownership. */
(() => {
  'use strict';
  const source = document.currentScript.src;
  const assets = new URL('assets/grand-home/',source);
  const veil=document.getElementById('veil'), preview=document.getElementById('region-preview');
  const regions=['aurora_shelf','ember_rift','veil_marsh','pale_decay'];
  const copy={
    en:{scene:'Beyond the arch',keyArt:'Concept artwork',expedition:'LET CURIOSITY LEAD',actual:'Actual gameplay',preview:'Preview the four habitats',names:['Aurora Shelf','Ember Rift','Veil Marsh','Pale Decay'],details:['Crystal ridges · open horizons','Thermal stone · Veyra territory','Quiet water · Aeral flight','Spore hollows · Morrow shells']},
    zh:{scene:'岩拱之外',keyArt:'概念主視覺',expedition:'讓好奇心帶路',actual:'實際遊戲畫面',preview:'預覽四片棲地',names:['極光高原','熱泉裂谷','濃霧沼澤','孢子衰變'],details:['冰晶地脊 · 開闊遠景','熱岩台地 · Veyra 礦殼生物','安靜水岸 · Aeral 霧翼群','孢子窪地 · Morrow 甲殼生物']}
  };
  let selected=0,frame=0,point=null;
  const reduced=()=>document.body.dataset.reducedMotion==='true'||matchMedia('(prefers-reduced-motion: reduce)').matches;
  const home=()=>document.body.dataset.shellPhase==='home';
  function paint(){
    const c=copy[document.documentElement.lang==='zh-Hant'?'zh':'en'];
    for(const node of document.querySelectorAll('[data-art-copy]'))node.textContent=c[node.dataset.artCopy];
    document.querySelector('.game-preview').setAttribute('aria-label',c.actual);
    document.querySelector('.habitat-index').setAttribute('aria-label',c.preview);
    document.getElementById('region-name').textContent=c.names[selected];
    document.getElementById('region-detail').textContent=c.details[selected];
    document.getElementById('preview-index').textContent=String(selected+1).padStart(2,'0')+' / 04';
    preview.alt=c.actual+' · '+c.names[selected];
    for(const b of document.querySelectorAll('[data-region]')){
      const active=b.dataset.region===regions[selected];b.setAttribute('aria-pressed',String(active));b.closest('li').classList.toggle('featured',active);
    }
    const credit=document.querySelector('.game-preview .art-credit');credit.textContent=c.names[selected]+(c===copy.zh?' · 遊戲實景':' · In-game capture');
    if(!home()||reduced())reset();
  }
  function select(index){
    if(index===selected)return;selected=index;
    preview.src=new URL(regions[index]+'-actual.webp',assets).href;paint();
    if(!reduced())preview.animate([{opacity:.5},{opacity:1}],{duration:240,easing:'ease-out'});
  }
  for(const b of document.querySelectorAll('[data-region]')){
    const activate=()=>select(regions.indexOf(b.dataset.region));
    b.addEventListener('click',activate);b.addEventListener('focus',activate);
    b.addEventListener('pointerenter',e=>{if(e.pointerType==='mouse')activate();});
  }
  function reset(){if(frame)cancelAnimationFrame(frame);frame=0;point=null;veil.style.setProperty('--drift-x','0px');veil.style.setProperty('--drift-y','0px');}
  function drift(){frame=0;if(!point||!home()||reduced())return;veil.style.setProperty('--drift-x',((point.x/innerWidth-.5)*-10).toFixed(2)+'px');veil.style.setProperty('--drift-y',((point.y/innerHeight-.5)*-7).toFixed(2)+'px');}
  veil.addEventListener('pointermove',e=>{if(e.pointerType!=='mouse'||!home()||reduced())return;point={x:e.clientX,y:e.clientY};if(!frame)frame=requestAnimationFrame(drift);},{passive:true});
  veil.addEventListener('pointerleave',reset);window.addEventListener('blur',reset);
  document.addEventListener('visibilitychange',()=>{if(document.hidden)reset();});
  const observer=new MutationObserver(paint);observer.observe(document.documentElement,{attributes:true,attributeFilter:['lang']});observer.observe(document.body,{attributes:true,attributeFilter:['data-shell-phase','data-reduced-motion']});
  window.addEventListener('pagehide',()=>{reset();observer.disconnect();},{once:true});paint();
})();
