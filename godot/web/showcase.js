/* The shell owns presentation and launch intent. Godot owns saves and game state. */
(() => {
  'use strict';
  const COPY = {
    en: {
      downloadStep:'Game download', worldStep:'Planet preparation', viewStep:'First game view', preparationLabel:'Game loading stages', atlas:'Four alien regions to explore', elapsed:'Elapsed', received:'received', firstDiscovery:'Your first objective', observation:'Field observation 03', studyArt:'Ecology · In-game capture', specimenHabitat:'VEIL MARSH',
      downloadTitle:'Downloading\nthe game', worldTitle:'Preparing\nthe alien planet', materialTitle:'Preparing\nthe game graphics', viewTitle:'Opening\nthe game view',
      worldStatus:'Preparing the four alien regions…', materialStatus:'Preparing the game graphics…', firstViewStatus:'Waiting for the first game view…', connectingHint:'Opening the game files. The game has not started yet.', worldHint:'Preparing four alien regions and their creatures.', materialHint:'Preparing the terrain, water and creature graphics.', viewHint:'The game view opens when its first frame is ready.', validationHint:'Checking saved game progress before starting.', transferFiles:'Game files', surfaceCount:'Surface preparation', longWait:'First-time downloads and graphics preparation can take longer. Keep this tab open until the game view is ready. If the browser stops responding, let it recover.',
      specimenNotes:['Aeral Veil live in the marsh. Slow down and stop to observe them.', 'A quiet approach changes how nearby creatures respond.', 'Explore Aurora Shelf, Ember Rift, Veil Marsh and Pale Decay.'],
      firstStep:'Drive to the gold map marker. Brake beside the crystals, then observe the signal.', driveTip:'W / arrows · Drive    C (hold) · Crawl    Space · Brake', observeTip:'Right-drag · Look    V · Camera    E · Observe    J · Journal', touchTip:'Drive to move. Crawl + Drive for a quiet approach. Brake to stop, then tap Observe.',
      ready:'Drive a rover.\nExplore an alien planet.', freshJourney:'Saved progress is replaced only after your confirmation.', eyebrow:'ALIEN PLANET EXPLORATION GAME', subtitle:'塵境回聲', intro:'Drive across four alien regions. Stop to observe creatures and investigate signals.', start:'Begin my journey', settings:'Settings', language:'繁中', desktop:'For the richest detail, explore on a desktop. Mobile play uses landscape.', footer:'Drive · Observe creatures · Investigate signals', controls:'Keyboard & mouse · Landscape touch', habitat:'AURORA SHELF', art:'Aurora Shelf · In-game capture', landscapeNote:'Start in Aurora Shelf. Follow the gold marker.', aurora:'Aurora Shelf', ember:'Ember Rift', veil:'Veil Marsh', pale:'Pale Decay', expedition:'Loading the game', specimen:'Aeral Veil', settingsKicker:'Expedition preferences', settingsTitle:'Make yourself at home', settingsNote:'Saved preferences stay in place unless you change them here.', localeLabel:'Language', volumeLabel:'Sound', motionLabel:'Reduced motion', qualityLabel:'Visual detail', saved:'Use saved preference', on:'On', off:'Off', low:'Lighter', high:'Full', done:'Done', restore:'Keep saved preferences', close:'Close settings', loadingTitle:'Loading your rover exploration game', connecting:'Opening the game…', downloading:'Downloading game files…', preparing:'Preparing the alien planet…', validating:'Checking saved game progress…', waiting:'Waiting for the first game view…', transferHint:'Download progress', prepareHint:'Preparing the game before you can drive…', errorTitle:'The game could not open', error:'The game could not open. Try again, or return to the home screen.', support:'This browser cannot provide the required 3D graphics. Try a browser with hardware acceleration enabled.', lost:'The graphics connection was interrupted. Reload the page to restart the game. Your preferences will be kept.', timeout:'Game loading is taking longer than expected. Return home to try again, or reload if it remains unavailable.', retry:'Try again', reload:'Reload page', home:'Return home', loadingFooter:'Explore four regions. Drive, observe and follow signals.', stopMotion:'Pause animation', resumeMotion:'Resume animation', canvas:'Signal in the Dust alien-planet rover exploration game'
    },
    zh_TW: {
      downloadStep:'下載遊戲', worldStep:'準備星球', viewStep:'開啟畫面', preparationLabel:'遊戲載入階段', atlas:'探索四個外星區域', elapsed:'已等候', received:'已接收', firstDiscovery:'第一個探索目標', observation:'生態場記 03', studyArt:'生態 · 遊戲實景', specimenHabitat:'濃霧沼澤',
      downloadTitle:'正在下載\n遊戲內容', worldTitle:'正在準備\n外星星球', materialTitle:'正在準備\n遊戲畫面', viewTitle:'正在開啟\n遊戲畫面',
      worldStatus:'正在準備四個外星區域…', materialStatus:'正在準備遊戲畫面…', firstViewStatus:'正在等候第一個遊戲畫面…', connectingHint:'正在開啟遊戲內容，遊戲尚未開始。', worldHint:'正在準備四個外星區域與其中的生物。', materialHint:'正在準備地形、水面與生物的畫面。', viewHint:'第一個遊戲畫面準備完成後，才會開啟遊戲。', validationHint:'開始前，正在確認已儲存的遊戲進度。', transferFiles:'遊戲內容', surfaceCount:'表面準備', longWait:'首次下載與畫面準備可能需要較多時間。請保持此分頁開啟，等候遊戲畫面準備完成。若瀏覽器暫時未有回應，請先等它恢復。',
      specimenNotes:['Aeral 霧翼群生活在濃霧沼澤。減速停車，靠近觀察。', '安靜靠近時，附近生物會以不同方式回應。', '探索極光高原、熱泉裂谷、濃霧沼澤與孢子衰變。'],
      firstStep:'駕駛探索車前往地圖的金色標記；在冰晶旁煞車停下，觀察生命訊號。', driveTip:'W／方向鍵 · 駕駛　按住 C · 慢行　空白鍵 · 煞車', observeTip:'按住右鍵拖曳 · 環顧　V · 視角　E · 觀察　J · 日誌', touchTip:'點前進駕駛；慢行＋前進可安靜靠近。煞車停下後，點互動觀察。',
      ready:'駕駛探索車，\n探索外星星球', freshJourney:'確認重新出發前，已儲存的旅程會為你保留。', eyebrow:'外星星球探索遊戲', subtitle:'塵境回聲', intro:'駕駛探索車穿越四個外星區域，減速停車，觀察生物與調查生命訊號。', start:'開啟我的旅程', settings:'設定', language:'EN', desktop:'電腦可呈現更豐富的細節；手機請以橫向遊玩。', footer:'駕駛探索車 · 觀察生物 · 調查訊號', controls:'鍵盤與滑鼠 · 橫向觸控', habitat:'極光高原', art:'極光高原 · 遊戲實景', landscapeNote:'從極光高原出發，跟隨金色標記。', aurora:'極光高原', ember:'熱泉裂谷', veil:'濃霧沼澤', pale:'孢子衰變', expedition:'正在載入遊戲', specimen:'Aeral 霧翼群', settingsKicker:'旅程偏好', settingsTitle:'以你的步調出發', settingsNote:'除非在此更改，否則沿用遊戲已儲存的偏好。', localeLabel:'語言', volumeLabel:'音量', motionLabel:'減少動態效果', qualityLabel:'畫面細節', saved:'沿用遊戲偏好', on:'開啟', off:'關閉', low:'輕量', high:'完整', done:'完成', restore:'沿用已儲存偏好', close:'關閉設定', loadingTitle:'正在載入探索車遊戲', connecting:'正在開啟遊戲…', downloading:'正在下載遊戲內容…', preparing:'正在準備外星星球…', validating:'正在確認已儲存的遊戲進度…', waiting:'正在等候第一個遊戲畫面…', transferHint:'實際下載進度', prepareHint:'正在準備遊戲，完成後即可駕駛探索車…', errorTitle:'遊戲暫時未能開啟', error:'遊戲暫時未能開啟。你可以再試一次，或先返回首頁。', support:'此瀏覽器未能提供所需的 3D 圖像支援，請使用已啟用硬件加速的瀏覽器。', lost:'圖像連線中斷。請重新載入，重新開啟遊戲。語言與設定會保留。', timeout:'遊戲載入時間比預期長。你可以返回首頁再試一次；若仍未能開啟，請重新載入。', retry:'再試一次', reload:'重新載入', home:'返回首頁', loadingFooter:'探索四個外星區域，駕駛、觀察並追蹤訊號。', stopMotion:'暫停動畫', resumeMotion:'繼續動畫', canvas:'塵境回聲：外星星球探索車遊戲'
    }
  };
  const $ = id => document.getElementById(id);
  const canvas = $('canvas'), veil = $('veil'), home = $('home'), loading = $('loading');
  const dialog = $('settings-dialog'), progress = $('progress'), percent = $('percent');
  const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const initialLocale = /^zh/i.test(navigator.language) ? 'zh_TW' : 'en';
  let locale = initialLocale, overrides = {}, pending = null, engine = null;
  let startPromise = null, started = false, fatal = false, busy = false;
  let guard = 0, fade = 0, restoreFetch = null, phaseKey = 'connecting', errorKey = 'error';
  let homeMessage = '', lastStatus = '', sequence = 0, pausedAnimation = false;
  let lastAction = 'new';
  let bootDeadline = 0, lastBootProgress = 0, lastTransferBytes = 0;
  let transferCurrent = 0, transferTotal = 0, lastLoadingSignature = '';
  window.__EXPEDITION_ERRORS__ = window.__EXPEDITION_ERRORS__ || [];
  let bootTiming = {
    action: null,
    coldStart: null,
    timestampsMs: { shell_script_evaluated_ms: performance.now() },
    durationsMs: {}
  };

  function publishBootTimings(preserveGodot = true) {
    const previousGodot = preserveGodot ? (window.__EXPEDITION_BOOT_TIMINGS__?.godot ?? null) : null;
    const shell = Object.freeze({
      clock: 'performance.now() monotonic milliseconds since navigation start',
      action: bootTiming.action,
      cold_start: bootTiming.coldStart,
      timestamps_ms: Object.freeze({ ...bootTiming.timestampsMs }),
      durations_ms: Object.freeze({ ...bootTiming.durationsMs })
    });
    const snapshot = Object.freeze({
      version: 1,
      readonly: true,
      shell,
      godot: previousGodot,
      unavailable_or_combined: Object.freeze({
        wasm_compile_ms: 'unknown; browser/engine work is combined within engine.startGame()',
        shader_compile_ms: 'unknown; browser/engine work is combined through engine start and first rendered frame',
        wasm_decompression_completion_ms: 'unknown; the existing streaming decode path does not expose its completion separately'
      })
    });
    Object.defineProperty(window, '__EXPEDITION_BOOT_TIMINGS__', {
      value: snapshot, writable: false, configurable: true, enumerable: true
    });
  }
  function markBootTiming(name, at = performance.now()) {
    bootTiming.timestampsMs[name] = at;
    publishBootTimings();
    return at;
  }
  function completeBootTiming(name, startedAt, completedName) {
    const completedAt = markBootTiming(completedName);
    if (Number.isFinite(startedAt)) {
      bootTiming.durationsMs[name] = completedAt - startedAt;
      publishBootTimings();
    }
    return completedAt;
  }
  function resetBootTimings(action) {
    const requestedAt = performance.now();
    bootTiming = {
      action,
      coldStart: !started,
      timestampsMs: {
        shell_script_evaluated_ms: bootTiming.timestampsMs.shell_script_evaluated_ms,
        launch_requested_ms: requestedAt
      },
      durationsMs: {}
    };
    publishBootTimings(false);
  }
  publishBootTimings();

  function reducedMotion() { return overrides.reduced_motion ?? systemMotion.matches; }
  function updateMotion() {
    document.body.dataset.reducedMotion = String(reducedMotion() || pausedAnimation);
    document.body.dataset.bloomMotion = reducedMotion() ? 'reduced' : pausedAnimation ? 'paused' : 'running';
    $('pause-animation').setAttribute('aria-pressed',String(pausedAnimation));
    $('pause-animation').hidden = reducedMotion() || document.body.dataset.shellPhase === 'error';
  }
  function translate() {
    const copy = COPY[locale];
    document.documentElement.lang = locale === 'zh_TW' ? 'zh-Hant' : 'en';
    for (const node of document.querySelectorAll('[data-copy]')) node.textContent = copy[node.dataset.copy];
    canvas.setAttribute('aria-label', copy.canvas);
    progress.setAttribute('aria-label',copy.transferHint);
    $('open-settings').setAttribute('aria-label', copy.settings);
    $('close-settings').setAttribute('aria-label', copy.close);
    $('language-toggle').setAttribute('aria-label', locale === 'en' ? '切換至繁體中文' : 'Switch to English');
    $('status').textContent = copy[document.body.dataset.shellPhase === 'error' ? errorKey : phaseKey];
    $('loading-title').textContent = copy[document.body.dataset.shellPhase === 'error' ? 'errorTitle' : 'loadingTitle'];
    $('home-message').textContent = homeMessage ? copy[homeMessage] : '';
    $('phase-detail').textContent = copy[progress.hasAttribute('value') ? 'transferHint' : 'prepareHint'];
    $('pause-animation').textContent = copy[pausedAnimation ? 'resumeMotion' : 'stopMotion'];
    $('retry').textContent = copy[fatal ? 'reload' : 'retry'];
    $('volume-value').textContent = overrides.volume === undefined ? '—' : `${Math.round(overrides.volume * 100)}%`;
    $('control-drive').textContent = copy[window.__EXPEDITION_TOUCH__ ? 'touchTip' : 'driveTip'];
    $('control-observe').hidden = !!window.__EXPEDITION_TOUCH__;
    $('arrival-purpose').textContent = copy.firstStep;
    $('loading-stages').setAttribute('aria-label',copy.preparationLabel);
    updateLoadingExperience(true);
  }
  function updateLoadingExperience(force = false) {
    if (document.body.dataset.shellPhase !== 'loading') return;
    const copy = COPY[locale];
    const value = window.__EXPEDITION_PREPARATION__;
    const preparation = value?.version === 1 && ['world','materials','first-view'].includes(value.phase) ? value : null;
    const elapsed = Math.max(0, Math.floor((performance.now() - bootTiming.timestampsMs.launch_requested_ms) / 1000)) || 0;
    const stage = ['connecting','downloading'].includes(phaseKey) ? 'download' : phaseKey === 'validating' ? 'first-view' : preparation?.phase || (phaseKey === 'waiting' ? 'first-view' : 'world');
    const signature = `${locale}:${phaseKey}:${stage}:${preparation?.completed}:${preparation?.total}:${transferCurrent}:${transferTotal}:${elapsed}`;
    if (!force && signature === lastLoadingSignature) return;
    lastLoadingSignature = signature;
    document.body.dataset.preparationStage = stage;
    $('loading-title').textContent = copy[{download:'downloadTitle',world:'worldTitle',materials:'materialTitle','first-view':'viewTitle'}[stage]];
    if (phaseKey !== 'connecting' && phaseKey !== 'downloading' && phaseKey !== 'validating') {
      $('status').textContent = copy[{world:'worldStatus',materials:'materialStatus','first-view':'firstViewStatus'}[stage]];
    }
    const step = stage === 'download' ? 0 : stage === 'first-view' ? 2 : 1;
    [...$('loading-stages').children].forEach((node,index) => {
      node.dataset.state = index < step ? 'complete' : index === step ? 'current' : 'pending';
      if (index === step) node.setAttribute('aria-current','step');
      else node.removeAttribute('aria-current');
    });
    let detail = copy[phaseKey === 'connecting' ? 'connectingHint' : phaseKey === 'downloading' ? 'transferHint' : phaseKey === 'validating' ? 'validationHint' : stage === 'materials' ? 'materialHint' : stage === 'first-view' ? 'viewHint' : 'worldHint'];
    if (phaseKey === 'downloading' && (transferCurrent > 0 || transferTotal > 0)) {
      const received = `${(transferCurrent / 1048576).toFixed(1)} MiB`;
      detail = `${copy.transferFiles} · ${received}${transferTotal > 0 ? ` / ${(transferTotal / 1048576).toFixed(1)} MiB` : ` ${copy.received}`}`;
    } else if (stage === 'materials' && Number.isInteger(preparation?.completed) && Number.isInteger(preparation?.total) && preparation.total > 0 && preparation.completed >= 0 && preparation.completed <= preparation.total) {
      detail = `${copy.surfaceCount} · ${Math.floor(preparation.completed)} / ${Math.floor(preparation.total)}`;
    }
    $('phase-detail').textContent = detail;
    progress.setAttribute('aria-label',copy[progress.hasAttribute('value') ? 'transferHint' : 'prepareHint']);
    $('waiting-elapsed').textContent = `${String(Math.floor(elapsed / 60)).padStart(2,'0')}:${String(elapsed % 60).padStart(2,'0')}`;
    $('wait-note').hidden = elapsed < 25;
    $('specimen-note').textContent = copy.specimenNotes[Math.floor(elapsed / 18) % copy.specimenNotes.length];
  }
  function blockGame(blocked) {
    canvas.inert = blocked;
    canvas.setAttribute('aria-hidden', String(blocked));
    if (blocked) {
      window.dispatchEvent(new Event('expedition-shell-blocked'));
      if (document.pointerLockElement) document.exitPointerLock?.();
      if (['arrival','exploring','contact'].includes(window.__EXPEDITION_STATE__?.phase)) window.expeditionTouch?.('pause_only', true);
    }
  }
  function showHome(message = '') {
    clearTimeout(guard); clearTimeout(fade); busy = false; homeMessage = message;
    document.body.dataset.shellPhase = 'home';
    veil.classList.remove('hidden', 'departing'); veil.inert = false;
    home.hidden = false; loading.hidden = true; $('home-footer').hidden = false;
    $('home-message').hidden = !message;
    $('start').disabled = false;
    blockGame(true); translate();
    if (pending) $('start').focus({preventScroll:true});
  }
  function showLoading() {
    clearTimeout(fade); document.body.dataset.shellPhase = 'loading';
    veil.classList.remove('hidden','departing'); veil.inert = false;
    home.hidden = true; loading.hidden = false; $('home-footer').hidden = true;
    $('error-actions').hidden = true; $('progress-line').hidden = false; $('phase-detail').hidden = false; updateMotion();
    $('loading-title').focus({preventScroll:true}); blockGame(true);
    setProgress(null, 'connecting');
  }
  function setProgress(value, key) {
    phaseKey = key;
    if (value === null) { progress.removeAttribute('value'); percent.textContent = '—'; }
    else { progress.value = value; percent.textContent = `${Math.floor(value)}%`; }
    translate();
  }
  function finishOnFrame() {
    clearTimeout(guard); busy = false;
    if (!Number.isFinite(bootTiming.timestampsMs.first_interactive_ms)) {
      const interactiveAt = markBootTiming('first_interactive_ms');
      const requestedAt = bootTiming.timestampsMs.launch_requested_ms;
      if (Number.isFinite(requestedAt)) {
        bootTiming.durationsMs.launch_to_first_interactive_ms = interactiveAt - requestedAt;
        publishBootTimings();
      }
    }
    document.body.dataset.shellPhase = 'game';
    veil.classList.add('departing'); veil.inert = true; blockGame(false);
    canvas.focus({preventScroll:true});
    fade = setTimeout(() => { if (document.body.dataset.shellPhase === 'game') veil.classList.add('hidden'); }, reducedMotion() ? 0 : 440);
    // Initial play in portrait must pause as well as a later orientation change.
    if (window.__EXPEDITION_TOUCH__ && innerHeight > innerWidth) window.expeditionTouch?.('pause_only', true);
  }
  function fail(key = 'error', detail = null, isFatal = false) {
    clearTimeout(guard); clearTimeout(fade); fatal ||= isFatal; busy = false; errorKey = key;
    document.body.dataset.shellPhase = 'error';
    veil.classList.remove('hidden','departing'); veil.inert = false;
    home.hidden = true; loading.hidden = false; $('home-footer').hidden = true;
    $('error-actions').hidden = false; $('progress-line').hidden = true; $('phase-detail').hidden = true; $('pause-animation').hidden = true;
    blockGame(true); translate(); $('retry').focus({preventScroll:true});
    if (detail) { window.__EXPEDITION_ERRORS__.push(String(detail)); console.error(detail); }
  }
  function syncSettings() {
    $('setting-locale').value = overrides.locale ?? '';
    $('setting-volume').value = String(Math.round((overrides.volume ?? .7) * 100));
    $('setting-motion').value = overrides.reduced_motion === undefined ? '' : String(overrides.reduced_motion);
    $('setting-quality').value = overrides.low_quality === undefined ? '' : String(overrides.low_quality);
    translate();
  }
  function request(action) {
    return { version:1, requestId:`web-${Date.now().toString(36)}-${++sequence}-${Math.random().toString(36).slice(2,9)}`, action, settings:{...overrides} };
  }
  function loadEngineScript() {
    if (typeof window.Engine === 'function') {
      markBootTiming('engine_script_already_available_ms');
      return Promise.resolve();
    }
    const downloadStartedAt = markBootTiming('engine_script_download_start_ms');
    return new Promise((resolve,reject) => {
      const script = document.createElement('script');
      script.src = document.getElementById('engine-source').dataset.src;
      script.onload = () => {
        if (typeof window.Engine === 'function') {
          completeBootTiming('engine_script_download_ms', downloadStartedAt, 'engine_script_download_complete_ms');
          resolve();
        } else reject(new Error('Engine entry unavailable'));
      };
      script.onerror = () => reject(new Error('Engine download failed'));
      document.head.append(script);
    });
  }
  function installWasmDecode(config) {
    // Support raw exports and precompressed WASM even on hosts ignoring _headers.
    // Limit interception to this asset, preserve headers/length on raw responses.
    const originalFetch = window.fetch;
    const wasmUrl = new URL(config.executable + '.wasm', location.href).href;
    const packUrl = new URL(config.mainPack || config.executable + '.pck', location.href).href;
    const decodeFetch = async (resource, options) => {
      const requested = new URL(resource instanceof Request ? resource.url : resource, location.href).href;
      if (requested === packUrl && config.packParts) {
        const parts = config.packParts;
        if (!Array.isArray(parts) || parts.length < 2 || parts.some((part,index) =>
          part.name !== 'index.pck.part-' + String(index).padStart(3,'0') ||
          !Number.isSafeInteger(part.bytes) || part.bytes <= 0 || part.bytes > 64*1024*1024)) {
          throw new Error('Invalid game package parts');
        }
        const total = parts.reduce((sum,part) => sum + part.bytes,0);
        if (!Number.isSafeInteger(total) || config.fileSizes?.[config.mainPack || config.executable + '.pck'] !== total) {
          throw new Error('Invalid game package size');
        }
        const fetchPart = async index => {
          const url = new URL(parts[index].name,packUrl).href;
          const input = resource instanceof Request ? new Request(url,resource) : url;
          const response = await originalFetch.call(window,input,options);
          if (!response.ok || !response.body) throw new Error('Game package part download failed');
          return response.body.getReader();
        };
        let index = 0, received = 0, reader = await fetchPart(0);
        const body = new ReadableStream({
          async pull(controller) {
            while (true) {
              const chunk = await reader.read();
              if (!chunk.done) {
                received += chunk.value.byteLength;
                if (received > parts[index].bytes) throw new Error('Game package part size mismatch');
                controller.enqueue(chunk.value); return;
              }
              if (received !== parts[index].bytes) throw new Error('Truncated game package part');
              reader.releaseLock(); index += 1; received = 0;
              if (index === parts.length) { controller.close(); return; }
              reader = await fetchPart(index);
            }
          },
          cancel(reason) { return reader.cancel(reason); }
        });
        return new Response(body,{headers:{'Content-Type':'application/octet-stream','Content-Length':String(total)}});
      }
      const wasmFetchStartedAt = requested === wasmUrl ? markBootTiming('wasm_fetch_start_ms') : null;
      const response = await originalFetch.call(window, resource, options);
      if (requested !== wasmUrl || !response.ok) return response;
      // Inspect only the signature. Keep network, decoding and compilation streaming.
      const reader = response.body.getReader(), prefix = [];
      let length = 0;
      while (length < 4) {
        const chunk = await reader.read();
        if (chunk.done) break;
        prefix.push(chunk.value); length += chunk.value.length;
      }
      const signature = prefix.flatMap(chunk => Array.from(chunk.subarray(0,4))).slice(0,4);
      const gzip = signature[0] === 0x1f && signature[1] === 0x8b;
      if (!gzip && ![0,97,115,109].every((byte,index) => signature[index] === byte)) {
        await reader.cancel(); throw new Error('Invalid game engine download');
      }
      let body = new ReadableStream({
        async pull(controller) {
          if (prefix.length) { controller.enqueue(prefix.shift()); return; }
          const chunk = await reader.read();
          if (chunk.done) { markBootTiming('wasm_stream_read_complete_ms'); controller.close(); }
          else controller.enqueue(chunk.value);
        },
        cancel(reason) { return reader.cancel(reason); }
      });
      const headers = new Headers(response.headers); headers.set('Content-Type','application/wasm');
      if (gzip || headers.has('Content-Encoding')) headers.delete('Content-Length');
      headers.delete('Content-Encoding');
      if (gzip) {
        if (typeof DecompressionStream === 'undefined') {
          await body.cancel(); throw new Error('Browser cannot decode game package');
        }
        const setupStartedAt = markBootTiming('wasm_decompression_stream_setup_start_ms');
        body = body.pipeThrough(new DecompressionStream('gzip'));
        completeBootTiming('wasm_decompression_stream_setup_ms', setupStartedAt, 'wasm_decompression_stream_setup_complete_ms');
      }
      completeBootTiming('wasm_fetch_to_stream_ready_ms', wasmFetchStartedAt, 'wasm_response_ready_ms');
      return new Response(body,{status:response.status,headers});
    };
    window.fetch = decodeFetch;
    return () => { if (window.fetch === decodeFetch) window.fetch = originalFetch; };
  }
  function withBootFailures(start) {
    // Godot's generated init wrapper can leave its promise pending on rejection.
    // Observe failures only during boot; preserve console reporting and one instance.
    let onRejection, onError;
    const failed = new Promise((resolve,reject) => {
      onRejection = event => reject(event.reason || new Error('Engine initialization failed'));
      onError = event => { if (event.message) reject(event.error || new Error(event.message)); };
      window.addEventListener('unhandledrejection',onRejection);
      window.addEventListener('error',onError);
    });
    return Promise.race([Promise.resolve().then(start),failed]).finally(() => {
      window.removeEventListener('unhandledrejection',onRejection);
      window.removeEventListener('error',onError);
    });
  }
  async function initialize() {
    await loadEngineScript();
    if (window.Engine.getMissingFeatures({threads:false}).length) {
      fail('support', null, true); return;
    }
    const config = window.__EXPEDITION_ENGINE_CONFIG__;
    const engineInitializationStartedAt = markBootTiming('engine_initialization_start_ms');
    engine = new window.Engine(config);
    completeBootTiming('engine_initialization_ms', engineInitializationStartedAt, 'engine_initialization_complete_ms');
    restoreFetch = installWasmDecode(config);
    try {
      const engineStartStartedAt = markBootTiming('engine_start_start_ms');
      await withBootFailures(() => engine.startGame({canvas,
        onProgress(current,total) {
          if (!busy || document.body.dataset.shellPhase !== 'loading') return;
          transferCurrent = Number.isFinite(current) && current >= 0 ? current : 0;
          transferTotal = Number.isFinite(total) && total > 0 ? total : 0;
          if (Number.isFinite(current) && current > lastTransferBytes) {
            lastTransferBytes = current; refreshBootGuard();
          }
          if (Number.isFinite(total) && total > 0 && Number.isFinite(current) && current >= 0) {
            if (current < total && !Number.isFinite(bootTiming.timestampsMs.engine_reported_download_start_ms)) {
              markBootTiming('engine_reported_download_start_ms');
            }
            if (current >= total && !Number.isFinite(bootTiming.timestampsMs.engine_reported_download_complete_ms)) {
              const completedAt = markBootTiming('engine_reported_download_complete_ms');
              const downloadStartedAt = bootTiming.timestampsMs.engine_reported_download_start_ms;
              if (Number.isFinite(downloadStartedAt)) {
                bootTiming.durationsMs.engine_reported_download_ms = completedAt - downloadStartedAt;
                publishBootTimings();
              }
            }
          }
          if (Number.isFinite(total) && total > 0 && Number.isFinite(current) && current >= 0 && current < total) setProgress(Math.min(100,current/total*100),'downloading');
          else setProgress(null, total > 0 && current >= total ? 'preparing' : 'downloading');
        },
        onPrintError(...args) {
          const message = args.join(' '); window.__EXPEDITION_ERRORS__.push(message); console.error(message);
          if (busy && document.body.dataset.shellPhase === 'loading' && /ERROR:|SCRIPT ERROR|Parse Error|shader.*failed/i.test(message)) {
            window.__EXPEDITION_FATAL_BOOT_ERROR__ = true;
            fail('error', null, true);
          }
        }
      }));
      completeBootTiming('engine_start_until_ready_ms', engineStartStartedAt, 'engine_ready_ms');
      started = true;
      if (busy && document.body.dataset.shellPhase === 'loading') setProgress(null,'waiting');
      inspectStatus();
    } finally { restoreFetch?.(); restoreFetch = null; }
  }
  function refreshBootGuard() {
    clearTimeout(guard);
    guard = setTimeout(() => {
      // Bound inactivity as well as total boot time; never start a second engine.
      restoreFetch?.(); restoreFetch = null;
      fail('timeout', null, !started || typeof window.expeditionLaunch !== 'function');
    }, Math.max(0,Math.min(120000,bootDeadline - performance.now())));
  }
  async function launch(action) {
    if (action !== 'new' || busy) return;
    if (fatal) { fail(errorKey, null, true); return; }
    lastAction = action; busy = true; pending = request(action); lastStatus = '';
    resetBootTimings(action);
    bootDeadline = performance.now() + 600000;
    lastBootProgress = Number(window.__EXPEDITION_BOOT_PROGRESS__) || 0;
    lastTransferBytes = 0;
    transferCurrent = 0; transferTotal = 0; lastLoadingSignature = '';
    $('start').disabled = true; showLoading();
    refreshBootGuard();
    try {
      if (startPromise) {
        if (!started || typeof window.expeditionLaunch !== 'function') { fail('timeout',null,true); return; }
        setProgress(null,'validating');
        window.expeditionLaunch(JSON.stringify(pending));
      } else {
        window.__EXPEDITION_BOOT_REQUEST__ = pending;
        startPromise = initialize();
        await startPromise;
      }
    } catch (error) { fail('error', error, true); }
  }
  function inspectStatus() {
    updateLoadingExperience();
    const completed = window.__EXPEDITION_BOOT_PROGRESS__;
    if (busy && Number.isFinite(completed) && completed > lastBootProgress) {
      lastBootProgress = completed; refreshBootGuard();
    }
    const status = window.__EXPEDITION_BOOT_STATUS__;
    if (!pending || !status || status.version !== 1 || status.requestId !== pending.requestId || fatal) return;
    const signature = `${status.requestId}:${status.stage}:${status.firstFrameReady}:${status.savedAvailable}:${status.saveState}:${status.saveWriteFailed}`;
    if (signature === lastStatus) return;
    lastStatus = signature;
    translate();
    if (['playing','confirm-new'].includes(status.stage)) {
      if (status.firstFrameReady === true && started) finishOnFrame();
      else if (busy) { lastStatus = ''; setProgress(null,'waiting'); }
    } else if (status.stage === 'home') showHome();
    else if (status.stage === 'error') fail('error', null, status.fatal === true);
    else if (busy && ['initializing','validating'].includes(status.stage)) {
      if (status.stage === 'validating' || started) setProgress(null,status.stage === 'validating' ? 'validating' : 'preparing');
    }
  }

  $('start').addEventListener('click',() => launch('new'));
  $('retry').addEventListener('click',() => fatal ? location.reload() : launch(lastAction));
  $('return-home').addEventListener('click',() => { pending = null; showHome(); $('start').focus({preventScroll:true}); });
  $('open-settings').addEventListener('click',() => { syncSettings(); dialog.showModal(); });
  $('close-settings').addEventListener('click',() => dialog.close());
  $('settings-done').addEventListener('click',() => dialog.close());
  // Keep Tab at either edge in the open dialog, including embedded browsers
  // that otherwise move focus from the first control into application chrome.
  dialog.addEventListener('keydown',event => {
    if (event.key !== 'Tab') return;
    const controls = [...dialog.querySelectorAll('button,input,select')].filter(control => !control.disabled);
    const first = controls[0], last = controls[controls.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  });
  $('language-toggle').addEventListener('click',() => { locale = locale === 'en' ? 'zh_TW' : 'en'; overrides.locale = locale; translate(); });
  $('setting-locale').addEventListener('change',event => {
    const value = event.target.value;
    if (['en','zh_TW'].includes(value)) { overrides.locale = value; locale = value; }
    else { delete overrides.locale; locale = initialLocale; }
    translate();
  });
  $('setting-volume').addEventListener('input',event => { overrides.volume = Math.max(0,Math.min(1,Number(event.target.value)/100)); translate(); });
  for (const [id,key] of [['setting-motion','reduced_motion'],['setting-quality','low_quality']]) {
    $(id).addEventListener('change',event => {
      if (event.target.value === '') delete overrides[key];
      else overrides[key] = event.target.value === 'true';
      updateMotion();
    });
  }
  $('restore-settings').addEventListener('click',() => { overrides = {}; locale = initialLocale; updateMotion(); syncSettings(); });
  $('pause-animation').addEventListener('click',() => { pausedAnimation = !pausedAnimation; updateMotion(); translate(); });
  systemMotion.addEventListener('change', updateMotion);
  // Queue genuine focus loss for Godot to consume on its own frame. No callback
  // re-entry and no key-state synthesis; Godot owns pause, save and input release.
  window.addEventListener('blur',() => { window.__EXPEDITION_FOCUS_LOST__ = true; document.body.classList.add('page-unfocused'); });
  window.addEventListener('focus',() => document.body.classList.remove('page-unfocused'));
  document.addEventListener('visibilitychange',() => { document.body.classList.toggle('page-hidden',document.hidden); if (document.hidden) window.__EXPEDITION_FOCUS_LOST__ = true; else inspectStatus(); });
  canvas.addEventListener('webglcontextlost',() => fail('lost',null,true));
  canvas.addEventListener('contextmenu',event => event.preventDefault());
  const poll = setInterval(inspectStatus,100);
  window.addEventListener('pagehide',() => { clearTimeout(guard); clearTimeout(fade); clearInterval(poll); restoreFetch?.(); window.dispatchEvent(new Event('expedition-shell-blocked')); });
  window.addEventListener('pageshow',event => { if (event.persisted) location.reload(); });
  updateMotion(); showHome(); syncSettings();
})();

