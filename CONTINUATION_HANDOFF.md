# AURELIA / DeepSpaceRover — 新對話接力

> 建立時間：2026-09-14T15:06:34Z
> 這份檔案是新 Claude Code session 的 bounded handoff；它不代表遊戲已完成、已發布或 market-ready。

## 先讀順序

1. `RUN_CONTRACT.md` — 當前 parent contract、時間窗與 mutation boundary
2. `CHECKPOINT.md` — 歷史 stage receipts、已驗證證據與剩餘 gap
3. `RUN_LOG.md` — 詳細操作紀錄
4. `GAME_CONTRACT.md`、`CREATIVE_BRIEF.md` — AURELIA 產品與視覺真相
5. `tools/runtime-proof.mjs`、`evidence/runtime-proof/report.json` — runtime proof surface
6. 本檔 — 本次 session 的最新接力補充

## 當前產品／技術真相

- 遊戲：AURELIA 深空外星生態探勘；第一身 mini rover；探索、觀察、掃描、記錄；無戰鬥、無操縱 AI 生命。
- Primary engine：Three.js 0.185.1 + JavaScript + Vite + WebGL。
- Browser 是唯一 authoritative delivery surface；desktop first、mobile fallback。
- Deterministic local runtime 擁有 world truth；model/provider 預設停用。
- 四個 habitat：Aurora Shelf、Ember Rift、Mist Basin、Spore Garden；shared dimensional portal 通往 AI Life Castle。
- 已有 localStorage journal/settings persistence、reset 清除 persistence、reload 還原 observed organism、四區 distinct authored response cue、Castle enter/return。
- 最新已證 status：`ROOT_VERIFIED_LOCAL`、`RUNTIME_PROVEN`、local `PERFORMANCE_PROVEN`。
- PM：`PARTIAL`；first-time/art `PARTIAL`，product/market `FAIL`，presentation `SKELETON`。
- 不可宣稱：market-ready、released、deployed、public demo、autonomous AI life、independent audience validation。

## 最新停止點與 blocker

Nova 叫停後，尚未開始新一輪產品修改。最近 bounded investigation 發現：

- `npm run check` 已 PASS。
- `node tools/runtime-proof-harness.test.mjs` 已 PASS。
- 一次 `RUNTIME_PROOF_DISABLE_GPU=0 npm run runtime:proof` 在 fresh Chrome/CDP 啟動時失敗：
  `window.__GAME did not become ready`，page 長時間保持 `interactive`，`window.__GAME` 為 `undefined`。
- 已有臨時診斷 marker 仍需清理：`src/main.js` 的 `window.__AURELIA_BOOT`。
- `tools/runtime-proof.mjs` 的 readiness probe 仍有臨時 debug verbosity；完成 root-cause probe 後應收斂。
- 尚未取得該次 session 的 fresh P3 full adverse PASS，因此不要寫 P3 success receipt。
- 可先用 bounded probe 比較 Vite dev server 與已完成 build 後的 `vite preview`；若 preview 穩定 boot，才考慮將 proof delivery 改為 build artifact。不得以 workaround 假造 runtime evidence。

## 下一個正確 stage 順序

1. **先確認 Blender MCP 可用及 asset provenance boundary**，不要直接改遊戲 body。
2. 讀取 Blender 場景摘要；確認 bridge／addon／MCP tool 實際可呼叫。
3. 若要建立 `.blend`／`.glb`，只建立可驗證的 Blender-authored asset，記錄 source、version、provenance、license 與 runtime budget；不得把 procedural Three.js geometry 假稱 Blender-authored。
4. 清理 `window.__AURELIA_BOOT` 及臨時 probe（只有在不再需要 diagnosis 後）。
5. 修復或重新界定 Chrome/CDP/Vite readiness boundary；重跑：
   - `npm run check`
   - `node tools/runtime-proof-harness.test.mjs`
   - `RUNTIME_PROOF_DISABLE_GPU=0 npm run runtime:proof`
6. fresh P3 PASS 後，才更新 `RUN_LOG.md`／`CHECKPOINT.md`。
7. 再做 P4 visual/performance regression，優先處理最大 user-visible gap：
   - 四區 near/mid/far authored ecological material density
   - creature animation/consequence quality
   - mobile HUD／rover framing
   - representative GPU performance
8. 最後做 proxy PM review；沒有 independent audience validation 仍維持 `PM PARTIAL`。

## Blender MCP（Nova 於 2026-09-14 提供並已驗證）

- Blender 5.2.1 LTS：
  `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`
- 官方 repo：
  `C:\Users\tsang\Tools\blender-mcp`
- repo commit：`ff54e4d8f6b09502f2f466189cca0e52b4a91643`
- bridge：`127.0.0.1:9876`
- Claude Code user-scope MCP command：
  `uv run --directory C:/Users/tsang/Tools/blender-mcp/mcp blender-mcp`
- `claude mcp list`：`blender ✔ Connected`
- 已實際 MCP 呼叫取得 Blender scene summary，`MCP_CALL_ERROR False`。
- Blender Online Access 已持久啟用；普通啟動會自動啟動 bridge。
- 新 session 需重新啟動 Claude Code，才會載入 Blender MCP tools。
- 以上是 Nova 提供的安裝／驗證 receipt；新 session 仍應做一次 read-only MCP health check，不能只因文字 receipt 宣稱已可操作。

## 安全與範圍（不得放寬）

- 不執行第三方 repository 未檢查的 installer、plugin、add-on、下載 script 或未知程式碼。
- 不依賴付費外部 asset provider。
- 不做 deploy、publish、secrets 或公開網絡暴露。
- Never expose secrets, tokens, credentials, private keys, or private environment values.
- Never commit secrets or generated files that may contain secrets.
- If a secret leak or credential exposure is suspected, stop and ask Nova before continuing.
- Mutation boundary：`project-local source、tests、evidence、and contract artifacts only; no secrets, paid providers, external publishing, deploy, or public network exposure`。
- Blender MCP 可用不等於授權 deploy、publish、payment、account traffic 或 secrets。

## 新對話開場句

```text
繼續 AURELIA DeepSpaceRover。先讀 CONTINUATION_HANDOFF.md、RUN_CONTRACT.md、CHECKPOINT.md；做 Blender MCP read-only health check，然後按 handoff 的 P3 blocker 和 asset provenance boundary 繼續。不要宣稱 market-ready 或 released。
```
