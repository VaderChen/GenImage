import Foundation

public struct ModelInstallProgress: Sendable {
    public var fractionCompleted: Double
    public var downloadedBytes: Int64
    public var totalBytes: Int64

    public init(fractionCompleted: Double, downloadedBytes: Int64, totalBytes: Int64) {
        self.fractionCompleted = fractionCompleted
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
    }
}

public actor HuggingFaceModelInstaller {
    public static let int4ModelID = "qwen-image-edit-2511@mlx-int4"
    public static let int8ModelID = "qwen-image-edit-2511@mlx-int8"
    public static let fp16ModelID = "qwen-image-edit-2511@mlx-fp16"
    public static let zImage8BitModelID = "mzbac/z-image-turbo-8bit"
    public static let zImageFP16ModelID = "Tongyi-MAI/Z-Image-Turbo"
    public static let zImagePixelArtLoRAModelID = "tarn59/pixel_art_style_lora_z_image_turbo"
    public static let ltx23UnionControlLoRAModelID = "Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control"
    public static let captionerModelID = "local-captioner-3b@q4"
    public static let ltx23DistilledModelID = "Lightricks/LTX-2.3@distilled-1.1"
    public static let ltx23MLXQ4ModelID = "dgrauet/ltx-2.3-mlx-q4"
    public static let miniMaxH3MLX8BitModelID = "pipenetwork/MiniMax-H3-MLX-8bit"
    public static let miniMaxH3MLX4BitModelID = "pipenetwork/MiniMax-H3-MLX-4bit"
    public static let realESRGAN4xModelID = "realesrgan-x4@coreml"
    public static let realESRGAN2xModelID = "realesrgan-x2@coreml"

    private struct SourcePlan: Sendable {
        var repository: String
        var revision: String = "main"
        var destinationSubdirectory: String
        var prefixes: [String]
        var exactFiles: Set<String>

        func includes(_ path: String) -> Bool {
            exactFiles.contains(path) || prefixes.contains { path.hasPrefix($0) }
        }
    }

    private struct InstallPlan: Sendable {
        var directoryName: String
        var runtimeRelativePath: String?
        var sources: [SourcePlan]

        init(
            directoryName: String,
            runtimeRelativePath: String? = nil,
            sources: [SourcePlan]
        ) {
            self.directoryName = directoryName
            self.runtimeRelativePath = runtimeRelativePath
            self.sources = sources
        }
    }

    private struct HubTreeEntry: Decodable, Sendable {
        var type: String
        var size: Int64
        var path: String
    }

    private struct ManifestFile: Codable, Sendable {
        var relativePath: String
        var remotePath: String?
        var size: Int64
        var repository: String
        var revision: String
    }

    private struct InstallManifest: Codable, Sendable {
        var schemaVersion: Int
        var modelID: String
        var installedAt: Date
        var files: [ManifestFile]
    }

    private struct ResolvedFile: Sendable {
        var repository: String
        var revision: String
        var remotePath: String
        var relativePath: String
        var size: Int64
    }

    public init() {}

    public nonisolated static func supports(modelID: String) -> Bool {
        plan(for: modelID) != nil
    }

    public nonisolated static func installationDirectory(modelID: String, rootURL: URL) -> URL? {
        guard let plan = plan(for: modelID) else { return nil }
        return rootURL.appendingPathComponent(plan.directoryName, isDirectory: true)
    }

    public func install(
        modelID: String,
        rootURL: URL,
        progress: @escaping @Sendable (ModelInstallProgress) -> Void
    ) async throws -> URL {
        guard let plan = Self.plan(for: modelID) else {
            throw ModelInstallerError.unsupportedModel(modelID)
        }
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let destination = rootURL.appendingPathComponent(plan.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let files = try await resolveFiles(plan: plan)
        guard !files.isEmpty else { throw ModelInstallerError.emptyRepository(modelID) }
        let totalBytes = files.reduce(Int64(0)) { $0 + $1.size }
        var completedBytes = files.reduce(Int64(0)) { result, file in
            let url = destination.appendingPathComponent(file.relativePath)
            return result + (Self.fileSize(at: url) == file.size ? file.size : 0)
        }
        progress(
            ModelInstallProgress(
                fractionCompleted: Self.fraction(completedBytes, totalBytes),
                downloadedBytes: completedBytes,
                totalBytes: totalBytes
            )
        )

        for file in files {
            try Task.checkCancellation()
            let fileURL = destination.appendingPathComponent(file.relativePath)
            if Self.fileSize(at: fileURL) == file.size { continue }

            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if let reusableURL = Self.reusableFile(
                for: file,
                rootURL: rootURL,
                excluding: destination
            ) {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                do {
                    try FileManager.default.linkItem(at: reusableURL, to: fileURL)
                    completedBytes += file.size
                    progress(
                        ModelInstallProgress(
                            fractionCompleted: Self.fraction(completedBytes, totalBytes),
                            downloadedBytes: completedBytes,
                            totalBytes: totalBytes
                        )
                    )
                    continue
                } catch {
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                }
            }

            let request = try Self.downloadRequest(for: file)
            let completedBeforeFile = completedBytes
            let downloader = FileDownloadDelegate(
                destination: fileURL,
                expectedBytes: file.size,
                progress: { received, _ in
                    let downloaded = min(totalBytes, completedBeforeFile + received)
                    progress(
                        ModelInstallProgress(
                            fractionCompleted: Self.fraction(downloaded, totalBytes),
                            downloadedBytes: downloaded,
                            totalBytes: totalBytes
                        )
                    )
                }
            )
            do {
                try await downloader.start(request: request)
            } catch {
                try Task.checkCancellation()
                throw error
            }
            guard Self.fileSize(at: fileURL) == file.size else {
                throw ModelInstallerError.sizeMismatch(
                    path: file.relativePath,
                    expected: file.size,
                    actual: Self.fileSize(at: fileURL)
                )
            }
            completedBytes += file.size
            progress(
                ModelInstallProgress(
                    fractionCompleted: Self.fraction(completedBytes, totalBytes),
                    downloadedBytes: completedBytes,
                    totalBytes: totalBytes
                )
            )
        }

        let manifest = InstallManifest(
            schemaVersion: 2,
            modelID: modelID,
            installedAt: .now,
            files: files.map {
                ManifestFile(
                    relativePath: $0.relativePath,
                    remotePath: $0.remotePath,
                    size: $0.size,
                    repository: $0.repository,
                    revision: $0.revision
                )
            }
        )
        let manifestData = try JSONEncoder.genImageManifest.encode(manifest)
        try manifestData.write(
            to: destination.appendingPathComponent("genimage-model.json"),
            options: .atomic
        )
        return Self.runtimeURL(for: plan, destination: destination)
    }

    public nonisolated static func verify(modelID: String, rootURL: URL) throws -> URL {
        guard let plan = plan(for: modelID) else {
            throw ModelInstallerError.unsupportedModel(modelID)
        }
        let destination = rootURL.appendingPathComponent(plan.directoryName, isDirectory: true)
        let manifestURL = destination.appendingPathComponent("genimage-model.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder.genImageManifest.decode(InstallManifest.self, from: data),
              manifest.modelID == modelID,
              !manifest.files.isEmpty else {
            throw ModelInstallerError.invalidManifest(manifestURL)
        }
        for file in manifest.files {
            let url = destination.appendingPathComponent(file.relativePath)
            let actual = fileSize(at: url)
            guard actual == file.size else {
                throw ModelInstallerError.sizeMismatch(
                    path: file.relativePath,
                    expected: file.size,
                    actual: actual
                )
            }
        }
        let runtimeURL = runtimeURL(for: plan, destination: destination)
        guard FileManager.default.fileExists(atPath: runtimeURL.path) else {
            throw ModelInstallerError.runtimeNotFound(runtimeURL)
        }
        return runtimeURL
    }

    public nonisolated static func remove(modelID: String, rootURL: URL) throws {
        guard let destination = installationDirectory(modelID: modelID, rootURL: rootURL) else {
            throw ModelInstallerError.unsupportedModel(modelID)
        }
        guard FileManager.default.fileExists(atPath: destination.path) else { return }
        try FileManager.default.removeItem(at: destination)
    }

    private func resolveFiles(plan: InstallPlan) async throws -> [ResolvedFile] {
        var result: [ResolvedFile] = []
        for source in plan.sources {
            let tree = try await Self.fetchTree(repository: source.repository, revision: source.revision)
            let selected = tree.filter {
                $0.type == "file"
                    && $0.size >= 0
                    && source.includes($0.path)
                    && Self.isSafeRelativePath($0.path)
            }
            guard !selected.isEmpty else {
                throw ModelInstallerError.noMatchingFiles(source.repository)
            }
            result.append(contentsOf: selected.map {
                let relativePath = source.destinationSubdirectory.isEmpty
                    ? $0.path
                    : source.destinationSubdirectory + "/" + $0.path
                return ResolvedFile(
                    repository: source.repository,
                    revision: source.revision,
                    remotePath: $0.path,
                    relativePath: relativePath,
                    size: $0.size
                )
            })
        }
        return result.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private nonisolated static func fetchTree(
        repository: String,
        revision: String
    ) async throws -> [HubTreeEntry] {
        guard let encodedRevision = revision.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(
                string: "https://huggingface.co/api/models/\(repository)/tree/\(encodedRevision)?recursive=true&expand=false&limit=1000"
              ) else {
            throw ModelInstallerError.invalidRepository(repository)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("GenImage/1.0", forHTTPHeaderField: "User-Agent")
        Self.applyAuthorization(to: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: data)
        return try JSONDecoder().decode([HubTreeEntry].self, from: data)
    }

    private nonisolated static func downloadRequest(for file: ResolvedFile) throws -> URLRequest {
        let pathSegments = file.remotePath.split(separator: "/").map(String.init)
        var url = URL(string: "https://huggingface.co/\(file.repository)/resolve/\(file.revision)")!
        for segment in pathSegments { url.appendPathComponent(segment) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60 * 60 * 24
        request.setValue("GenImage/1.0", forHTTPHeaderField: "User-Agent")
        applyAuthorization(to: &request)
        return request
    }

    private nonisolated static func applyAuthorization(to request: inout URLRequest) {
        guard let token = ProcessInfo.processInfo.environment["HF_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private nonisolated static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ModelInstallerError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data.prefix(2_048), encoding: .utf8) ?? ""
            throw ModelInstallerError.httpStatus(http.statusCode, message)
        }
    }

    private nonisolated static func plan(for modelID: String) -> InstallPlan? {
        let officialFiles: Set<String> = ["model_index.json"]
        let officialPrefixes = [
            "processor/", "scheduler/", "text_encoder/", "tokenizer/", "transformer/", "vae/"
        ]
        switch modelID {
        case zImage8BitModelID:
            return InstallPlan(
                directoryName: "z-image-turbo-8bit",
                sources: [
                    SourcePlan(
                        repository: "mzbac/Z-Image-Turbo-8bit",
                        destinationSubdirectory: "",
                        prefixes: [
                            "scheduler/", "text_encoder/", "tokenizer/", "transformer/", "vae/"
                        ],
                        exactFiles: ["model_index.json", "quantization.json"]
                    )
                ]
            )
        case zImageFP16ModelID:
            return InstallPlan(
                directoryName: "z-image-turbo-fp16",
                sources: [
                    SourcePlan(
                        repository: "Tongyi-MAI/Z-Image-Turbo",
                        destinationSubdirectory: "",
                        prefixes: [
                            "scheduler/", "text_encoder/", "tokenizer/", "transformer/", "vae/"
                        ],
                        exactFiles: ["model_index.json"]
                    )
                ]
            )
        case zImagePixelArtLoRAModelID:
            return InstallPlan(
                directoryName: "loras/z-image-pixel-art",
                runtimeRelativePath: "pixel_art_style_z_image_turbo.safetensors",
                sources: [
                    SourcePlan(
                        repository: "tarn59/pixel_art_style_lora_z_image_turbo",
                        destinationSubdirectory: "",
                        prefixes: [],
                        exactFiles: ["pixel_art_style_z_image_turbo.safetensors"]
                    )
                ]
            )
        case ltx23UnionControlLoRAModelID:
            return InstallPlan(
                directoryName: "loras/ltx-2.3-union-control",
                runtimeRelativePath: "ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors",
                sources: [
                    SourcePlan(
                        repository: "Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control",
                        destinationSubdirectory: "",
                        prefixes: [],
                        exactFiles: [
                            "LICENSE",
                            "README.md",
                            "ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors"
                        ]
                    )
                ]
            )
        case captionerModelID:
            return InstallPlan(
                directoryName: "Qwen3-VL-4B-Instruct-4bit",
                sources: [
                    SourcePlan(
                        repository: "mlx-community/Qwen3-VL-4B-Instruct-4bit",
                        destinationSubdirectory: "",
                        prefixes: [],
                        exactFiles: [
                            "added_tokens.json",
                            "chat_template.jinja",
                            "chat_template.json",
                            "config.json",
                            "generation_config.json",
                            "merges.txt",
                            "model.safetensors",
                            "model.safetensors.index.json",
                            "preprocessor_config.json",
                            "special_tokens_map.json",
                            "tokenizer.json",
                            "tokenizer_config.json",
                            "video_preprocessor_config.json",
                            "vocab.json"
                        ]
                    )
                ]
            )
        case realESRGAN4xModelID:
            return realESRGANPlan(directoryName: "realesrgan-coreml-x4")
        case realESRGAN2xModelID:
            return realESRGANPlan(directoryName: "realesrgan-coreml-x2")
        case ltx23DistilledModelID:
            return InstallPlan(
                directoryName: "ltx-2.3-distilled-1.1",
                sources: [
                    SourcePlan(
                        repository: "Lightricks/LTX-2.3",
                        destinationSubdirectory: "",
                        prefixes: [],
                        exactFiles: [
                            "LICENSE",
                            "ltx-2.3-22b-distilled-1.1.safetensors",
                            "ltx-2.3-spatial-upscaler-x2-1.1.safetensors"
                        ]
                    ),
                    SourcePlan(
                        repository: "google/gemma-3-12b-it-qat-q4_0-unquantized",
                        destinationSubdirectory: "gemma-3-12b",
                        prefixes: [],
                        exactFiles: [
                            "added_tokens.json",
                            "chat_template.json",
                            "config.json",
                            "generation_config.json",
                            "model-00001-of-00005.safetensors",
                            "model-00002-of-00005.safetensors",
                            "model-00003-of-00005.safetensors",
                            "model-00004-of-00005.safetensors",
                            "model-00005-of-00005.safetensors",
                            "model.safetensors.index.json",
                            "preprocessor_config.json",
                            "processor_config.json",
                            "special_tokens_map.json",
                            "tokenizer.json",
                            "tokenizer.model",
                            "tokenizer_config.json"
                        ]
                    )
                ]
            )
        case ltx23MLXQ4ModelID:
            return InstallPlan(
                directoryName: "ltx-2.3-mlx-q4",
                sources: [
                    SourcePlan(
                        repository: "dgrauet/ltx-2.3-mlx-q4",
                        destinationSubdirectory: "",
                        prefixes: [],
                        exactFiles: [
                            "README.md",
                            "audio_vae.safetensors",
                            "config.json",
                            "connector.safetensors",
                            "embedded_config.json",
                            "quantize_config.json",
                            "spatial_upscaler_x2_v1_1.safetensors",
                            "spatial_upscaler_x2_v1_1_config.json",
                            "split_model.json",
                            "transformer-distilled-1.1.safetensors",
                            "vae_decoder.safetensors",
                            "vae_encoder.safetensors",
                            "vocoder.safetensors"
                        ]
                    )
                ]
            )
        case miniMaxH3MLX8BitModelID:
            return miniMaxH3MLXPlan(
                repository: "pipenetwork/MiniMax-H3-MLX-8bit",
                directoryName: "minimax-h3-mlx-8bit"
            )
        case miniMaxH3MLX4BitModelID:
            return miniMaxH3MLXPlan(
                repository: "pipenetwork/MiniMax-H3-MLX-4bit",
                directoryName: "minimax-h3-mlx-4bit"
            )
        case int4ModelID:
            return InstallPlan(
                directoryName: "qwen-image-edit-2511-int4",
                sources: [
                    SourcePlan(
                        repository: "Qwen/Qwen-Image-Edit-2511",
                        destinationSubdirectory: "snapshot",
                        prefixes: ["processor/", "text_encoder/", "vae/"],
                        exactFiles: officialFiles
                    ),
                    SourcePlan(
                        repository: "xocialize/qwen-image-edit-2511-mlx-int4",
                        destinationSubdirectory: "quantized",
                        prefixes: [],
                        exactFiles: [
                            "qie-2511-dit-int4-mod8.safetensors",
                            "qie-2511-vl7b-int4.safetensors"
                        ]
                    )
                ]
            )
        case int8ModelID:
            return InstallPlan(
                directoryName: "qwen-image-edit-2511-int8",
                sources: [
                    SourcePlan(
                        repository: "Qwen/Qwen-Image-Edit-2511",
                        destinationSubdirectory: "snapshot",
                        prefixes: officialPrefixes,
                        exactFiles: officialFiles
                    )
                ]
            )
        case fp16ModelID:
            return InstallPlan(
                directoryName: "qwen-image-edit-2511-fp16",
                sources: [
                    SourcePlan(
                        repository: "Qwen/Qwen-Image-Edit-2511",
                        destinationSubdirectory: "snapshot",
                        prefixes: officialPrefixes,
                        exactFiles: officialFiles
                    )
                ]
            )
        default:
            return nil
        }
    }

    private nonisolated static func miniMaxH3MLXPlan(
        repository: String,
        directoryName: String
    ) -> InstallPlan {
        InstallPlan(
            directoryName: directoryName,
            sources: [
                SourcePlan(
                    repository: repository,
                    destinationSubdirectory: "transformer",
                    prefixes: ["model-"],
                    exactFiles: [
                        "LICENSE",
                        "README.md",
                        "config.json",
                        "model.safetensors.index.json",
                        "quant_config.json"
                    ]
                ),
                SourcePlan(
                    repository: "MiniMaxAI/MiniMax-H3",
                    destinationSubdirectory: "upstream",
                    prefixes: [
                        "FL2VA/audio_vae/",
                        "FL2VA/processor/",
                        "FL2VA/text_encoder/",
                        "FL2VA/tokenizer/",
                        "FL2VA/video_vae/"
                    ],
                    exactFiles: ["FL2VA/model_index.json"]
                )
            ]
        )
    }

    private nonisolated static func realESRGANPlan(directoryName: String) -> InstallPlan {
        InstallPlan(
            directoryName: directoryName,
            runtimeRelativePath: "RealESRGAN_x4.mlpackage",
            sources: [
                SourcePlan(
                    repository: "mlboydaisuke/Real-ESRGAN-x4-CoreML",
                    destinationSubdirectory: "",
                    prefixes: ["RealESRGAN_x4.mlpackage/"],
                    exactFiles: []
                )
            ]
        )
    }

    private nonisolated static func runtimeURL(
        for plan: InstallPlan,
        destination: URL
    ) -> URL {
        guard let relativePath = plan.runtimeRelativePath else { return destination }
        return destination.appendingPathComponent(relativePath)
    }

    private nonisolated static func isSafeRelativePath(_ path: String) -> Bool {
        !path.isEmpty
            && !path.hasPrefix("/")
            && !path.split(separator: "/").contains("..")
    }

    private nonisolated static func reusableFile(
        for file: ResolvedFile,
        rootURL: URL,
        excluding destination: URL
    ) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        let excludedPath = destination.standardizedFileURL.path
        for case let manifestURL as URL in enumerator
        where manifestURL.lastPathComponent == "genimage-model.json" {
            let installDirectory = manifestURL.deletingLastPathComponent().standardizedFileURL
            if installDirectory.path == excludedPath { continue }
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder.genImageManifest.decode(InstallManifest.self, from: data),
                  let match = manifest.files.first(where: {
                      $0.repository == file.repository
                          && $0.revision == file.revision
                          && $0.remotePath == file.remotePath
                          && $0.size == file.size
                          && isSafeRelativePath($0.relativePath)
                  }) else { continue }

            let candidate = installDirectory.appendingPathComponent(match.relativePath)
            if fileSize(at: candidate) == file.size {
                return candidate
            }
        }
        return nil
    }

    private nonisolated static func fileSize(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true else { return -1 }
        return Int64(values.fileSize ?? -1)
    }

    private nonisolated static func fraction(_ completed: Int64, _ total: Int64) -> Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }
}

private final class FileDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let resumeDataURL: URL
    private let expectedBytes: Int64
    private let progress: @Sendable (Int64, Int64) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var movedFile = false
    private var completed = false

    init(
        destination: URL,
        expectedBytes: Int64,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) {
        self.destination = destination
        resumeDataURL = destination.appendingPathExtension("resume")
        self.expectedBytes = expectedBytes
        self.progress = progress
    }

    func start(request: URLRequest) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                self.continuation = continuation
                let configuration = URLSessionConfiguration.default
                configuration.timeoutIntervalForRequest = 60 * 60 * 24
                configuration.timeoutIntervalForResource = 60 * 60 * 24
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                let task: URLSessionDownloadTask
                if let resumeData = try? Data(contentsOf: resumeDataURL), !resumeData.isEmpty {
                    task = session.downloadTask(withResumeData: resumeData)
                } else {
                    task = session.downloadTask(with: request)
                }
                self.task = task
                lock.unlock()
                task.resume()
            }
        } onCancel: {
            self.cancel()
        }
    }

    func cancel() {
        lock.lock()
        let task = task
        lock.unlock()
        task?.cancel { [resumeDataURL] resumeData in
            guard let resumeData, !resumeData.isEmpty else { return }
            try? resumeData.write(to: resumeDataURL, options: .atomic)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            let fileManager = FileManager.default
            let actual = Int64(
                (try location.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? -1
            )
            guard actual == expectedBytes else {
                throw ModelInstallerError.sizeMismatch(
                    path: destination.lastPathComponent,
                    expected: expectedBytes,
                    actual: actual
                )
            }
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
            try? fileManager.removeItem(at: resumeDataURL)
            lock.lock()
            movedFile = true
            lock.unlock()
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        if let error {
            finish(.failure(error))
            return
        }
        lock.lock()
        let movedFile = movedFile
        lock.unlock()
        finish(movedFile ? .success(()) : .failure(ModelInstallerError.invalidResponse))
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let continuation = continuation
        self.continuation = nil
        let session = session
        self.session = nil
        task = nil
        lock.unlock()
        session?.finishTasksAndInvalidate()
        continuation?.resume(with: result)
    }
}

public enum ModelInstallerError: LocalizedError, Sendable {
    case unsupportedModel(String)
    case invalidRepository(String)
    case emptyRepository(String)
    case noMatchingFiles(String)
    case invalidResponse
    case httpStatus(Int, String)
    case invalidManifest(URL)
    case runtimeNotFound(URL)
    case sizeMismatch(path: String, expected: Int64, actual: Int64)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedModel(id):
            "此模型尚未提供可執行的下載方案：\(id)"
        case let .invalidRepository(repository):
            "Hugging Face 模型來源格式不正確：\(repository)"
        case let .emptyRepository(id):
            "模型下載清單是空的：\(id)"
        case let .noMatchingFiles(repository):
            "模型來源沒有符合 Runtime 的檔案：\(repository)"
        case .invalidResponse:
            "模型伺服器回傳了無效回應。"
        case let .httpStatus(status, message):
            "模型伺服器回傳 HTTP \(status)：\(message)"
        case let .invalidManifest(url):
            "模型安裝資訊不存在或已損壞：\(url.path)"
        case let .runtimeNotFound(url):
            "安裝完成但找不到 Runtime 模型：\(url.path)"
        case let .sizeMismatch(path, expected, actual):
            "模型檔案大小不符：\(path)（預期 \(expected)，實際 \(actual) bytes）"
        }
    }
}

private extension JSONEncoder {
    static var genImageManifest: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var genImageManifest: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
