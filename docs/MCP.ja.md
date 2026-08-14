# GenImage MCP Server

[繁體中文](MCP.md) | [English](MCP.en.md) | 日本語 | [한국어](MCP.ko.md)

GenImage はプロトコル版 `2025-06-18` の JSON-RPC 2.0 stdio MCP server を提供します。

## 起動

```bash
./build.command
.build/arm64-apple-macosx/release/GenImageMCP
```

正式な連携では `build.command` が出力した絶対パスを使用してください。`swift build` だけを実行しても metallib はコピーされません。

```bash
/absolute/path/to/GenImage/.build/arm64-apple-macosx/release/GenImageMCP
```

## MCP メソッド

- `initialize`
- `notifications/initialized`
- `ping`
- `tools/list`
- `tools/call`

stdio メッセージは 1 行につき 1 つの UTF-8 JSON-RPC オブジェクトです。stdout にはプロトコルメッセージだけを出力し、診断情報は stderr に書き込みます。

## ツール

- `genimage_models_list`
- `genimage_profiles_list`
- `genimage_upscale_image`
- `genimage_generate_image`
- `genimage_describe_image`

テキストから画像と画像からテキストはネイティブ MLX Swift Runtime を使用します。Release 実行ファイルの隣に `mlx.metallib` が必要で、`build.command` が自動的に配置します。

モデルのルートディレクトリは `model_root` または `GENIMAGE_MODEL_ROOT` で指定できます。

## 設定例

コンパイル済み実行ファイルを使用すると、MCP Client ごとの作業ディレクトリの違いを回避できます。

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

MCP Client は `build.command` が生成した Release 実行ファイルを使用し、MLX Runtime と実行ファイルを同じディレクトリに配置してください。

## 検証済みの動作

- `initialize` と `tools/list` のスモークテストに合格しています。
- 未知のメソッドは JSON-RPC `-32601` を返します。
- `genimage_generate_image` はローカル Z-Image Turbo Q4 を使用した 256×256、1-step のエンドツーエンド生成を完了しています。
- `genimage_describe_image` はローカル Qwen3-VL 4-bit を使用した繁体字中国語の画像説明を完了しています。
- `genimage_upscale_image` はローカル Real-ESRGAN Core ML モデルを使用した 4 倍拡大を完了しています。
- モデル内部の Logger は stdout に書き込まず、stdio は純粋な JSON-RPC を維持します。
