# 本地 main 交接

Nova於2026-09-28明確要求整合到本地main，不是GitHub推送。本次不變更遠端或公開網站。

- 主工作目錄：`C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906`，分支`main`。
- 原實作工作樹：`C:/Users/tsang/DeepSpaceRover/worktrees/visual-upgrade-20260923`，保留來源、作者備份及原始證據。
- 遊戲來源：主工作目錄的`godot/project.godot`；Godot4.7.2 Compatibility single-thread Web。
- 已驗Web版本會同步至主工作目錄的`out/`（本地產物，不加入Git）；啟動方式：`python tools/serve_web.py --port 4234`。若4234已運行，可直接開啟http://127.0.0.1:4234/。
- 最新UI成品：原工作樹`evidence/life-bloom-20260928T160447Z/candidate-bloom-v2/web/`；遊戲PCK SHA256為`6f25e0140d9d90f8535c523544cd085fc1b890a1c76f8755c44c241d2b051d25`。

整合包含環境／水岸、共用模板樹林與石林、生物與材質、舊存檔安全恢復、雙語首頁／加載與生命綻放動畫、必要作者來源及測試工具。`.codex`本機工作者資料、Python cache、Blender自動備份與大量原始runtime證據保留本地。

驗證細節以原工作樹內以下文件為準：
- `evidence/environment-entry-20260928T134859Z/HANDOFF.md`／`TEST_RESULTS.md`：121項原生檢查與同版Web旅程；Low720達標，Standard1080仍未全面達60FPS；畫質／市場驗收PARTIAL。
- `evidence/life-bloom-20260928T160447Z/HANDOFF.md`／`REVIEW.md`：動畫24項檢查、真Web旅程14項及失焦5項PASS，PCK/WASM/素材不變。
- `evidence/push-main-20260928T165224Z/`：本地整合回執、分支與工作目錄保全核對；GitHub只做過唯讀辨識／clone，沒有push。

本文件不重啟舊製作窗口或排程；整合後收尾，後續變更等Nova新指示。
