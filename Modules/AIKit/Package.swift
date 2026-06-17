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
        // AIKit depends on the AICore API only - never on AIProviders (the impl).
        // The composition root injects concrete providers into AIKit's registry.
        .package(path: "../AICore"),
    ],
    targets: [
        .target(
            name: "AIKit",
            dependencies: [
                .product(name: "AICore", package: "AICore"),
            ]
        ),
        .testTarget(
            name: "AIKitTests",
            dependencies: ["AIKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
