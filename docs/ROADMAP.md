# 開發路線

繁體中文 | [English](ROADMAP.en.md) | [日本語](ROADMAP.ja.md) | [한국어](ROADMAP.ko.md)

## 已完成：Foundation

- Swift Package 與 macOS 14+ 應用程式入口。
- HTML/CSS/JavaScript 混合式 UI。
- JSON Bridge 與本機圖片 scheme。
- 文生圖、圖生文、Upscale 獨立服務介面。
- Profile 模型、切換、複製、revision 與操作快照。
- 工作佇列、流程分支、模型中心及圖片預覽 UI。
- Core ML Real-ESRGAN 512 tile／4× Upscale Runtime 與端到端測試。
- 原生 Z-Image Turbo Q4 文生圖 Runtime、進度與取消。
- 原生 Qwen3-VL 4-bit 圖生文 Runtime 與多語言描述。
- 文生圖輸出串接圖生文與 Upscale 的端到端測試。
- MLX metallib Release 封裝與原生 MCP 推論工具。
- Core 單元測試與 JavaScript 語法驗證。

## 下一階段：Runtime

1. 建立實際 ModelDownloadManager：續傳、SHA-256、磁碟預檢、修復與刪除。
2. 建立應用程式資產目錄並複製匯入圖片，避免依賴暫時性檔案權限。
3. 將工作、Profile 與專案狀態持久化。
4. 保存生成參數、模型 revision 與輸出圖片中繼資料。
5. 加入 MLX 模型卸載策略與多工作記憶體協調。

## 後續：Caption 與 Upscale

1. 完成 Z-Image、Qwen3-VL 與 Real-ESRGAN 的授權頁面。
2. 依 Profile architecture 建立可擴充 Engine Factory。
3. 加入 Profile 匯入／匯出及版本遷移。

## 發佈前

- 16GB、24GB、32GB Apple Silicon 記憶體與熱壓測試。
- 模型下載中斷與磁碟不足測試。
- App Sandbox、簽章、公證及授權頁面。
- 工作取消、App 異常退出與重啟恢復。
