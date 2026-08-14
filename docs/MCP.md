# GenImage MCP Server

繁體中文 | [English](MCP.en.md) | [日本語](MCP.ja.md) | [한국어](MCP.ko.md)

GenImage 提供 JSON-RPC 2.0 stdio MCP server，協定版本 `2025-06-18`。

## 啟動

```bash
./build.command
.build/arm64-apple-macosx/release/GenImageMCP
```

正式整合請使用 `build.command` 輸出的絕對路徑；單獨執行 `swift build` 不會複製 metallib。

```bash
/absolute/path/to/GenImage/.build/arm64-apple-macosx/release/GenImageMCP
```

## MCP 方法

- `initialize`
- `notifications/initialized`
- `ping`
- `tools/list`
- `tools/call`

stdio 訊息為一行一個 UTF-8 JSON-RPC 物件。stdout 只輸出協定訊息；診斷資訊應寫入 stderr。

## 工具

- `genimage_models_list`
- `genimage_profiles_list`
- `genimage_upscale_image`
- `genimage_generate_image`
- `genimage_describe_image`

文生圖與圖生文使用原生 MLX Swift Runtime；Release 執行檔旁必須有 `mlx.metallib`，`build.command` 會自動處理。

模型根目錄可透過 `model_root` 或 `GENIMAGE_MODEL_ROOT` 指定。

## 設定範例

使用編譯後的執行檔可避免 MCP Client 的工作目錄差異：

```json
{
  "mcpServers": {
    "genimage": {
      "command": "/absolute/path/to/GenImageMCP",
      "env": {
        "GENIMAGE_MODEL_ROOT": "/absolute/path/to/models"
      }
    }
  }
}
```

MCP Client 應使用 `build.command` 產生的 Release 執行檔，確保 MLX Runtime 與執行檔位於同一層。

## 已驗證行為

- `initialize` 與 `tools/list` 煙霧測試通過。
- 未知方法會回傳 JSON-RPC `-32601`。
- `genimage_generate_image` 已使用本機 Z-Image Turbo Q4 完成 256×256、1-step 端到端生成。
- `genimage_describe_image` 已使用本機 Qwen3-VL 4-bit 完成繁體中文圖片描述。
- `genimage_upscale_image` 已使用本機 Real-ESRGAN Core ML 模型完成 4× 放大。
- 模型內部 Logger 不會寫入 stdout，stdio 保持純 JSON-RPC。
