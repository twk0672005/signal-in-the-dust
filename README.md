# Signal in the Dust — First Contact

正式遊戲：Godot 4.7.2。開啟 `godot/project.godot`。
唯一工作根目錄：C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906。

目前：市場版本重建中，尚未通過市場驗收或公開發佈。

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
