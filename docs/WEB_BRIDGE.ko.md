# Web Bridge

[繁體中文](WEB_BRIDGE.md) | [English](WEB_BRIDGE.en.md) | [日本語](WEB_BRIDGE.ja.md) | 한국어

## 원칙

- JavaScript는 JSON 호환 데이터만 전송합니다.
- 각 명령에는 고유한 request ID와 성공 또는 실패 응답이 있습니다.
- Swift가 실제 상태의 기준이며 상태 변경 후 전체 `WebAppState`를 전송합니다.
- 큰 이미지는 JSON에 포함하지 않고 Web UI가 `genimage-asset://<asset-id>`를 통해 읽습니다.
- `AssetSchemeHandler`는 `AppStore`에 등록된 에셋 URL만 읽을 수 있도록 허용합니다.

## JavaScript 호출

```js
await invoke("generate", { linkToSelectedAsset: false });
```

실제로 전송되는 메시지:

```json
{
  "id": "web-...",
  "method": "generate",
  "params": {
    "linkToSelectedAsset": false
  }
}
```

## 명령

### 작업 공간

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

### 모델

- `installModel`
- `pauseModel`
- `removeModel`
- `repairModel`

### 프로필

- `selectProfile`
- `applyProfileDefaults`
- `createProfile`
- `duplicateProfile`
- `updateProfile`
- `deleteProfile`

## 호환성 전략

현재 `WebAppState.schemaVersion`은 `1`입니다. 새 필드는 하위 호환성을 유지해야 합니다. 호환되지 않는 변경에서는 major schema version을 올려 이전 UI가 잘못된 데이터를 자동으로 사용하지 않도록 합니다.
