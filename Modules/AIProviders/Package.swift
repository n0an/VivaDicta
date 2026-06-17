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
        .package(path: "../Networking"),
        .package(path: "../OAuth"),
    ],
    targets: [
        .target(
            name: "AIProviders",
            dependencies: [
                .product(name: "AICore", package: "AICore"),
                .product(name: "Networking", package: "Networking"),
                .product(name: "OAuth", package: "OAuth"),
            ]
        ),
        .testTarget(
            name: "AIProvidersTests",
            dependencies: [
                "AIProviders",
                .product(name: "AICore", package: "AICore"),
                .product(name: "Networking", package: "Networking"),
                .product(name: "NetworkingMocks", package: "Networking"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
