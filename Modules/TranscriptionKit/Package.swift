// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TranscriptionKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TranscriptionKit", targets: ["TranscriptionKit"]),
        .library(name: "TranscriptionKitMocks", targets: ["TranscriptionKitMocks"]),
    ],
    dependencies: [
        .package(path: "../TranscriptionCore"),
        .package(path: "../CloudTranscription"),
        .package(path: "../LocalTranscription"),
        .package(path: "../Networking"),
        .package(path: "../TestUtilities"),
    ],
    targets: [
        .target(
            name: "TranscriptionKit",
            dependencies: [
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
                .product(name: "CloudTranscription", package: "CloudTranscription"),
                .product(name: "LocalTranscription", package: "LocalTranscription"),
                // Direct dependency on Networking required so the linker can
                // resolve the `URLSession: URLSessionProtocol` witness table
                // referenced by CloudTranscription service initializers with
                // their default `urlSession: URLSessionProtocol = URLSession.shared`.
                // SPM doesn't propagate this transitive conformance link
                // through the umbrella in every build context.
                .product(name: "Networking", package: "Networking"),
            ]
        ),
        .target(
            name: "TranscriptionKitMocks",
            dependencies: [
                "TranscriptionKit",
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
        .testTarget(
            name: "TranscriptionKitTests",
            dependencies: [
                "TranscriptionKit",
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
                .product(name: "CloudTranscriptionMocks", package: "CloudTranscription"),
                .product(name: "LocalTranscriptionMocks", package: "LocalTranscription"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
