# GenImage

[繁體中文](README.md) | [English](README.en.md) | [日本語](README.ja.md) | 한국어

GenImage는 **Apple Silicon을 네이티브로 지원**하는 로컬 AI 미디어 생성 앱입니다. 이 프로젝트는 다음 기능을 갖춘 빌드 가능한 하이브리드 애플리케이션을 제공합니다.

- Swift가 모델, 프로필, 작업 대기열, 파일, MLX/Core ML 추론을 관리합니다.
- `WKWebView`에 HTML, CSS, JavaScript UI를 내장하여 네트워크 연결이나 npm 런타임이 필요하지 않습니다.
- 텍스트→이미지, 이미지→텍스트, 이미지→이미지, 텍스트→비디오, 이미지→비디오, 업스케일을 독립적으로 실행하거나 에셋 계보를 통해 연결할 수 있습니다.
- 각 작업은 프로필 스냅샷을 보존하므로 모델이나 아키텍처가 업데이트된 뒤에도 당시 버전을 추적할 수 있습니다.
- 별도의 설정 화면에서 번체 중국어, 영어, 일본어, 한국어와 저장 가능한 6가지 색상 테마를 지원합니다.
- 표준 JSON-RPC 2.0 stdio MCP 서버를 Agent 및 자동화 도구에서 사용할 수 있습니다.

## 실행

요구 사항: macOS 14 이상, Apple Silicon, Xcode 16 이상.

```bash
./build.command
./run.command
```

`build.command`는 Release 실행 파일, 표준 `GenImage.app`, 마운트 가능한 `GenImage-1.0.0-arm64.dmg`를 `dist/`에 생성합니다. DMG에는 Applications 바로가기, WebUI 리소스, MLX Metal 런타임, MCP 서버, 모델 진단 도구가 포함됩니다.

```bash
# 빌드하고 DMG 패키징
./build.command

# DMG 없이 증분 Release 빌드만 실행
./build.command --no-dmg

# 버전과 Bundle ID 지정
GENIMAGE_VERSION=1.1.0 GENIMAGE_BUNDLE_ID=com.example.genimage ./build.command
```

`run.command`는 자동으로 `--no-dmg`를 사용하므로 일반적인 개발 실행에서 디스크 이미지를 반복 생성하지 않습니다. 현재 DMG는 공증되지 않은 로컬 테스트 패키지입니다. 공개 배포 전에는 Developer ID 서명과 Apple 공증이 필요합니다.

### 비디오 Runtime

비디오 생성은 교체 가능한 외부 `ltx-2-mlx` Runtime을 사용합니다. Swift 앱은 프로필, 매개변수 검증, 작업 대기열, 취소, 진행률, 에셋, 비디오 재생을 관리합니다. 처음 사용하기 전에 CLI와 FFmpeg를 설치하세요.

```bash
brew install uv ffmpeg
./scripts/install-ltx-runtime.command
```

앱은 `GENIMAGE_LTX_RUNTIME`, `GENIMAGE_LTX_RUNTIME_ROOT/.venv/bin/ltx-2-mlx`, App Helpers, `~/.local/bin/ltx-2-mlx`, 일반적인 Homebrew 경로, `PATH` 순서로 검색합니다. 실행 파일이 사용자 지정 위치에 있다면 다음과 같이 지정합니다.

```bash
GENIMAGE_LTX_RUNTIME="/absolute/path/to/ltx-2-mlx" ./run.command
```

`ltx-2-mlx`는 기본적으로 Gemma 텍스트 인코더 설정을 사용합니다. 로컬 Gemma 모델이 있다면 `GENIMAGE_LTX_GEMMA_MODEL`에 모델 디렉터리 또는 Hugging Face ID를 지정할 수 있습니다. 현재 앱 DMG에는 Python Runtime, Gemma 가중치, FFmpeg가 포함되지 않습니다. 정식 배포 전에 이를 선택적 외부 구성 요소로 취급하고 Runtime 및 모델 라이선스를 각각 확인해야 합니다.

