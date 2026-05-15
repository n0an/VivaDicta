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
            dependencies: ["Presets", "PresetsMocks"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
