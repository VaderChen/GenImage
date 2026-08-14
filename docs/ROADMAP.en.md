# Roadmap

[繁體中文](ROADMAP.md) | English | [日本語](ROADMAP.ja.md) | [한국어](ROADMAP.ko.md)

## Completed: Foundation

- Swift Package and macOS 14+ application entry point.
- Hybrid HTML/CSS/JavaScript UI.
- JSON bridge and local image scheme.
- Independent service interfaces for text-to-image, image-to-text, and upscaling.
- Profile models, switching, duplication, revisions, and operation snapshots.
- Job queue, workflow branches, Model Center, and image preview UI.
- Core ML Real-ESRGAN 512-tile/4× upscaling runtime with end-to-end tests.
- Native Z-Image Turbo Q4 text-to-image runtime with progress and cancellation.
- Native Qwen3-VL 4-bit image-to-text runtime with multilingual descriptions.
- End-to-end chaining tests for text-to-image outputs with image-to-text and upscaling.
- MLX metallib release packaging and native MCP inference tools.
- Core unit tests and JavaScript syntax validation.

## Next: Runtime

1. Implement `ModelDownloadManager` with resume support, SHA-256 verification, disk preflight, repair, and removal.
2. Create an application asset directory and copy imported images to avoid relying on temporary file permissions.
3. Persist jobs, profiles, and project state.
4. Preserve generation parameters, model revisions, and output image metadata.
5. Add MLX model unloading policies and multi-job memory coordination.

## Later: Caption and Upscale

1. Complete license pages for Z-Image, Qwen3-VL, and Real-ESRGAN.
2. Build an extensible engine factory based on profile architecture.
3. Add profile import/export and version migration.

## Before Release

- Memory and thermal stress testing on 16 GB, 24 GB, and 32 GB Apple Silicon systems.
- Interrupted model download and insufficient disk space testing.
- App Sandbox, signing, notarization, and license pages.
- Job cancellation, abnormal app termination, and restart recovery.
