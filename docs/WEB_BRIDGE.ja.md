# Web Bridge

[繁體中文](WEB_BRIDGE.md) | [English](WEB_BRIDGE.en.md) | 日本語 | [한국어](WEB_BRIDGE.ko.md)

## 原則

- JavaScript は JSON 互換データのみを送信します。
- 各コマンドには一意の request ID と成功／失敗の応答があります。
- Swift を正しい状態の唯一の情報源とし、状態変更後に完全な `WebAppState` を送信します。
- 大きな画像は JSON に含めず、Web UI が `genimage-asset://<asset-id>` を通じて読み込みます。
- `AssetSchemeHandler` は `AppStore` に登録されたアセット URL の読み込みだけを許可します。

## JavaScript 呼び出し

```js
await invoke("generate", { linkToSelectedAsset: false });
```

実際に送信されるメッセージ：

```json
{
  "id": "web-...",
  "method": "generate",
  "params": {
    "linkToSelectedAsset": false
  }
}
```

## コマンド

### ワークスペース

- `bootstrap`
- `selectAsset`
- `updateRecipe`
- `randomizeSeed`
- `generate`
- `describe`
- `upscale`
- `importImage`
- `cancelJob`
- `clearJobs`

### モデル

- `installModel`
- `pauseModel`
- `removeModel`
- `repairModel`

### プロファイル

- `selectProfile`
- `applyProfileDefaults`
- `createProfile`
- `duplicateProfile`
- `updateProfile`
- `deleteProfile`

## 互換性方針

現在の `WebAppState.schemaVersion` は `1` です。新しいフィールドは後方互換性を維持する必要があります。破壊的変更では major schema version を上げ、古い UI が誤ったデータを暗黙に使用しないようにします。
