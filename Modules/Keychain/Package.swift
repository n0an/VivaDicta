// swift-tools-version: 6.2

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
    targets: [
        .target(
            name: "Keychain"
        ),
        .target(
            name: "KeychainMocks",
            dependencies: ["Keychain"]
        ),
        .testTarget(
            name: "KeychainTests",
            dependencies: ["Keychain", "KeychainMocks"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
