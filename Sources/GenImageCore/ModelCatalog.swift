import Foundation

public enum ModelCatalog {
    public static let builtIn: [ModelDescriptor] = [
        ModelDescriptor(
            id: "mzbac/z-image-turbo-8bit",
            displayName: "Z-Image Turbo 8-bit",
            publisher: "mzbac / Tongyi-MAI",
            summary: "適合一般 Apple Silicon Mac 的量化文生圖版本。",
            capabilities: [.textToImage],
            quantization: .eightBit,
            approximateDownloadGB: 12.3,
            recommendedMemoryGB: 16,
            licenseName: "Apache-2.0",
            sourceURL: URL(string: "https://huggingface.co/mzbac/z-image-turbo-8bit"),
            isRecommended: true
        ),
        ModelDescriptor(
            id: "Tongyi-MAI/Z-Image-Turbo",
            displayName: "Z-Image Turbo 原始版",
            publisher: "Tongyi-MAI",
            summary: "官方原始權重，適合記憶體較大的 Apple Silicon Mac。",
            capabilities: [.textToImage, .controlNet],
            quantization: .fp16,
            approximateDownloadGB: 30.6,
            recommendedMemoryGB: 32,
            licenseName: "Apache-2.0",
            sourceURL: URL(string: "https://huggingface.co/Tongyi-MAI/Z-Image-Turbo")
        ),
        ModelDescriptor(
            id: "tarn59/pixel_art_style_lora_z_image_turbo",
            displayName: "Z-Image Turbo Pixel Art LoRA",
            publisher: "tarn59",
            summary: "可直接搭配 Z-Image Turbo 使用的像素藝術風格 LoRA。",
            capabilities: [.lora],
            quantization: .lora,
            approximateDownloadGB: 0.16,
            recommendedMemoryGB: 16,
            licenseName: "Apache-2.0",
            sourceURL: URL(string: "https://huggingface.co/tarn59/pixel_art_style_lora_z_image_turbo"),
            isRecommended: true
        ),
        ModelDescriptor(
            id: "local-captioner-3b@q4",
            displayName: "Qwen3-VL 4B 4-bit",
            publisher: "Qwen / MLX Community",
            summary: "以本機 Qwen3-VL 將圖片轉成可編輯的多語言描述。",
            capabilities: [.imageToText],
            quantization: .fourBit,
            approximateDownloadGB: 2.9,
            recommendedMemoryGB: 16,
            licenseName: "Apache-2.0",
            sourceURL: URL(string: "https://huggingface.co/mlx-community/Qwen3-VL-4B-Instruct-4bit")
        ),
        ModelDescriptor(
            id: "qwen-image-edit-2511@mlx-int4",
            displayName: "Qwen Image Edit 2511 INT4",
            publisher: "Qwen / xocialize",
            summary: "官方 2511 基礎模型搭配預量化 Swift/MLX INT4 權重，可直接在 Apple Silicon 載入。",
            capabilities: [.imageToImage],
            quantization: .fourBit,
            approximateDownloadGB: 35.8,
            recommendedMemoryGB: 32,
            licenseName: "Apache-2.0",
            sourceURL: URL(string: "https://huggingface.co/Qwen/Qwen-Image-Edit-2511"),
            isRecommended: true
        ),
        ModelDescriptor(
            id: "qwen-image-edit-2511@mlx-int8",
            displayName: "Qwen Image Edit 2511 INT8",
            publisher: "Qwen",
            summary: "下載官方 2511 權重，首次使用時轉換並保存為 Swift/MLX INT8。",
            capabilities: [.imageToImage],
            quantization: .eightBit,
            approximateDownloadGB: 57.8,
            recommendedMemoryGB: 48,
            licenseName: "Apache-2.0",
            sourceURL: URL(string: "https://huggingface.co/Qwen/Qwen-Image-Edit-2511")
        ),
        ModelDescriptor(
            id: "qwen-image-edit-2511@mlx-fp16",
            displayName: "Qwen Image Edit 2511 FP16",
            publisher: "Qwen",
            summary: "官方 Qwen Image Edit 2511 BF16/FP16 權重，提供最高品質基準。",
            capabilities: [.imageToImage],
            quantization: .fp16,
            approximateDownloadGB: 57.8,
            recommendedMemoryGB: 64,
            licenseName: "Apache-2.0",
            sourceURL: URL(string: "https://huggingface.co/Qwen/Qwen-Image-Edit-2511")
        ),
        ModelDescriptor(
            id: "Lightricks/LTX-2.3@distilled-1.1",
            displayName: "LTX-2.3 Distilled 1.1",
            publisher: "Lightricks",
            summary: "官方開放權重圖生影模型，包含同步音訊生成；安裝項目含 Distilled 1.1、空間升頻器與 Gemma 3 12B 文字編碼器。",
            capabilities: [.imageToVideo],
            quantization: .bf16,
            approximateDownloadGB: 66.7,
            recommendedMemoryGB: 96,
            licenseName: "LTX-2 Community License / Gemma Terms",
            sourceURL: URL(string: "https://huggingface.co/Lightricks/LTX-2.3"),
            isRecommended: true
        ),
        ModelDescriptor(
            id: "dgrauet/ltx-2.3-mlx-q4",
            displayName: "LTX-2.3 MLX Q4",
            publisher: "dgrauet / LTX-2 MLX",
            summary: "原生 MLX INT4 圖生影模型，在 Apple Silicon 上透過 Metal 執行；包含影片與立體聲音訊生成所需元件。",
            capabilities: [.imageToVideo, .textToVideo],
            quantization: .fourBit,
            approximateDownloadGB: 20.5,
            recommendedMemoryGB: 24,
            licenseName: "LTX-2 Community License / MLX Port MIT",
            sourceURL: URL(string: "https://huggingface.co/dgrauet/ltx-2.3-mlx-q4"),
            isRecommended: true
        ),
        ModelDescriptor(
            id: "pipenetwork/MiniMax-H3-MLX-8bit",
            displayName: "MiniMax H3 MLX Q8",
            publisher: "PipeNetwork / MiniMaxAI",
            summary: "Apple Silicon 原生 MLX 8-bit 圖生影模型，可同步生成影片與立體聲音訊；安裝內容包含量化 Transformer 與官方 FL2VA 文字編碼器、Video/Audio VAE、Tokenizer。",
            capabilities: [.imageToVideo],
            quantization: .eightBit,
            approximateDownloadGB: 105.3,
            recommendedMemoryGB: 128,
            licenseName: "MiniMax H3 Community License",
            sourceURL: URL(string: "https://huggingface.co/pipenetwork/MiniMax-H3-MLX-8bit")
        ),
        ModelDescriptor(
            id: "pipenetwork/MiniMax-H3-MLX-4bit",
            displayName: "MiniMax H3 MLX Q4",
            publisher: "PipeNetwork / MiniMaxAI",
            summary: "Apple Silicon 原生 MLX 4-bit 圖生影模型，可同步生成影片與立體聲音訊；安裝內容包含量化 Transformer 與官方 FL2VA 文字編碼器、Video/Audio VAE、Tokenizer。",
            capabilities: [.imageToVideo],
            quantization: .fourBit,
            approximateDownloadGB: 96.0,
            recommendedMemoryGB: 96,
            licenseName: "MiniMax H3 Community License",
            sourceURL: URL(string: "https://huggingface.co/pipenetwork/MiniMax-H3-MLX-4bit"),
            isRecommended: true
        ),
        ModelDescriptor(
            id: "realesrgan-x4@coreml",
            displayName: "Real-ESRGAN 4×",
            publisher: "mlboydaisuke / xinntao",
            summary: "Core ML Real-ESRGAN 本機 4× 圖片放大與細節修復。",
            capabilities: [.upscale],
            quantization: .coreML,
            approximateDownloadGB: 0.1,
            recommendedMemoryGB: 8,
            licenseName: "BSD-3-Clause",
            sourceURL: URL(string: "https://huggingface.co/mlboydaisuke/Real-ESRGAN-x4-CoreML")
        ),
        ModelDescriptor(
            id: "realesrgan-x2@coreml",
            displayName: "Real-ESRGAN 2×",
            publisher: "mlboydaisuke / xinntao",
            summary: "使用 Core ML Real-ESRGAN 4× 修復後高品質縮放至 2×，效果較溫和。",
            capabilities: [.upscale],
            quantization: .coreML,
            approximateDownloadGB: 0.1,
            recommendedMemoryGB: 8,
            licenseName: "BSD-3-Clause",
            sourceURL: URL(string: "https://huggingface.co/mlboydaisuke/Real-ESRGAN-x4-CoreML")
        )
    ]

