# Signal in the Dust — 收尾交付

## 開啟遊戲

- Codex Sites：https://signal-in-the-dust-first-contact.danny-eley944.chatgpt.site
- 網站沿用擁有人限定存取。部署版本及來源／產物雜湊以 `evidence/latest-release.json` 為準。
- Godot：開啟 `godot/project.godot`，使用4.7.2 Compatibility。
- 原始Web匯出：`godot/build/web/`；Sites用封裝：`out/`。`npm run dev` 在本機4174提供預覽。

## 操作

WASD／方向鍵駕駛；Space 煞車；V 第一／第三身；右鍵拖曳環視；E 觀察／互動；J 探索日誌；Esc 暫停；R 重新開始（途中需要確認）。Continue 保留進度，New Expedition 建立新旅程。

四區提供冰晶共鳴、Veyra 暖／冷棲地選路、膜葉穿行及根脈導流。濕地兩個場記需先啟動採样、觀察 Aeral 受驚與恢復，再返回盆地驗證。

## 本輪交付

- 已下載且核實CC0的Ground037貼圖正式用於水窪岸邊；含來源及SHA256清單。
- 濕地對照調查、淺水窪、植物回應、schema11遷移及導航對齊。
- 本機與Web實際操作、暫停、重置、途中／完成續玩驗證。
- 保留v14修好的同步Web存檔、備份回復、舊存檔遷移及重置防復活標記。

詳情：`docs/WETLAND_STUDY.md`、`docs/EMBER_THERMAL_ROUTES.md`、`docs/COMBINED_JOURNEY.md`。實際證據保留在 `evidence/`。

## 狀態與限制

這是可玩的私人預覽交付，市場判定為 **PARTIAL**。最近一次整段舊基線是10分33秒；約30分鐘內容未驗收。指定Windows/macOS瀏覽器矩陣、完整效能、三次最終全旅程及獨立真人首次遊玩尚未完成；整體地景精細度與變化仍有改善空間。

按本次收尾指示，成功部署後停用每15分鐘自動續作。未完成項目保留為後續清單，沒有標成市場版本完成。

## 重現與還原

`npm run check`、`npm run test:wetland-study`、`npm run test:wetland-journey -- --graphical`、`npm run test:activity-logic`、`npm run test:save-flow`、`npm run build`。

本輪前基線：來源 `1e845c403b8567f1cb6882f28649897e80fb702c`／私人Sites v14；凍結歷史和本輪before備份均保留。需要還原時應先備份目前來源和存檔，再選用該基線或已保存的Sites v14。較新的schema11存檔不保證可由舊版讀取，勿直接覆寫唯一存檔。
