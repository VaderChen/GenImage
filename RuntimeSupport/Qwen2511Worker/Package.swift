// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GenImageQwen2511Worker",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "GenImageQwen2511Worker", targets: ["GenImageQwen2511Worker"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/xocialize/qwen-image-edit-swift.git",
            exact: "0.7.2"
        ),
        .package(
            url: "https://github.com/ml-explore/mlx-swift.git",
            exact: "0.31.6"
        )
    ],
    targets: [
        .executableTarget(
            name: "GenImageQwen2511Worker",
            dependencies: [
                .product(name: "QwenImageEdit", package: "qwen-image-edit-swift"),
                .product(name: "MLX", package: "mlx-swift")
            ]
        )
    ]
)
