import Foundation
import GenImageCore

public actor LTXVideoGenerationService: VideoGenerating {
    private let outputDirectory: URL
    private var runningProcess: Process?

    public init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    public func generate(
        request: VideoGenerationRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [ImageAsset] {
        try request.options.validate()
        guard request.profile.capability == .textToVideo
                || request.profile.capability == .imageToVideo else {
            throw LTXVideoRuntimeError.incompatibleProfile
        }
        guard request.profile.architecture == .externalCLI else {
            throw LTXVideoRuntimeError.unsupportedArchitecture(request.profile.architecture)
        }
        guard request.profile.modelID.lowercased().contains("ltx-2.3-mlx") else {
            throw LTXVideoRuntimeError.unsupportedModel(request.profile.modelID)
        }
        guard request.options.frameCount % 8 == 1 else {
            throw LTXVideoRuntimeError.invalidFrameCount(request.options.frameCount)
        }
        if request.profile.capability == .imageToVideo {
            guard let inputURL = request.sourceAsset?.fileURL,
                  FileManager.default.fileExists(atPath: inputURL.path) else {
                throw LTXVideoRuntimeError.missingInputFile
            }
        }
        let manifestURL = request.modelURL.appendingPathComponent("genimage-model.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw LTXVideoRuntimeError.modelNotInstalled(request.modelURL)
        }

        let executable = try Self.runtimeExecutable()
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        var outputs: [ImageAsset] = []
        var generatedOutputURLs: [URL] = []
        var completed = false
        defer {
            if !completed {
                for outputURL in generatedOutputURLs {
                    try? FileManager.default.removeItem(at: outputURL)
                }
            }
        }
        for index in 0..<request.options.outputCount {
            try Task.checkCancellation()
            let identifier = UUID().uuidString
            let outputURL = outputDirectory.appendingPathComponent("ltx-video-\(identifier).mp4")
            generatedOutputURLs.append(outputURL)
            let logURL = outputDirectory.appendingPathComponent("ltx-video-\(identifier).log")
            defer { try? FileManager.default.removeItem(at: logURL) }

            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            let logHandle = try FileHandle(forWritingTo: logURL)
            defer { try? logHandle.close() }

            let process = Process()
            process.executableURL = executable
            process.arguments = Self.arguments(
                request: request,
                outputURL: outputURL,
                seed: request.options.seed &+ UInt64(index)
            )
            process.environment = Self.runtimeEnvironment()
            process.standardOutput = logHandle
            process.standardError = logHandle
            runningProcess = process
            defer { runningProcess = nil }

            let completedFraction = Double(index) / Double(request.options.outputCount)
            progress(completedFraction + 0.01 / Double(request.options.outputCount))
            try process.run()
            do {
                while process.isRunning {
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(300))
                    let runtimeProgress = min(Self.latestProgress(in: logURL) ?? 0.02, 0.95)
                    progress(
                        completedFraction
                            + runtimeProgress / Double(request.options.outputCount)
                    )
                }
            } catch is CancellationError {
                process.terminate()
                process.waitUntilExit()
                throw CancellationError()
            }
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw LTXVideoRuntimeError.runtimeFailed(
                    status: process.terminationStatus,
                    message: Self.logMessage(in: logURL)
                )
            }
            guard FileManager.default.fileExists(atPath: outputURL.path),
                  (try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 else {
                throw LTXVideoRuntimeError.outputMissing(outputURL)
            }

            outputs.append(
                ImageAsset(
                    projectID: request.projectID,
                    parentAssetID: request.sourceAsset?.id,
                    kind: .generatedVideo,
                    title: request.options.outputCount == 1
                        ? "生成影片"
                        : "生成影片 \(index + 1)",
                    fileURL: outputURL,
                    pixelWidth: request.options.width,
                    pixelHeight: request.options.height,
                    recipeID: request.recipeID
                )
            )
            progress(Double(index + 1) / Double(request.options.outputCount))
        }
        completed = true
        return outputs
    }

    private nonisolated static func arguments(
        request: VideoGenerationRequest,
        outputURL: URL,
        seed: UInt64
    ) -> [String] {
        var arguments = [
            "generate",
            "--prompt", request.options.prompt,
            "--output", outputURL.path,
            "--model", request.modelURL.path,
            "--height", String(request.options.height),
            "--width", String(request.options.width),
            "--frames", String(request.options.frameCount),
            "--frame-rate", String(request.options.frameRate),
            "--seed", String(seed),
            "--distilled",
            "--stage1-steps", String(request.options.steps)
        ]
        if let gemmaModel = ProcessInfo.processInfo.environment["GENIMAGE_LTX_GEMMA_MODEL"],
           !gemmaModel.isEmpty {
            arguments.append(contentsOf: ["--gemma", gemmaModel])
        }
        if let inputURL = request.sourceAsset?.fileURL {
            arguments.append(contentsOf: ["--image", inputURL.path])
        }
        return arguments
    }

    private nonisolated static func runtimeExecutable() throws -> URL {
        let fileManager = FileManager.default
        var candidates: [URL] = []
        let environment = ProcessInfo.processInfo.environment

        if let configured = environment["GENIMAGE_LTX_RUNTIME"], !configured.isEmpty {
            candidates.append(URL(fileURLWithPath: configured))
        }
        if let runtimeRoot = environment["GENIMAGE_LTX_RUNTIME_ROOT"], !runtimeRoot.isEmpty {
            candidates.append(
                URL(fileURLWithPath: runtimeRoot, isDirectory: true)
                    .appendingPathComponent(".venv/bin/ltx-2-mlx")
            )
        }
        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            candidates.append(executableDirectory.appendingPathComponent("ltx-2-mlx"))
            candidates.append(
                executableDirectory
                    .deletingLastPathComponent()
                    .appendingPathComponent("Helpers/ltx-2-mlx")
            )
        }

        let home = fileManager.homeDirectoryForCurrentUser
        candidates.append(home.appendingPathComponent(".local/bin/ltx-2-mlx"))
        candidates.append(
            home.appendingPathComponent(
                "Library/Application Support/GenImage/Runtime/ltx-2-mlx/.venv/bin/ltx-2-mlx"
            )
        )
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/ltx-2-mlx"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/ltx-2-mlx"))

        for directory in (environment["PATH"] ?? "").split(separator: ":") {
            candidates.append(
                URL(fileURLWithPath: String(directory), isDirectory: true)
                    .appendingPathComponent("ltx-2-mlx")
            )
        }

        guard let executable = candidates.first(where: {
            fileManager.isExecutableFile(atPath: $0.path)
        }) else {
            throw LTXVideoRuntimeError.runtimeNotFound(candidates.map(\.path))
        }
        return executable
    }

    private nonisolated static func runtimeEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let commonPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        let currentPaths = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        environment["PATH"] = (currentPaths + commonPaths)
            .reduce(into: [String]()) { paths, path in
                if !paths.contains(path) { paths.append(path) }
            }
            .joined(separator: ":")
        environment["PYTHONUNBUFFERED"] = "1"
        return environment
    }

    private nonisolated static func latestProgress(in logURL: URL) -> Double? {
        guard let data = try? Data(contentsOf: logURL),
              let text = String(data: data.suffix(64 * 1_024), encoding: .utf8) else {
            return nil
        }
        let pattern = #"(?:^|\D)(\d{1,3})(?:\.\d+)?%"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let value = Double(text[valueRange]), value <= 100 else { return nil }
            return value / 100
        }.max()
    }

    private nonisolated static func logMessage(in logURL: URL) -> String {
        guard let data = try? Data(contentsOf: logURL), !data.isEmpty else {
            return "Runtime 未提供錯誤訊息。"
        }
        return String(data: data.suffix(8_192), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "Runtime 執行失敗。"
    }
}

