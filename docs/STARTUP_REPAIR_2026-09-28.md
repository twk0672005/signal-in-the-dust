# 啟動卡死修復交接

Nova 在公開更新後回報 Chrome「網頁無回應」，並授權團隊診斷與修復。原先的本地限定已由後續 GitHub main／原網址更新要求取代；原六小時窗口、counters 及舊證據保留，不重新起算。

## 來源與候選

- 現役可編輯來源：本 checkout 的 `godot/`，分支 `main`。
- 公開目標：https://twk0672005.github.io/signal-in-the-dust/ ，發佈倉庫 `twk0672005/signal-in-the-dust` 只放 Web 匯出。
- 凍結 Web：`evidence/startup-freeze-20260928T173012Z/candidate-r3/web/`。
- 版本識別：`53395a6554fcc5b4604c57de`；精確檔案與 SHA256 見該目錄 `release-manifest.json`。
- 本地開啟：`python -m http.server 4174 --bind 127.0.0.1 --directory evidence/startup-freeze-20260928T173012Z/candidate-r3/web`，瀏覽 http://127.0.0.1:4174/ 。若埠已有人使用，改用另一個空閒埠；正式 QA 用 `serve_candidate.py` 由作業系統分配埠並核對頁面 SHA256。
- 正式重新匯出使用 `tools/build-review-candidate.py`，destination 必須是本 checkout 內的新目錄。舊 `npm run build` 的 Sites 25 MiB 限制仍會拒絕大型遊戲包，不作 GitHub Pages 的發佈入口。

## 原因與修改

原版在同一瀏覽器工作內建立全世界及首次繪製大量材質。冷啟動重現 62.9 秒 timer gap；第二次診斷中 183 次 WebGL 程式狀態等待合共約 54.3 秒。原先「最後能玩」的煙霧測試未涵蓋啟動回應性。

現在 Web 會明確等待分批世界建立完成，CPU 工作之間交回瀏覽器；逐材質初始化後分開實際場景的顏色與陰影繪製，耗時工作後留出真實 idle 時段。恢復所有物件圖層、陰影、畫質及相機，重新建立完整水岸反射後，才發布第一個可玩畫面。原生測試保留同步建立路徑。

Loader 保留 raw／gzip 串流；初始化拒絕及缺檔會顯示重試頁。逾時依真下載／已完成工作更新，120 秒無進展或總共 600 秒後終止等待。新 HTML、引擎、PCK、WASM、音訊 worklet、CSS／JS 及美術使用同一 `releases/<hash>/`。發佈只按 manifest 複製，保留舊版本與根目錄依賴，讓舊快取頁面仍有相符資源。

## 證據與限制

- 原始證據及精確備份：`evidence/startup-freeze-20260928T173012Z/`。
- 首輪最終候選冷啟動最大 gap 2903.2ms、暖啟動 500.9ms；冷啟動至可互動約 74.7 秒，暖啟動約 15.5 秒。完整 raw gaps 與 LongTasks 保留，未刪除 stall。
- `staged-world-checks.log`：同步／分批世界五項檢查通過，全部 MultiMesh 位置相同；3256 植被實例、198 批、864 碰撞實例及世界統計一致。
- Loader／封裝 11 項、原生啟動契約 12 項及地形／舊存檔 24 項檢查通過；真瀏覽器損壞 WASM／缺 PCK 約四秒顯示錯誤頁。
- 其餘最終有視窗 Chrome、四區旅程、截圖與公開讀回，以同目錄 `FINAL_RECEIPT.json` 及 `verifier/REVIEW.md` 的實際結果為準。
- `r2-startup/` 測量讀到舊共用埠內容，已明確標記 INVALID；有效替代為 `r2-startup-bound/`，不得混用。
- 嚴格 ≤2 秒冷啟動目標仍 PARTIAL：固定 Godot 4.7.2 GLES3 在內部同步初始化同一 shader 的基礎變體，遊戲腳本無法在其中 yield。未修改引擎、降低畫質或宣稱消除此剩餘限制。
- MARKET、Standard1080 全區 60FPS、實機手機及 Safari 驗收仍未完成。

ClawTeam Skill 目前禁止外部模型程序啟動；實際使用兩個原生 Codex WORKER（引擎、loader）及非作者 verifier。沒有冒稱執行 ClawTeam，也沒有安裝新 orchestration。
