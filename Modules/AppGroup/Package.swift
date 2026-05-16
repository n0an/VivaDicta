// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AppGroup",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AppGroup", targets: ["AppGroup"]),
    ],
    targets: [
        .target(name: "AppGroup"),
        .testTarget(
            name: "AppGroupTests",
            dependencies: ["AppGroup"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
