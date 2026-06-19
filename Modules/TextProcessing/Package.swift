// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TextProcessing",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TextProcessing", targets: ["TextProcessing"]),
    ],
    targets: [
        .target(
            name: "TextProcessing"
        ),
        .testTarget(
            name: "TextProcessingTests",
            dependencies: ["TextProcessing"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
