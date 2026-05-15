// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Keychain",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Keychain", targets: ["Keychain"]),
        .library(name: "KeychainMocks", targets: ["KeychainMocks"]),
    ],
    dependencies: [
        .package(path: "../TestUtilities"),
    ],
    targets: [
        .target(
            name: "Keychain"
        ),
        .target(
            name: "KeychainMocks",
            dependencies: [
                "Keychain",
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
        .testTarget(
            name: "KeychainTests",
            dependencies: [
                "Keychain",
                "KeychainMocks",
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
    ]
)
