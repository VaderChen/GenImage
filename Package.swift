// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GenImage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GenImage", targets: ["GenImageApp"]),
        .executable(name: "GenImageDoctor", targets: ["GenImageDoctor"]),
        .executable(name: "GenImageMCP", targets: ["GenImageMCP"]),
        .library(name: "GenImageCore", targets: ["GenImageCore"]),
        .library(name: "GenImageRuntime", targets: ["GenImageRuntime"]),
        .library(name: "GenImageMCPServer", targets: ["GenImageMCPServer"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/zhutao100/Z-Image.swift.git",
            revision: "28bfcf3148c041a554629247170eb54d9ac46830"
        ),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm.git",
            exact: "2.30.6"
        ),
        .package(
            url: "https://github.com/apple/swift-log.git",
            from: "1.6.4"
        )
    ],
    targets: [
        .target(name: "GenImageCore"),
        .executableTarget(
            name: "GenImageApp",
            dependencies: ["GenImageCore", "GenImageRuntime"],
            resources: [
                .copy("Resources/WebUI")
            ]
        ),
        .executableTarget(
            name: "GenImageDoctor",
            dependencies: ["GenImageCore", "GenImageRuntime"]
        ),
        .target(
            name: "GenImageRuntime",
            dependencies: [
                "GenImageCore",
                .product(name: "ZImage", package: "z-image.swift"),
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .target(
            name: "GenImageMCPServer",
            dependencies: ["GenImageCore", "GenImageRuntime"]
        ),
        .executableTarget(
            name: "GenImageMCP",
            dependencies: ["GenImageMCPServer"]
        ),
        .testTarget(
            name: "GenImageCoreTests",
            dependencies: ["GenImageCore"]
        ),
        .testTarget(
            name: "GenImageRuntimeTests",
            dependencies: ["GenImageCore", "GenImageRuntime"]
        ),
        .testTarget(
            name: "GenImageMCPServerTests",
            dependencies: ["GenImageMCPServer"]
        )
    ]
)
