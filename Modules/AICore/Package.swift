// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AICore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AICore", targets: ["AICore"]),
    ],
    targets: [
        .target(name: "AICore"),
        .testTarget(
            name: "AICoreTests",
            dependencies: ["AICore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
