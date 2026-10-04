## E 首次聯絡更新已上線 — 2026-10-04

[開啟最新公開遊戲](https://twk0672005.github.io/signal-in-the-dust/?v=9515f0fa92616a04840eb938) · [發布與驗收紀錄](docs/E_CONTACT_RELEASE_2026-10-04.md)

E 更新已推到網站 main：六秒确认、日誌發現、保留根脈回應、三秒回覆脈衝。公開桌面／觸控共 32 項操作通過，25 個公開檔與兩份版本資料匹配。冷載入本輪約 56–62 秒，20–30 秒目標仍未過；美術維持 PARTIAL。下方本地／舊發布狀態為歷史紀錄。

## 已發布世界樹 v6 — 2026-10-04

[開啟最新公開遊戲](https://twk0672005.github.io/signal-in-the-dust/?v=bedf501e10b0277026060294) · [發布與實測紀錄](docs/RELEASE_2026-10-04.md)

已依 Nova 最新收尾／GitHub push 要求更新 Pages main。公開版 56 項入口、駕駛、保存、雙語及觸控模擬檢查通過；四區至世界樹的 E 互動與結局通過。此次公開 Chrome 冷載入：按開始至可駕駛 22.6 秒，開頁至可駕駛 24.8 秒。美術還原度仍 PARTIAL，發布不等同 Valley 或參考圖品質驗收。舊版本、失敗證據與未提交 WIP 保留；下方各日期皆為歷史紀錄。

## 已接受並發布 — 2026-10-03 核對完成

Nova已對本版給予PASS並授權兩邊main。本地來源main與獨立GitHub Web main已更新；
[公開遊戲](https://twk0672005.github.io/signal-in-the-dust/?v=0a1c861367c02356a40353c7)
使用你已接受的遊戲內容，分檔重組後PCK完全相同。GitHub提交9cccf30472987676dba5997766d9ebd005960da1，
發布版本0a1c861367c02356a40353c7，遊戲來源提交936fd1fef22829e551b832716cf5efe1634456d1。
Pages建置成功、23個公開檔案雜湊一致，公開Chrome的32項入口／駕駛／存檔檢查通過。
[發布紀錄](docs/RELEASE_2026-10-01.md)。原量測及舊版本保留；下方未發布／PARTIAL為各歷史階段記錄。
本次冷啟動重驗約164.7秒、最大停頓約14秒，回應速度門檻仍未過；NOVA版本接受與實測分開記錄。

## 最新本地候選 — 2026-10-01 六小時交付

[開啟遊戲](http://127.0.0.1:51860/) · [完整交付與驗證](evidence/alien-renewal-20260930T200644Z/HANDOFF.md)。固定版本7830ff00616c4e124b3b6440；可玩、美術與入口已整合，整體 Valley／60FPS／冷啟動門檻仍 PARTIAL，未發布。本段覆蓋下方歷史的 current/latest/預覽埠；舊工作、版本與證據保留。

# Signal in the Dust — First Contact

## Latest local Blender material candidate — 2026-09-29

[Play locally](http://127.0.0.1:52372/) · [Blender source, skill installation, actual Web comparison and limits](docs/BLENDER_LOOKDEV_2026-09-29.md). Includes the entry redesign below. Rock/ground improvements are locally verified; overall visual target remains PARTIAL. This candidate has not been committed or published.

## Latest local entry redesign — 2026-09-29

The welcome now asks “準備好開始你的旅程了嗎？” with one Start action. Continue has been removed as requested; in-session pause/resume remains. [Local preview](http://127.0.0.1:58047/) · [Changes, actual Web checks and publication status](docs/ENTRY_REDESIGN_2026-09-29.md). This local redesign has not yet replaced the GitHub release below.

## Published main — 2026-09-29

Nova's explicit local/GitHub main instruction has been completed for the existing public preview.
Game source commit: `4f727820451e51da7dd2d50021f6049c0caafd03` on local `main`.
Separate Web-export GitHub main: `46aa6dfa675569fe4450c8da71cd5516b4698af0`.
Play: https://twk0672005.github.io/signal-in-the-dust/?v=af58aba5d001b1a262549d19
Pages reports built for that commit; all 13 game files plus 3 publication metadata files match by SHA-256.
Local `out/` holds the same release; run `python tools/serve_web.py --port 4234`.
592 authored Godot files matched the frozen candidate before integration; 396 preexisting import files remain unchanged and uncommitted. Old public release dependencies remain intact.
Publication receipt and public Chrome smoke: `evidence/push-main-20260929/FINAL_RECEIPT.json`.
This publication supersedes the historical no-commit/no-push notes below. Visual/performance acceptance remains PARTIAL; publishing does not close the outstanding phone/Safari, long-duration, sustained60FPS or visual-quality gates.

## Main publication — 2026-09-29

Nova explicitly authorized local main and the existing GitHub main/Pages publication.
This supersedes earlier no-commit/no-push wording below, which is historical.
Publish the byte-verified candidate-reviewed release `af58aba5d001b1a262549d19`;
source stays in this local repository and Web exports stay in `twk0672005/signal-in-the-dust`.
Publication results: `evidence/push-main-20260929/FINAL_RECEIPT.json`.
The visual/performance verdict remains PARTIAL. Prior import WIP and cached release assets are preserved.

## 最新本地候選：畫面、玩法與入口更新 — 2026-09-28

現役來源仍是本 checkout 的 `godot/`，工作分支 `codex/visual-gameplay-20260928`。
本輪已實作四區地形／棲地／表面、互動與日誌、安靜研究、C慢行及真實Start／Continue狀態。
本地候選：[開啟遊戲](http://127.0.0.1:58827/)。[完整交付、重開命令、來源、前後圖及驗證](docs/VISUAL_GAMEPLAY_HANDOFF_2026-09-28.md)。
整體驗收 **PARTIAL**：功能／保存有實測，嚴格冷啟動≤2秒、Standard1080持續60FPS及完整視覺目標尚未全達。Nova最終畫質、實機手機／Safari、長時記憶體與30分鐘內容未驗。
本輪未commit／push／公開發布；下方舊網址、工作樹和發布記錄均為歷史，不覆蓋本段。

## 最新啟動卡死修復 — 2026-09-28

Nova 已追加授權更新原 GitHub Pages 網站，並要求修復 Chrome「網頁無回應」。現役來源是本目錄的 `main`；網站為 https://twk0672005.github.io/signal-in-the-dust/ 。來源、修復前後原始量測、候選及發佈狀態見 [啟動修復交接](docs/STARTUP_REPAIR_2026-09-28.md)。下方「只做本地」及舊預覽位址均為歷史記錄，不覆蓋最新要求。

修復把世界建立與材質首次繪製分批，保留全部場景、碰撞及存檔；Web 每次匯出產生整套不可變版本路徑，避免新介面混用舊遊戲包。冷啟動仍需下載及編譯，嚴格每次停頓 ≤2 秒與市場畫質目標尚未全部達標。

## 歷史：本地 main 收尾

本次依Nova更正，整合到**本地 main**，不推送GitHub。主工作目錄為 `C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906`；本機Web產物放在該目錄的`out/`，可用 `python tools/serve_web.py --port 4234` 開啟。原實作工作樹及所有原始證據保留。[本地 main 交接](docs/LOCAL_MAIN_HANDOFF_2026-09-28.md)說明來源、驗證範圍及已知限制；下方歷史證據路徑均以原實作工作樹為基準。

## 最新UI — 生命的綻放

本地 **http://127.0.0.1:4234/** 已套用「生命的綻放」加載動畫：微光萌發、半透明膜瓣展開、孢光飄散。保留手動暫停、靜態替代、真進度與重試，完成動態及真Web操作檢查。來源與備份／影片／獨立覆核見 [動畫交接](evidence/life-bloom-20260928T160447Z/HANDOFF.md)。本次只改HTML/CSS/JS；PCK、WASM與遊戲資產雜湊不變。

目前Web候選為 `evidence/life-bloom-20260928T160447Z/candidate-bloom-v2/web`；重啟命令：`python evidence/life-bloom-20260928T160447Z/PLAY_LOCAL.py`。下方是遊戲本體的凍結基準和歷史驗證，不代表這次重新測量整個遊戲的性能。

## 遊戲本體基準 — 2026-09-28 環境／入口更新

Nova 已要求收尾；不再擴展內容。最新候選是 `evidence/environment-entry-20260928T134859Z/candidate-r4/web`，本地入口 **http://127.0.0.1:4234/**。啟動：`python evidence/environment-entry-20260928T134859Z/PLAY_LOCAL.py`。可編輯來源仍在 `godot/`，同版凍結來源在該候選的 `candidate-project/godot/`。

本輪加入分層圖像遠景、不對稱水岸與根堤、共用模板批量樹林／石林，以及雙語入口／加載美術。3256個植群實例以198批渲染，864碰撞實例共用39個碰撞區塊。實際畫面仍須與已接受概念目標區分，沒有市場／發布完成聲明。

本輪證據與最新驗證狀態見 [交接](evidence/environment-entry-20260928T134859Z/HANDOFF.md)、[收尾測試原始狀態](evidence/environment-entry-20260928T134859Z/CLOSEOUT_QA.json) 及 [技能修訂](evidence/environment-entry-20260928T134859Z/SKILL_REVIEW.md)。以下各日期內容是歷史記錄，其 current／latest／預覽埠不覆蓋本段；舊時間窗口與 counters 保留，不自動啟動任何工作或排程。

現役遊戲：**Godot 4.7.2＋GDScript＋Compatibility＋single-thread Web**，開啟 `godot/project.godot`。Three.js 僅為歷史基線。

- **實作根**：`C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923`
- **正式規格根**：`C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906`
- branch：`codex/veil-marsh-visual-upgrade`。保留 dirty／untracked WIP；不要 reset、stash、clean 或清空重建。

## Codex 本輪現況（2026-09-27 中斷收尾）

原六小時窗口已於02:16:58UTC屆滿，狀態 **WINDOW_EXPIRED_PARTIAL**；沒有在中斷期間持續背景製作。最新接手入口：[本輪完整交接](evidence/codex-six-hour-20260926T201658Z/HANDOFF.md)。此段覆蓋下方舊交接的 current／latest 措辭。

目前本地預覽：[Codex 畫質候選 r1](http://127.0.0.1:4234/)，來源與Web凍結於 evidence/codex-six-hour-20260926T201658Z/integrated-r1/。已驗20個Web視角、固定條件材質A/B及8組原生回歸；**未完成同版Web旅程／觸控／性能／影片／獨立驗收**。更新的 integrated-r2 已匯出，尚未做Web驗證。最後完整Web功能回歸證據仍屬下方歷史Claude r1。

新水岸、群落與生物材質已實作；最終畫質未獲Nova驗收。兩個WORKER已交回ownership，所有WIP、精確備份、失敗回執及原時間／counters均保留。預覽PID、重新開啟命令與全部限制見本輪交接。追加製作窗口尚待Nova確認；不commit／push／deploy。
## Codex／Claude Code 接手入口（2026-09-26 收尾）

1. 先讀 [最新現況交接](evidence/world-upgrade-20260926/CODEX_HANDOFF_FROM_CLAUDE.md)：來源、ownership、已驗／未驗、畫質缺口、本地開啟命令、備份與 hashes。
2. 新一輪執行可使用 [Codex／GPT-6 Astra 六小時提示詞](evidence/world-upgrade-20260926/CODEX_GPT6_ASTRA_SIX_HOUR_PROMPT.md)，已合併 Nova 最新要求並修正舊候選路徑。只有接手者收到 Nova 直接執行指示並開始實際工作時才啟動新計時；不改写舊 run。
3. 再按交接讀 `AGENTS.md`、`GAME_CONTRACT.md`、正式規格與原始交接。**Claude 本輪已按要求停止施工，不會在背景繼續；完整畫質／市場驗收仍為 PARTIAL，等待 Nova。**

最後已做 Web 功能驗證的完整候選：
`evidence/world-upgrade-20260926/claude-integrated-r1/web/`。

- 同版真四區旅程、三種生物觀察、控制／pause／reload／Continue及桌面模擬觸控重測 PASS；native 8 suites／232 assertions PASS。
- focus-loss 仍 PARTIAL；17固定視圖與18姿態 samples 不等於畫質驗收或自由操作影片。
- 已量測的8段性能屬於較舊 baseline，且到區後停車採樣；不是 r1 或行進／互動負載驗收。
- **live `main.gd`／`showcase.js` 多出尚未做 Godot／Web 驗證的啟動儀表；上述 r1 PASS 不覆蓋此兩檔。**
- 材質 A/B、水岸／棲地完整度、同版兩品質行進性能、冷暖啟動／記憶體趨勢、自由操作影片和 fresh reviewer 尚未完成。

自建4230／4231預覽 servers 已停止；交接檔提供可重新啟動的精確命令，不能假設 URL 還活著。只做本地工作：**不 commit／push／deploy、不讀 secrets、不改全域設定、不付費生成**。`DELIVERY.md` 及舊文件中的發布狀態僅為歷史，不能取代本輪限制。

## 建置與本機測試
`npm run check`：Godot 語法檢查。
`npm run build`：配對引擎匯出 release Web 到 godot/build/web，封裝到 out。
`npm run dev`：開啟 http://127.0.0.1:4174，支援預壓縮 WASM。
GODOT_BIN 可指定相同版本的引擎可執行檔；默认使用本機已驗證版本。
原始 Web 包可由一般靜態主機提供；out 使用 gzip WASM，需 Content-Encoding: gzip。

## 保存與路線
legacy/aurelia-threejs 保存先前 AURELIA；legacy/signal-in-the-dust 保存 Claude 第一身交付基線。
歷史內容不能作為新市場版本的 runtime 證據。
PLANS.md、RUN_CONTRACT.md、CHECKPOINT.md 記錄本輪狀態。

## 冰晶共鳴（可選活動）

在極光高原左側找到三組編號冰晶，先按 E 記錄旁邊的高原回波，再按 E 聆聽。
用 1／2／3 回應亮起的順序；答錯會重播同一段，E 亦可重聽。
完成三段後晶簇會展開，Continue 會保留完成結果。Esc 暫停；V 切换視角；離開晶簇會重新開始未完成的挑戰。

這是一項新增短活動，並不代表整體已達 30 分鐘。驗證及授權見 docs/AURORA_RESONANCE.md。

## Veyra 安靜穿越（可選護送）

完成熱泉裂谷的主線測繪及 Veyra 觀察後，停車面向第一隻 Veyra，按 E 開始陪伴。
保持 4–24 米距離，車速低於 8 米／秒；太吵或太近時，先停車並留出空間。
走遠了牠會等你。Pause／Continue 支援護送途中的位置和進度，抵達庇護處後礦床會亮起暖光。
詳見 docs/VEYRA_CROSSING.md；整體仍未完成30分鐘市場驗收。

## 探索日誌與礦脈選路

J 開啟四區日誌，可追蹤已到訪地區的活動，或切回主線調查。
熱泉裂谷可選原有暖床護送，或先觀察東側熱泉噴發、按 E 切換冷礦脈路線，再返回 Veyra。
護送開始後路線鎖定，兩種棲地結果均可續玩。詳見 docs/EMBER_THERMAL_ROUTES.md。
Web 存檔保留在本瀏覽器，舊版進度自動遷移；儲存故障會顯示提示並保留可讀的舊進度。

## 濕地反應對照

先在膜葉場記點啟動採樣，親自觀察並按 E 記錄 Aeral 受驚與恢復，再到濕地盆地場記點驗證。完成後水窪岸邊植物會展開；舊版已完成的場記會保留。
