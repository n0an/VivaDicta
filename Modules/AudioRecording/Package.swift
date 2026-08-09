// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AudioRecording",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AudioRecording", targets: ["AudioRecording"]),
        .library(name: "AudioRecordingMocks", targets: ["AudioRecordingMocks"]),
    ],
    dependencies: [
        .package(path: "../AppGroup"),
        .package(path: "../TestUtilities"),
    ],
    targets: [
        .target(
            name: "AudioRecording",
            dependencies: [
                .product(name: "AppGroup", package: "AppGroup"),
            ]
        ),
        .target(
            name: "AudioRecordingMocks",
            dependencies: [
                "AudioRecording",
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
        .testTarget(
            name: "AudioRecordingTests",
            dependencies: [
                "AudioRecording",
                "AudioRecordingMocks",
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