    public static let builtInProfiles: [InferenceProfile] = [
        InferenceProfile(
            name: "快速文生圖 · Z-Image 8-bit",
            capability: .textToImage,
            modelID: "mzbac/z-image-turbo-8bit",
            modelRevision: "main",
            architecture: .mlxSwift,
            defaults: ProfileDefaults(width: 1024, height: 1024, steps: 9, outputCount: 4),
            notes: "16GB Mac 的建議預設。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "高品質文生圖 · Z-Image 原始版",
            capability: .textToImage,
            modelID: "Tongyi-MAI/Z-Image-Turbo",
            modelRevision: "main",
            architecture: .mlxSwift,
            defaults: ProfileDefaults(width: 1024, height: 1024, steps: 9, outputCount: 4),
            notes: "適合 24GB 以上的 Mac。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "繁中圖生文 · 3B Q4",
            capability: .imageToText,
            modelID: "local-captioner-3b@q4",
            modelRevision: "main",
            architecture: .mlxSwift,
            defaults: ProfileDefaults(maxTokens: 512, languageCode: "zh-Hant"),
            notes: "輸出可直接交給文生圖編輯器。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "圖生圖 · Qwen Image Edit INT4",
            capability: .imageToImage,
            modelID: "qwen-image-edit-2511@mlx-int4",
            modelRevision: "main",
            architecture: .externalCLI,
            defaults: ProfileDefaults(width: 1024, height: 1024, steps: 20, outputCount: 1),
            notes: "Qwen Image Edit 2511 原生 Swift/MLX；建議 32GB 以上 Apple Silicon Mac。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "圖生圖 · Qwen Image Edit INT8",
            capability: .imageToImage,
            modelID: "qwen-image-edit-2511@mlx-int8",
            modelRevision: "main",
            architecture: .externalCLI,
            defaults: ProfileDefaults(width: 1024, height: 1024, steps: 20, outputCount: 1),
            notes: "首次使用會將官方 2511 權重轉存為 MLX INT8；建議 48GB 以上記憶體。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "圖生圖 · Qwen Image Edit FP16",
            capability: .imageToImage,
            modelID: "qwen-image-edit-2511@mlx-fp16",
            modelRevision: "main",
            architecture: .externalCLI,
            defaults: ProfileDefaults(width: 1024, height: 1024, steps: 20, outputCount: 1),
            notes: "官方 Qwen Image Edit 2511 完整精度 Profile；建議 64GB 以上記憶體。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "圖生影 · LTX-2.3 Distilled",
            capability: .imageToVideo,
            modelID: "Lightricks/LTX-2.3@distilled-1.1",
            modelRevision: "main",
            architecture: .externalCLI,
            defaults: ProfileDefaults(
                width: 768,
                height: 512,
                steps: 8,
                outputCount: 1,
                frameCount: 121,
                frameRate: 24
            ),
            notes: "官方 LTX-2.3 Distilled 1.1 圖生影 Profile；5 秒、24 FPS。模型中心會下載主權重、x2 空間升頻器與 Gemma 3 12B 文字編碼器，推論仍需官方 Python Runtime。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "圖生影 · LTX-2.3 MLX Q4",
            capability: .imageToVideo,
            modelID: "dgrauet/ltx-2.3-mlx-q4",
            modelRevision: "main",
            architecture: .externalCLI,
            defaults: ProfileDefaults(
                width: 704,
                height: 480,
                steps: 8,
                outputCount: 1,
                frameCount: 97,
                frameRate: 24
            ),
            notes: "原生 MLX INT4 LTX-2.3 Profile；由 ltx-2-mlx 使用 Apple Silicon Metal 執行。建議 24GB 以上記憶體，需安裝 ltx-2-mlx Python Runtime。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "文生影 · LTX-2.3 MLX Q4",
            capability: .textToVideo,
            modelID: "dgrauet/ltx-2.3-mlx-q4",
            modelRevision: "main",
            architecture: .externalCLI,
            defaults: ProfileDefaults(
                width: 704,
                height: 480,
                steps: 8,
                outputCount: 1,
                frameCount: 97,
                frameRate: 24
            ),
            notes: "原生 MLX INT4 LTX-2.3 文生影 Profile；由 ltx-2-mlx 使用 Apple Silicon Metal 執行。建議 24GB 以上記憶體，需安裝 ltx-2-mlx Python Runtime。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "圖生影 · MiniMax H3 MLX Q8",
            capability: .imageToVideo,
            modelID: "pipenetwork/MiniMax-H3-MLX-8bit",
            modelRevision: "main",
            architecture: .externalCLI,
            defaults: ProfileDefaults(
                width: 1344,
                height: 768,
                steps: 16,
                outputCount: 1,
                frameCount: 124,
                frameRate: 24
            ),
            notes: "PipeNetwork MiniMax H3 原生 MLX 8-bit Profile；預設約 5 秒、24 FPS、768p，支援首幀或首尾幀圖生影與同步音訊。推論需 pipenetwork/minimax-h3-mlx Python Runtime。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "圖生影 · MiniMax H3 MLX Q4",
            capability: .imageToVideo,
            modelID: "pipenetwork/MiniMax-H3-MLX-4bit",
            modelRevision: "main",
            architecture: .externalCLI,
            defaults: ProfileDefaults(
                width: 1344,
                height: 768,
                steps: 16,
                outputCount: 1,
                frameCount: 124,
                frameRate: 24
            ),
            notes: "PipeNetwork MiniMax H3 原生 MLX 4-bit Profile；預設約 5 秒、24 FPS、768p，支援首幀或首尾幀圖生影與同步音訊。推論需 pipenetwork/minimax-h3-mlx Python Runtime。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "一般照片放大 · Real-ESRGAN 4×",
            capability: .upscale,
            modelID: "realesrgan-x4@coreml",
            modelRevision: "1",
            architecture: .coreML,
            defaults: ProfileDefaults(upscaleScale: 4, tileSize: 512),
            notes: "使用分塊降低記憶體需求。",
            isBuiltIn: true
        ),
        InferenceProfile(
            name: "一般照片放大 · Real-ESRGAN 2×",
            capability: .upscale,
            modelID: "realesrgan-x2@coreml",
            modelRevision: "1",
            architecture: .coreML,
            defaults: ProfileDefaults(upscaleScale: 2, tileSize: 512),
            notes: "先以 Real-ESRGAN 4× 修復，再以 Lanczos 縮放為 2×。",
            isBuiltIn: true
        )
    ]
}
