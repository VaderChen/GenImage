import Foundation
import GenImageCore
import Logging
import ZImage

public actor ZImageTextToImageService: TextToImageGenerating {
    private let outputDirectory: URL
    private let pipeline: ZImagePipeline

    public init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
        let logger = Logger(label: "genimage.zimage") { _ in
            SwiftLogNoOpLogHandler()
        }
        pipeline = ZImagePipeline(logger: logger)
    }

    public func generate(
        request: TextToImageRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [ImageAsset] {
        guard request.profile.capability == .textToImage else {
            throw ZImageRuntimeError.incompatibleProfile
        }
        guard request.profile.architecture == .mlxSwift else {
            throw ZImageRuntimeError.unsupportedArchitecture(request.profile.architecture)
        }

        try request.recipe.validate()
        let modelURL = URL(fileURLWithPath: request.profile.modelID, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ZImageRuntimeError.modelNotFound(modelURL)
        }

        let loraConfiguration: LoRAConfiguration?
        if let selection = request.recipe.lora {
            let loraURL = selection.localURL.resolvingSymlinksInPath().standardizedFileURL
            var isLoRADirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: loraURL.path, isDirectory: &isLoRADirectory),
                  !isLoRADirectory.boolValue else {
                throw ZImageRuntimeError.loraNotFound(loraURL)
            }
            guard loraURL.pathExtension.lowercased() == "safetensors" else {
                throw ZImageRuntimeError.unsupportedLoRAFormat(loraURL)
            }
            loraConfiguration = .local(loraURL, scale: Float(selection.scale))
        } else {
            loraConfiguration = nil
        }

        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let outputCount = request.recipe.outputCount
        var assets: [ImageAsset] = []
        assets.reserveCapacity(outputCount)

        for index in 0..<outputCount {
            try Task.checkCancellation()
            let seed = request.recipe.seed &+ UInt64(index)
            let outputURL = outputDirectory.appendingPathComponent(
                "zimage-\(UUID().uuidString).png"
            )
            let generationRequest = ZImageGenerationRequest(
                prompt: request.recipe.prompt,
                negativePrompt: request.recipe.negativePrompt.isEmpty
                    ? nil
                    : request.recipe.negativePrompt,
                width: request.recipe.width,
                height: request.recipe.height,
                steps: request.recipe.steps,
                guidanceScale: 0,
                seed: seed,
                outputPath: outputURL,
                model: modelURL.path,
                lora: loraConfiguration
            )

            var lastFraction = 0.0
            _ = try await pipeline.generate(generationRequest) { update in
                let currentFraction: Double
                switch update.stage {
                case .loadingModel:
                    currentFraction = 0.02
                case .encodingText:
                    currentFraction = 0.12
                case .loadingTransformer:
                    currentFraction = 0.18
                case .loadingLoRA:
                    currentFraction = 0.22
                case .loadingVAE:
                    currentFraction = 0.24
                case .denoising:
                    currentFraction = 0.25 + update.fractionCompleted * 0.60
                case .decoding:
                    currentFraction = 0.90
                case .saving:
                    currentFraction = 1
                }
                lastFraction = max(lastFraction, currentFraction)
                progress((Double(index) + lastFraction) / Double(outputCount))
            }
            try Task.checkCancellation()

            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw ZImageRuntimeError.outputMissing(outputURL)
            }
            assets.append(
                ImageAsset(
                    projectID: request.projectID,
                    parentAssetID: request.sourceAsset?.id,
                    kind: .generated,
                    title: outputCount == 1 ? "生成結果" : "生成結果 \(index + 1)",
                    fileURL: outputURL,
                    pixelWidth: request.recipe.width,
                    pixelHeight: request.recipe.height,
                    recipeID: request.recipe.id
                )
            )
        }

        progress(1)
        return assets
    }
}

public enum ZImageRuntimeError: LocalizedError, Sendable {
    case incompatibleProfile
    case unsupportedArchitecture(InferenceArchitecture)
    case modelNotFound(URL)
    case loraNotFound(URL)
    case unsupportedLoRAFormat(URL)
    case outputMissing(URL)

    public var errorDescription: String? {
        switch self {
        case .incompatibleProfile:
            "Profile 不是文生圖類型。"
        case let .unsupportedArchitecture(architecture):
            "Z-Image Runtime 不支援此架構：\(architecture.title)。"
        case let .modelNotFound(url):
            "找不到 Z-Image 模型：\(url.path)"
        case let .loraNotFound(url):
            "找不到 LoRA 模型：\(url.path)"
        case let .unsupportedLoRAFormat(url):
            "LoRA 必須是 .safetensors 檔案：\(url.path)"
        case let .outputMissing(url):
            "Z-Image 完成推論但沒有產生檔案：\(url.path)"
        }
    }
}
