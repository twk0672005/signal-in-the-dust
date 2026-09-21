# Signal in the Dust — First Contact

正式遊戲：Godot 4.7.2。開啟 `godot/project.godot`。
唯一工作根目錄：C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906。

目前：按最新指示收尾並交付私人預覽；市場驗收為 PARTIAL。操作、限制及還原方式見 DELIVERY.md。

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