public enum LTXVideoRuntimeError: LocalizedError, Sendable {
    case incompatibleProfile
    case unsupportedArchitecture(InferenceArchitecture)
    case unsupportedModel(String)
    case invalidFrameCount(Int)
    case missingInputFile
    case modelNotInstalled(URL)
    case runtimeNotFound([String])
    case runtimeFailed(status: Int32, message: String)
    case outputMissing(URL)

    public var errorDescription: String? {
        switch self {
        case .incompatibleProfile:
            "Profile 不是文生影或圖生影類型。"
        case let .unsupportedArchitecture(architecture):
            "LTX 影片 Runtime 不支援此架構：\(architecture.title)。"
        case let .unsupportedModel(modelID):
            "目前影片 Runtime 尚不支援模型：\(modelID)。"
        case let .invalidFrameCount(frameCount):
            "LTX-2.3 幀數必須符合 8n+1，目前為 \(frameCount)。"
        case .missingInputFile:
            "圖生影需要一張可讀取的本機圖片。"
        case let .modelNotInstalled(url):
            "LTX-2.3 模型尚未完整安裝：\(url.path)"
        case let .runtimeNotFound(paths):
            "找不到 ltx-2-mlx Runtime。請安裝後設定 GENIMAGE_LTX_RUNTIME；已檢查：\(paths.joined(separator: "、"))"
        case let .runtimeFailed(status, message):
            "LTX 影片 Runtime 結束（\(status)）：\(message)"
        case let .outputMissing(url):
            "LTX 推論完成但沒有產生影片：\(url.path)"
        }
    }
}
