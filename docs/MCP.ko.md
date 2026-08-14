# GenImage MCP Server

[繁體中文](MCP.md) | [English](MCP.en.md) | [日本語](MCP.ja.md) | 한국어

GenImage는 프로토콜 버전 `2025-06-18`의 JSON-RPC 2.0 stdio MCP server를 제공합니다.

## 시작

```bash
./build.command
.build/arm64-apple-macosx/release/GenImageMCP
```

정식 연동에서는 `build.command`가 출력한 절대 경로를 사용하세요. `swift build`만 실행하면 metallib이 복사되지 않습니다.

```bash
/absolute/path/to/GenImage/.build/arm64-apple-macosx/release/GenImageMCP
```

## MCP 메서드

- `initialize`
- `notifications/initialized`
- `ping`
- `tools/list`
- `tools/call`

stdio 메시지는 한 줄에 하나의 UTF-8 JSON-RPC 객체입니다. stdout에는 프로토콜 메시지만 출력하고 진단 정보는 stderr에 기록해야 합니다.

## 도구

- `genimage_models_list`
- `genimage_profiles_list`
- `genimage_upscale_image`
- `genimage_generate_image`
- `genimage_describe_image`

텍스트→이미지와 이미지→텍스트는 네이티브 MLX Swift Runtime을 사용합니다. Release 실행 파일 옆에 `mlx.metallib`이 있어야 하며 `build.command`가 자동으로 처리합니다.

모델 루트는 `model_root` 또는 `GENIMAGE_MODEL_ROOT`로 지정할 수 있습니다.

## 설정 예시

컴파일된 실행 파일을 사용하면 MCP Client마다 다른 작업 디렉터리 문제를 피할 수 있습니다.

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

MCP Client는 `build.command`가 생성한 Release 실행 파일을 사용하여 MLX Runtime과 실행 파일이 같은 디렉터리에 있도록 해야 합니다.

## 검증된 동작

- `initialize`와 `tools/list` 스모크 테스트를 통과했습니다.
- 알 수 없는 메서드는 JSON-RPC `-32601`을 반환합니다.
- `genimage_generate_image`는 로컬 Z-Image Turbo Q4를 사용한 256×256, 1-step 엔드투엔드 생성을 완료했습니다.
- `genimage_describe_image`는 로컬 Qwen3-VL 4-bit를 사용한 번체 중국어 이미지 설명을 완료했습니다.
- `genimage_upscale_image`는 로컬 Real-ESRGAN Core ML 모델을 사용한 4배 확대를 완료했습니다.
- 모델 내부 Logger는 stdout에 기록하지 않으므로 stdio는 순수 JSON-RPC를 유지합니다.
