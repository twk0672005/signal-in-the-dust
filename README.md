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
