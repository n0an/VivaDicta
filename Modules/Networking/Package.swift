// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "NetworkingMocks", targets: ["NetworkingMocks"]),
    ],
    dependencies: [
        .package(path: "../TestUtilities"),
    ],
    targets: [
        .target(name: "Networking"),
        .target(
            name: "NetworkingMocks",
            dependencies: [
                "Networking",
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
        .testTarget(
            name: "NetworkingTests",
            dependencies: [
                "Networking",
                "NetworkingMocks",
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
