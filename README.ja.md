# GenImage

[繁體中文](README.md) | [English](README.en.md) | 日本語 | [한국어](README.ko.md)

GenImage は **Apple Silicon をネイティブサポート**するローカル AI メディア生成アプリです。本プロジェクトは、次の機能を備えたビルド可能なハイブリッドアプリケーションを提供します。

- Swift がモデル、プロファイル、ジョブキュー、ファイル、MLX／Core ML 推論を管理します。
- `WKWebView` に HTML、CSS、JavaScript UI を組み込み、ネットワーク接続や npm ランタイムを必要としません。
- テキストから画像、画像からテキスト、画像から画像、テキストから動画、画像から動画、アップスケールを個別に実行でき、アセットの系譜を通じて連携できます。
- 各操作でプロファイルのスナップショットを保存し、モデルやアーキテクチャの更新後も当時のバージョンを追跡できます。
- 専用の設定画面で繁体字中国語、英語、日本語、韓国語、および永続化可能な 6 種類のカラーテーマを利用できます。
- 標準 JSON-RPC 2.0 stdio MCP サーバーを Agent や自動化ツールから利用できます。

## 実行

要件：macOS 14 以降、Apple Silicon、Xcode 16 以降。

```bash
./build.command
./run.command
```

`build.command` は Release 実行ファイル、標準の `GenImage.app`、およびマウント可能な `GenImage-1.0.0-arm64.dmg` を `dist/` に生成します。DMG には Applications ショートカット、WebUI リソース、MLX Metal ランタイム、MCP サーバー、モデル診断ツールが含まれます。

```bash
# ビルドして DMG を作成
./build.command

# DMG を作成せずに増分 Release ビルドのみ実行
./build.command --no-dmg

# バージョンと Bundle ID を指定
GENIMAGE_VERSION=1.1.0 GENIMAGE_BUNDLE_ID=com.example.genimage ./build.command
```

`run.command` は自動的に `--no-dmg` を使用するため、日常の起動でディスクイメージを繰り返し生成しません。現在の DMG は公証されていないローカルテスト用パッケージです。一般配布には Developer ID 署名と Apple の公証が必要です。

### 動画 Runtime

動画生成には交換可能な外部 `ltx-2-mlx` Runtime を使用します。Swift アプリがプロファイル、パラメータ検証、ジョブキュー、キャンセル、進捗、アセット、動画再生を管理します。初回使用前に CLI と FFmpeg をインストールしてください。

```bash
brew install uv ffmpeg
./scripts/install-ltx-runtime.command
```

アプリは `GENIMAGE_LTX_RUNTIME`、`GENIMAGE_LTX_RUNTIME_ROOT/.venv/bin/ltx-2-mlx`、App Helpers、`~/.local/bin/ltx-2-mlx`、一般的な Homebrew パス、`PATH` の順に検索します。実行ファイルが独自の場所にある場合は、次のように指定します。

```bash
GENIMAGE_LTX_RUNTIME="/absolute/path/to/ltx-2-mlx" ./run.command
```

`ltx-2-mlx` は既定で Gemma テキストエンコーダー設定を使用します。ローカルの Gemma モデルがある場合は、`GENIMAGE_LTX_GEMMA_MODEL` にモデルディレクトリまたは Hugging Face ID を指定できます。現在のアプリ DMG には Python Runtime、Gemma の重み、FFmpeg は含まれていません。正式配布前に、これらを任意の外部コンポーネントとして扱い、Runtime とモデルのライセンスを個別に確認してください。

## 検証

```bash
swift test

for file in Sources/GenImageApp/Resources/WebUI/js/*.js; do
  node --check "$file"
done
```

ローカルモデルと自動生成されたプロファイルを診断します。

```bash
swift run GenImageDoctor

# または独自のモデルディレクトリを指定
GENIMAGE_MODEL_ROOT="/path/to/models" swift run GenImageDoctor
```

標準 MCP stdio サーバーを起動します。

```bash
.build/arm64-apple-macosx/release/GenImageMCP
```

MCP は `initialize`、`ping`、`tools/list`、`tools/call` をサポートします。ツールにはローカルモデル、プロファイル、ネイティブ Z-Image のテキストから画像生成、Qwen3-VL の画像説明、Core ML アップスケールが含まれます。

MCP のエンドツーエンド検証は完了しています。`genimage_generate_image` はローカル Z-Image Turbo Q4 で PNG を出力し、`genimage_describe_image` は Qwen3-VL で繁体字中国語の説明を生成し、`genimage_upscale_image` はローカル Real-ESRGAN Core ML モデルで 4 倍のアップスケールを実行します。

## プロジェクト構成

```text
Sources/
├── GenImageCore/
│   ├── DomainModels.swift        # アセット、レシピ、ジョブ、モデル、プロファイル
│   ├── InferenceServices.swift   # 画像、テキスト、動画の推論インターフェース
│   ├── ModelCatalog.swift        # 組み込みモデルとプロファイル
│   └── WorkflowGraph.swift       # アセットの系譜と分岐関係
├── GenImageRuntime/
│   ├── ZImageTextToImageService.swift
│   ├── QwenVLImageDescriptionService.swift
│   ├── Qwen2511ImageToImageService.swift
│   ├── LTXVideoGenerationService.swift
│   └── CoreMLUpscaleService.swift
└── GenImageApp/
    ├── AppStore.swift            # アプリケーション状態とジョブ調整
    ├── HybridBridgeController.swift
    ├── HybridWebView.swift
    ├── AssetSchemeHandler.swift  # ローカル画像と動画を安全に WebUI へ提供
    └── Resources/WebUI/          # HTML/CSS/JavaScript フロントエンド
```

## 現在の状態

アプリは Z-Image Turbo のテキストから画像、Qwen3-VL の画像からテキスト、Qwen 2511 の画像から画像、LTX-2.3 MLX のテキストから動画／画像から動画、Core ML Real-ESRGAN のアップスケールによるローカル推論に接続済みです。動画 Runtime は外部 `ltx-2-mlx` CLI を通じて実行され、完了した MP4 はプロファイルスナップショットと系譜を保持したアセットとしてワークスペースに追加されます。

モデルセンターのリモートダウンロードは現在 UI ワークフローの基盤を提供しています。今後、再開可能なダウンロード、ハッシュ検証、永続化、完全な App bundle／署名フローを実装する予定です。

詳細情報：

- [アーキテクチャ](docs/ARCHITECTURE.md)
- [Web Bridge](docs/WEB_BRIDGE.md)
- [ロードマップ](docs/ROADMAP.md)
- [MCP インターフェース](docs/MCP.md)
- [ローカルモデルテスト報告](docs/MODEL_TEST_REPORT.md)

## ライセンス

本プロジェクトは GPLv3 と商用ライセンスのデュアルライセンス方式を採用しています。

- オープンソースでの利用は [GNU General Public License v3.0](LICENSE) に基づきます。
- クローズドソースへの統合、プロプライエタリ製品の配布、個別の商用条件など、GPLv3 に準拠できない、または準拠を希望しない場合は、著作権者に連絡して別途商用ライセンスを取得してください。
