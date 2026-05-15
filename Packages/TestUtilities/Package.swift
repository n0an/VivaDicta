// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TestUtilities",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TestUtilities", targets: ["TestUtilities"]),
    ],
    targets: [
        .target(name: "TestUtilities"),
    ]
)
