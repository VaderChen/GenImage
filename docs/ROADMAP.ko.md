# 개발 로드맵

[繁體中文](ROADMAP.md) | [English](ROADMAP.en.md) | [日本語](ROADMAP.ja.md) | 한국어

## 완료: Foundation

- Swift Package와 macOS 14 이상 애플리케이션 진입점.
- HTML/CSS/JavaScript 하이브리드 UI.
- JSON Bridge와 로컬 이미지 scheme.
- 텍스트→이미지, 이미지→텍스트, 업스케일의 독립 서비스 인터페이스.
- 프로필 모델, 전환, 복제, revision, 작업 스냅샷.
- 작업 대기열, 작업 흐름 분기, 모델 센터, 이미지 미리보기 UI.
- Core ML Real-ESRGAN 512 타일/4배 업스케일 Runtime과 엔드투엔드 테스트.
- 네이티브 Z-Image Turbo Q4 텍스트→이미지 Runtime, 진행률, 취소.
- 네이티브 Qwen3-VL 4-bit 이미지→텍스트 Runtime과 다국어 설명.
- 텍스트→이미지 출력을 이미지→텍스트 및 업스케일과 연결하는 엔드투엔드 테스트.
- MLX metallib Release 패키징과 네이티브 MCP 추론 도구.
- Core 단위 테스트와 JavaScript 구문 검증.

## 다음 단계: Runtime

1. 이어받기, SHA-256, 디스크 사전 검사, 복구, 삭제를 지원하는 실제 `ModelDownloadManager`를 구현합니다.
2. 애플리케이션 에셋 디렉터리를 만들고 가져온 이미지를 복사하여 임시 파일 권한에 의존하지 않도록 합니다.
3. 작업, 프로필, 프로젝트 상태를 영구 저장합니다.
4. 생성 매개변수, 모델 revision, 출력 이미지 메타데이터를 보존합니다.
5. MLX 모델 언로드 정책과 다중 작업 메모리 조정을 추가합니다.

## 이후: Caption과 Upscale

1. Z-Image, Qwen3-VL, Real-ESRGAN의 라이선스 화면을 완성합니다.
2. 프로필 architecture를 기반으로 확장 가능한 Engine Factory를 구축합니다.
3. 프로필 가져오기/내보내기와 버전 마이그레이션을 추가합니다.

## 출시 전

- 16 GB, 24 GB, 32 GB Apple Silicon에서 메모리 및 발열 부하 테스트.
- 모델 다운로드 중단 및 디스크 공간 부족 테스트.
- App Sandbox, 서명, 공증, 라이선스 화면.
- 작업 취소, 앱 비정상 종료, 재시작 복구.
