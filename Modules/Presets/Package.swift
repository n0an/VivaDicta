// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Presets",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Presets", targets: ["Presets"]),
        .library(name: "PresetsMocks", targets: ["PresetsMocks"]),
    ],
    dependencies: [
        .package(path: "../TestUtilities"),
    ],
    targets: [
        .target(
            name: "Presets"
        ),
        .target(
            name: "PresetsMocks",
            dependencies: ["Presets"]
        ),
        .testTarget(
            name: "PresetsTests",
            dependencies: [
                "Presets",
                "PresetsMocks",
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
