# Web Bridge

## 原則

- JavaScript 只傳送 JSON 相容資料。
- 每個命令都有唯一 request ID 及成功／失敗回覆。
- Swift 是真實狀態來源，狀態改變後推送完整 `WebAppState`。
- 大型圖片不放進 JSON；Web UI 使用 `genimage-asset://<asset-id>` 讀取。
- `AssetSchemeHandler` 只允許讀取 AppStore 已登記的資產 URL。

## JavaScript 呼叫

```js
await invoke("generate", { linkToSelectedAsset: false });
```

實際送出的訊息：

```json
{
  "id": "web-...",
  "method": "generate",
  "params": {
    "linkToSelectedAsset": false
  }
}
```

## 命令

### 工作區

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

### 模型

- `installModel`
- `pauseModel`
- `removeModel`
- `repairModel`

### Profile

- `selectProfile`
- `applyProfileDefaults`
- `createProfile`
- `duplicateProfile`
- `updateProfile`
- `deleteProfile`

## 相容性策略

目前 `WebAppState.schemaVersion` 為 `1`。新增欄位必須保持向後相容；破壞性變更則提高 major schema version，避免舊 UI 靜默使用錯誤資料。
