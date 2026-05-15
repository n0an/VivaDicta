// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OAuth",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "OAuth", targets: ["OAuth"]),
        .library(name: "OAuthMocks", targets: ["OAuthMocks"]),
    ],
    dependencies: [
        .package(path: "../Keychain"),
        .package(path: "../TestUtilities"),
    ],
    targets: [
        .target(
            name: "OAuth",
            dependencies: [
                .product(name: "Keychain", package: "Keychain"),
            ]
        ),
        .target(
            name: "OAuthMocks",
            dependencies: [
                "OAuth",
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
        .testTarget(
            name: "OAuthTests",
            dependencies: [
                "OAuth",
                "OAuthMocks",
                .product(name: "KeychainMocks", package: "Keychain"),
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
