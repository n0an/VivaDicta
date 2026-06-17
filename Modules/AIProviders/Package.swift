// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AIProviders",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AIProviders", targets: ["AIProviders"]),
    ],
    dependencies: [
        .package(path: "../AICore"),
    ],
    targets: [
        .target(
            name: "AIProviders",
            dependencies: [
                .product(name: "AICore", package: "AICore"),
            ]
        ),
        .testTarget(
            name: "AIProvidersTests",
            dependencies: ["AIProviders"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
