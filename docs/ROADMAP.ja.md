# 開発ロードマップ

[繁體中文](ROADMAP.md) | [English](ROADMAP.en.md) | 日本語 | [한국어](ROADMAP.ko.md)

## 完了：Foundation

- Swift Package と macOS 14 以降のアプリケーションエントリポイント。
- HTML／CSS／JavaScript ハイブリッド UI。
- JSON Bridge とローカル画像 scheme。
- テキストから画像、画像からテキスト、アップスケールの独立サービスインターフェース。
- プロファイルモデル、切り替え、複製、revision、操作スナップショット。
- ジョブキュー、ワークフロー分岐、モデルセンター、画像プレビュー UI。
- Core ML Real-ESRGAN 512 タイル／4 倍アップスケール Runtime とエンドツーエンドテスト。
- ネイティブ Z-Image Turbo Q4 テキストから画像 Runtime、進捗、キャンセル。
- ネイティブ Qwen3-VL 4-bit 画像からテキスト Runtime と多言語説明。
- テキストから画像の出力を画像からテキストおよびアップスケールへ連携するエンドツーエンドテスト。
- MLX metallib の Release パッケージ化とネイティブ MCP 推論ツール。
- Core 単体テストと JavaScript 構文検証。

## 次の段階：Runtime

1. 再開、SHA-256、ディスク事前確認、修復、削除を備えた実用的な `ModelDownloadManager` を実装します。
2. アプリケーションのアセットディレクトリを作成して読み込み画像をコピーし、一時ファイルの権限への依存をなくします。
3. ジョブ、プロファイル、プロジェクト状態を永続化します。
4. 生成パラメータ、モデル revision、出力画像メタデータを保存します。
5. MLX モデルのアンロード方針と複数ジョブのメモリ調整を追加します。

## 今後：Caption と Upscale

1. Z-Image、Qwen3-VL、Real-ESRGAN のライセンス画面を完成させます。
2. プロファイルの architecture に基づく拡張可能な Engine Factory を構築します。
3. プロファイルのインポート／エクスポートとバージョン移行を追加します。

## リリース前

- 16 GB、24 GB、32 GB Apple Silicon でのメモリおよび熱負荷試験。
- モデルダウンロード中断とディスク容量不足のテスト。
- App Sandbox、署名、公証、ライセンス画面。
- ジョブのキャンセル、アプリの異常終了、再起動時の復元。