## 검증

```bash
swift test

for file in Sources/GenImageApp/Resources/WebUI/js/*.js; do
  node --check "$file"
done
```

로컬 모델과 자동 생성된 프로필을 진단합니다.

```bash
swift run GenImageDoctor

# 또는 사용자 지정 모델 디렉터리 지정
GENIMAGE_MODEL_ROOT="/path/to/models" swift run GenImageDoctor
```

표준 MCP stdio 서버를 시작합니다.

```bash
.build/arm64-apple-macosx/release/GenImageMCP
```

MCP는 `initialize`, `ping`, `tools/list`, `tools/call`을 지원합니다. 제공 도구에는 로컬 모델, 프로필, 네이티브 Z-Image 텍스트→이미지 생성, Qwen3-VL 이미지 설명, Core ML 업스케일이 포함됩니다.

MCP 엔드투엔드 검증을 완료했습니다. `genimage_generate_image`는 로컬 Z-Image Turbo Q4 모델로 PNG를 출력하고, `genimage_describe_image`는 Qwen3-VL로 번체 중국어 설명을 생성하며, `genimage_upscale_image`는 로컬 Real-ESRGAN Core ML 모델로 4배 업스케일을 수행합니다.

## 프로젝트 구조

```text
Sources/
├── GenImageCore/
│   ├── DomainModels.swift        # 에셋, 레시피, 작업, 모델, 프로필
│   ├── InferenceServices.swift   # 이미지, 텍스트, 비디오 추론 인터페이스
│   ├── ModelCatalog.swift        # 기본 제공 모델과 프로필
│   └── WorkflowGraph.swift       # 에셋 계보와 분기 관계
├── GenImageRuntime/
│   ├── ZImageTextToImageService.swift
│   ├── QwenVLImageDescriptionService.swift
│   ├── Qwen2511ImageToImageService.swift
│   ├── LTXVideoGenerationService.swift
│   └── CoreMLUpscaleService.swift
└── GenImageApp/
    ├── AppStore.swift            # 애플리케이션 상태와 작업 조정
    ├── HybridBridgeController.swift
    ├── HybridWebView.swift
    ├── AssetSchemeHandler.swift  # 로컬 이미지와 비디오를 WebUI에 안전하게 제공
    └── Resources/WebUI/          # HTML/CSS/JavaScript 프런트엔드
```

## 현재 상태

앱은 Z-Image Turbo 텍스트→이미지, Qwen3-VL 이미지→텍스트, Qwen 2511 이미지→이미지, LTX-2.3 MLX 텍스트→비디오 및 이미지→비디오, Core ML Real-ESRGAN 업스케일의 로컬 추론에 연결되어 있습니다. 비디오 Runtime은 외부 `ltx-2-mlx` CLI를 통해 실행되며, 완료된 MP4는 프로필 스냅샷과 계보를 유지한 에셋으로 작업 공간에 추가됩니다.

모델 센터의 원격 다운로드 기능은 현재 UI 작업 흐름의 기반을 제공합니다. 향후 이어받기 다운로드, 해시 검증, 영구 저장, 전체 App bundle/서명 흐름을 구현할 예정입니다.

추가 정보:

- [아키텍처](docs/ARCHITECTURE.md)
- [Web Bridge](docs/WEB_BRIDGE.md)
- [로드맵](docs/ROADMAP.md)
- [MCP 인터페이스](docs/MCP.md)
- [로컬 모델 테스트 보고서](docs/MODEL_TEST_REPORT.md)

## 라이선스

이 프로젝트는 GPLv3와 상용 라이선스의 이중 라이선스 방식을 사용합니다.

- 오픈 소스 사용은 [GNU General Public License v3.0](LICENSE)에 따라 허가됩니다.
- 비공개 소스 통합, 독점 제품 배포, 맞춤형 상용 조건 등 GPLv3를 준수할 수 없거나 준수하지 않으려는 경우 저작권자에게 별도의 상용 라이선스를 요청하세요.
