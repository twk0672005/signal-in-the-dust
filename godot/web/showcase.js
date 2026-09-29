/* The shell owns presentation and launch intent. Godot owns saves and game state. */
(() => {
  'use strict';
  const COPY = {
    en: {
      resumeStep:'Your journal keeps the discoveries you made. Follow the current map marker, or choose another habitat encounter.', localSave:'Progress stays in this browser. No account needed.', saveUnknown:'Continue checks for a saved expedition in this browser.', saveAbsent:'No saved expedition in this browser yet. Start exploring to begin.', saveValid:'A saved expedition is available in this browser.', saveUnreadable:'The save could not be read. Continue can check again; starting anew may replace older progress.', saveWriteFailed:'Progress could not be saved. Continue may return to an older checkpoint.', firstStep:'You are tracing a living signal. Follow the gold map marker to the crystals, then stop and listen.', driveTip:'W / arrows · Drive    C (hold) · Crawl    Space · Brake', observeTip:'Right-drag · Look    V · Camera    E · Observe    J · Journal', touchTip:'Drive to move. Crawl + Drive for a quiet approach. Brake to stop, then tap Observe.',
      eyebrow:'A field journey beyond the familiar', subtitle:'塵境回聲', intro:'Between mineral and living things, a world is quietly unfolding. Take the rover. Find your own way.', start:'Start exploring', continue:'Continue', settings:'Settings', language:'繁中', desktop:'For the richest detail, explore on a desktop. Mobile play uses landscape.', footer:'Four habitats. One quiet expedition.', controls:'Keyboard & mouse · Landscape touch', habitat:'VEIL MARSH', art:'Veil Marsh · Concept artwork', landscapeNote:'Where the water holds the light.', aurora:'Aurora Shelf', ember:'Ember Rift', veil:'Veil Marsh', pale:'Pale Decay', expedition:'The expedition', specimen:'Life in bloom', settingsKicker:'Expedition preferences', settingsTitle:'Make yourself at home', settingsNote:'Saved preferences stay in place unless you change them here.', localeLabel:'Language', volumeLabel:'Sound', motionLabel:'Reduced motion', qualityLabel:'Visual detail', saved:'Use saved preference', on:'On', off:'Off', low:'Lighter', high:'Full', done:'Done', restore:'Keep saved preferences', close:'Close settings', loadingTitle:'A world is coming into view', connecting:'Opening the expedition…', downloading:'Downloading the expedition…', preparing:'Preparing the living world…', validating:'Checking your expedition…', waiting:'Waiting for the first view…', transferHint:'Download progress', prepareHint:'Getting ready to enter the world…', errorTitle:'The signal was interrupted', error:'The expedition could not open. You can try again or return home.', support:'This browser cannot provide the required 3D graphics. Try a browser with hardware acceleration enabled.', lost:'The graphics connection was interrupted. Reload the page, then try Continue to check for progress saved in this browser.', timeout:'The expedition is taking longer than expected. Return home to try again, or reload if it remains unavailable.', unavailable:'A readable save could not be confirmed. Try Continue again, or start a new expedition.', retry:'Try again', reload:'Reload page', home:'Return home', loadingFooter:'Take a moment. There is no hurry here.', stopMotion:'Pause animation', resumeMotion:'Resume animation', canvas:'Signal in the Dust exploration game'
    },
    zh_TW: {
      resumeStep:'日誌保留了你的發現。沿目前的地圖標記前進，或選擇另一項棲地邂逅。', localSave:'進度只保存在此瀏覽器，毋須帳戶。', saveUnknown:'繼續旅程會檢查此瀏覽器的探勘存檔。', saveAbsent:'此瀏覽器尚無探勘存檔，請選擇開始探索。', saveValid:'此瀏覽器有可讀取的探勘存檔。', saveUnreadable:'未能讀取存檔。可再試繼續旅程；開始新旅程可能取代舊進度。', saveWriteFailed:'未能儲存進度。繼續旅程可能回到較早的進度。', firstStep:'你正在追尋生命訊號。沿地圖金色標記找到冰晶，停車聆聽。', driveTip:'W／方向鍵 · 駕駛　按住 C · 慢行　空白鍵 · 煞車', observeTip:'按住右鍵拖曳 · 環顧　V · 視角　E · 觀察　J · 日誌', touchTip:'點前進駕駛；慢行＋前進可安靜靠近。煞車停下後，點互動觀察。',
      eyebrow:'循著好奇，走進陌生的生命世界', subtitle:'塵境回聲', intro:'在礦物與生命之間，一片世界正靜靜展開。駕上探測車，走出自己的路。', start:'開始探索', continue:'繼續旅程', settings:'設定', language:'EN', desktop:'電腦可呈現更豐富的細節；手機請以橫向遊玩。', footer:'四片棲地，一段安靜的遠行。', controls:'鍵盤與滑鼠 · 橫向觸控', habitat:'帷幕濕地', art:'帷幕濕地 · 概念美術', landscapeNote:'水面，留住了光。', aurora:'極光高原', ember:'熱泉裂谷', veil:'濃霧沼澤', pale:'孢子衰變', expedition:'探索旅程', specimen:'生命的綻放', settingsKicker:'旅程偏好', settingsTitle:'以你的步調出發', settingsNote:'除非在此更改，否則沿用遊戲已儲存的偏好。', localeLabel:'語言', volumeLabel:'音量', motionLabel:'減少動態效果', qualityLabel:'畫面細節', saved:'沿用遊戲偏好', on:'開啟', off:'關閉', low:'輕量', high:'完整', done:'完成', restore:'沿用已儲存偏好', close:'關閉設定', loadingTitle:'世界正漸漸清晰', connecting:'正在開啟旅程…', downloading:'正在下載探索內容…', preparing:'正在準備這片生命世界…', validating:'正在確認旅程…', waiting:'正在等候第一個畫面…', transferHint:'實際下載進度', prepareHint:'正在準備進入世界…', errorTitle:'訊號暫時中斷', error:'旅程暫時未能開啟。你可以重試，或先返回首頁。', support:'此瀏覽器未能提供所需的 3D 圖像支援，請使用已啟用硬件加速的瀏覽器。', lost:'圖像連線中斷。重新載入後，可試「繼續旅程」檢查此瀏覽器的存檔。', timeout:'準備時間比預期長。你可以返回首頁重試；若仍未能開啟，請重新載入。', unavailable:'未能確認可讀取的存檔。可再試「繼續旅程」，或開始新旅程。', retry:'再試一次', reload:'重新載入', home:'返回首頁', loadingFooter:'慢慢來。這片世界，值得等一會。', stopMotion:'暫停動畫', resumeMotion:'繼續動畫', canvas:'Signal in the Dust 外星探索遊戲'
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
  let lastAction = 'new', savedAvailable = null;
  let saveState = 'unknown', saveWriteFailed = false;
  let bootDeadline = 0, lastBootProgress = 0, lastTransferBytes = 0;
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
    const saveKey = saveWriteFailed ? 'saveWriteFailed' : {unknown:'saveUnknown', absent:'saveAbsent', valid:'saveValid', unreadable:'saveUnreadable'}[saveState];
    $('save-status').textContent = copy[saveKey];
    $('continue').disabled = busy || saveState === 'absent';
    $('continue').dataset.saveState = saveState;
    $('control-drive').textContent = copy[window.__EXPEDITION_TOUCH__ ? 'touchTip' : 'driveTip'];
    $('control-observe').hidden = !!window.__EXPEDITION_TOUCH__;
    $('arrival-purpose').textContent = copy[lastAction === 'continue' ? 'resumeStep' : 'firstStep'];
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
    $('start').disabled = false; $('continue').disabled = false;
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
    const decodeFetch = async (resource, options) => {
      const requested = new URL(resource instanceof Request ? resource.url : resource, location.href).href;
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
        onPrintError(...args) { const message = args.join(' '); window.__EXPEDITION_ERRORS__.push(message); console.error(message); }
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
    if (!['new','continue'].includes(action) || busy) return;
    if (fatal) { fail(errorKey, null, true); return; }
    lastAction = action; busy = true; pending = request(action); lastStatus = '';
    resetBootTimings(action);
    bootDeadline = performance.now() + 600000;
    lastBootProgress = Number(window.__EXPEDITION_BOOT_PROGRESS__) || 0;
    lastTransferBytes = 0;
    $('start').disabled = true; $('continue').disabled = true; showLoading();
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
    const completed = window.__EXPEDITION_BOOT_PROGRESS__;
    if (busy && Number.isFinite(completed) && completed > lastBootProgress) {
      lastBootProgress = completed; refreshBootGuard();
    }
    const status = window.__EXPEDITION_BOOT_STATUS__;
    if (!pending || !status || status.version !== 1 || status.requestId !== pending.requestId || fatal) return;
    const signature = `${status.requestId}:${status.stage}:${status.firstFrameReady}:${status.savedAvailable}:${status.saveState}:${status.saveWriteFailed}`;
    if (signature === lastStatus) return;
    lastStatus = signature;
    if (typeof status.savedAvailable === 'boolean') savedAvailable = status.savedAvailable;
    if (['unknown','absent','valid','unreadable'].includes(status.saveState)) saveState = status.saveState;
    else if (typeof status.savedAvailable === 'boolean') saveState = status.savedAvailable ? 'valid' : 'unknown';
    if (typeof status.saveWriteFailed === 'boolean') saveWriteFailed = status.saveWriteFailed;
    // Actual save availability is informative only. Never inspect or clear a slot here.
    $('continue').dataset.savedAvailable = savedAvailable === null ? 'unknown' : String(savedAvailable);
    translate();
    if (['playing','confirm-new'].includes(status.stage)) {
      if (status.firstFrameReady === true && started) finishOnFrame();
      else if (busy) { lastStatus = ''; setProgress(null,'waiting'); }
    } else if (status.stage === 'continue-unavailable') showHome(saveState === 'absent' ? 'saveAbsent' : saveState === 'unreadable' ? 'saveUnreadable' : 'unavailable');
    else if (status.stage === 'home') showHome();
    else if (status.stage === 'error') fail('error');
    else if (busy && ['initializing','validating'].includes(status.stage)) {
      if (status.stage === 'validating' || started) setProgress(null,status.stage === 'validating' ? 'validating' : 'preparing');
    }
  }

  $('start').addEventListener('click',() => launch('new'));
  $('continue').addEventListener('click',() => launch('continue'));
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

