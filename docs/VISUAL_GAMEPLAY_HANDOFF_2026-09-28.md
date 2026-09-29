# 畫面、玩法與入口：本地候選接手入口

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

現役可編輯根：`C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906`。
分支 `codex/visual-gameplay-20260928`；本輪未commit／push／發布，原main基準保留。

本地遊戲：[http://127.0.0.1:58827/](http://127.0.0.1:58827/)。
凍結候選為 `evidence/visual-gameplay-build-20260928T193707Z/candidate-reviewed`，
release `af58aba5d001b1a262549d19`。停止服務後用該run的 `PLAY_LOCAL.py` 重開，
使用新印出的OS分配埠；不要假定舊埠永久存活。

請讀 [完整交付與證據](../evidence/visual-gameplay-build-20260928T193707Z/HANDOFF.md)、
[總收據](../evidence/visual-gameplay-build-20260928T193707Z/FINAL_RECEIPT.json)及
[更新計劃](VISUAL_GAMEPLAY_UPDATE_PLAN_2026-09-28.md)。

實作與可玩候選已存在，整體嚴格驗收仍 **PARTIAL**。主要功能、保存與真Web旅程
有證據；冷啟動≤2秒、Standard1080持續60FPS及完整視覺品質目標尚未全達。
新對話不可把上一輪「只評估未實作」、已結束時間窗口或舊工作樹當成現役狀態，
也不可把本地候選當作自動公開發布、帳戶、provider或排程授權。
