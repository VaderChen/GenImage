# GenImage Architecture

[繁體中文](ARCHITECTURE.md) | English | [日本語](ARCHITECTURE.ja.md) | [한국어](ARCHITECTURE.ko.md)

## Design Goals

1. Text-to-image, image-to-text, image-to-image, video generation, and upscaling are independent capabilities with no mutual dependency.
2. Image and video outputs can form workflows and branches.
3. The UI does not directly depend on MLX, Core ML, or any specific model.
4. Model versions and inference architectures are switched through profiles when models are updated.
5. Existing works preserve profile snapshots and are unaffected by later profile changes.

## Layers

```text
HTML / CSS / JavaScript UI
            │
            │ JSON commands + state snapshots
            ▼
HybridBridgeController (WKWebView Bridge)
            │
            ▼
AppStore / Workflow coordination
            │
            ├── Model manager
            ├── Asset repository
            ├── Job queue
            └── Profile registry
                    │
                    ▼
        Independent inference services
        ├── TextToImageGenerating
        ├── ImageDescribing
        ├── ImageToImageGenerating
        ├── VideoGenerating
        └── ImageUpscaling
                    │
                    ▼
       MLX Swift / Core ML / External CLI
```

The Web UI can access local capabilities only through the bridge. It cannot directly read arbitrary files, model directories, or system APIs.

## Profiles

`InferenceProfile` contains:

- Capability type.
- Model ID.
- Model revision.
- Inference architecture: MLX Swift, Core ML, local service, or external CLI.
- Capability defaults.
- Profile revision.

When a job runs, `WorkflowOperation.profileSnapshot` stores the complete value instead of only the profile ID.

Built-in profiles are not modified directly. Users duplicate a profile before saving changes as a new revision.

## Assets and Workflows

`ImageAsset.parentAssetID` identifies the source asset. Assets without a parent are root nodes of independent jobs:

- Standalone text-to-image: the generated image has no parent.
- Standalone image-to-text: a root image is imported first, and the description output is written to the recipe.
- Standalone upscale: a root image is imported first, and the upscaled result uses the original image as its parent.
- Chained generation: the generated result uses the selected image as its parent.
- Standalone text-to-video: the MP4 asset has no parent.
- Image-to-video: the MP4 asset uses the source image as its parent.

`WorkflowGraph` provides lineage and children queries, so the UI does not need to infer asset relationships.

## Inference Runtimes

Text-to-image uses `Z-Image.swift` commit `28bfcf3148c041a554629247170eb54d9ac46830`:

- macOS 14+ and Swift 6.
- `ZImageGenerationRequest` supports prompts, negative prompts, dimensions, steps, seeds, models, and runtime options.
- `ZImageTextToImageService` wraps `ZImagePipeline.generate` and reports progress by stage.
- The denoising loop checks Swift task cancellation.
- Model unloading, LoRA unloading, cancellation, and memory cache cleanup are supported.

Image-to-text uses `mlx-swift-lm 2.30.6`:

- `QwenVLImageDescriptionService` loads local Qwen3-VL models through `VLMModelFactory`.
- The model container is cached for the lifetime of the service to avoid reloading the same profile.
- Output prompts support Traditional Chinese, English, Japanese, and Korean.

Upscaling is handled by `CoreMLUpscaleService` with Real-ESRGAN 512 tiles and 4× stitching.

Video generation is handled by `LTXVideoGenerationService`, which invokes `ltx-2-mlx generate`:

- Text-to-video and image-to-video share `VideoGenerating` and `VideoGenerationRequest`.
- Swift validates the profile, model path, dimensions, frame count, FPS, and output count.
- LTX-2.3 additionally requires frame counts in the form `8n+1`.
- The external process supports task cancellation, log-based error reporting, and percentage progress extraction.
- MP4 outputs are added to the workspace as `generatedVideo` assets and played with the native Web UI `<video>` element.
- The runtime can be replaced through `GENIMAGE_LTX_RUNTIME` or standard installation locations without coupling the Python implementation to the UI or `AppStore`.

The MLX metallib is copied from `RuntimeSupport/mlx.metallib` into the release executable directory by `build.command`. Before distribution, model license review, 16/24/32 GB stress testing, app bundling, signing, and notarization still need to be completed.
