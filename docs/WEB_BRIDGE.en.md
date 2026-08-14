# Web Bridge

[繁體中文](WEB_BRIDGE.md) | English | [日本語](WEB_BRIDGE.ja.md) | [한국어](WEB_BRIDGE.ko.md)

## Principles

- JavaScript sends only JSON-compatible data.
- Every command has a unique request ID and a success or failure response.
- Swift is the source of truth and pushes a complete `WebAppState` after state changes.
- Large images are not embedded in JSON; the Web UI reads them through `genimage-asset://<asset-id>`.
- `AssetSchemeHandler` permits access only to asset URLs registered in `AppStore`.

## JavaScript Calls

```js
await invoke("generate", { linkToSelectedAsset: false });
```

Actual message:

```json
{
  "id": "web-...",
  "method": "generate",
  "params": {
    "linkToSelectedAsset": false
  }
}
```

## Commands

### Workspace

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

### Models

- `installModel`
- `pauseModel`
- `removeModel`
- `repairModel`

### Profiles

- `selectProfile`
- `applyProfileDefaults`
- `createProfile`
- `duplicateProfile`
- `updateProfile`
- `deleteProfile`

## Compatibility Strategy

The current `WebAppState.schemaVersion` is `1`. New fields must remain backward-compatible. Breaking changes must increment the major schema version so older UIs do not silently consume invalid data.
