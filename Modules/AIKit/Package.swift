// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AIKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AIKit", targets: ["AIKit"]),
    ],
    dependencies: [
        // AIKit is the AI orchestration module: it builds and routes providers,
        // so it depends on the provider impls + the infra they need (mirroring
        // how TranscriptionKit depends on Cloud/Local transcription).
        .package(path: "../AICore"),
        .package(path: "../AIProviders"),
        .package(path: "../Keychain"),
        .package(path: "../OAuth"),
        .package(path: "../Networking"),
    ],
    targets: [
        .target(
            name: "AIKit",
            dependencies: [
                .product(name: "AICore", package: "AICore"),
                .product(name: "AIProviders", package: "AIProviders"),
                .product(name: "Keychain", package: "Keychain"),
                .product(name: "OAuth", package: "OAuth"),
                .product(name: "Networking", package: "Networking"),
            ]
        ),
        .testTarget(
            name: "AIKitTests",
            dependencies: [
                "AIKit",
                .product(name: "AICore", package: "AICore"),
                .product(name: "AIProviders", package: "AIProviders"),
                .product(name: "KeychainMocks", package: "Keychain"),
                .product(name: "OAuthMocks", package: "OAuth"),
                .product(name: "NetworkingMocks", package: "Networking"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
