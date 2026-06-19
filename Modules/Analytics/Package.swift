// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Analytics",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Analytics", targets: ["Analytics"]),
        .library(name: "AnalyticsMocks", targets: ["AnalyticsMocks"]),
    ],
    targets: [
        .target(
            name: "Analytics"
        ),
        .target(
            name: "AnalyticsMocks",
            dependencies: ["Analytics"]
        ),
        .testTarget(
            name: "AnalyticsTests",
            dependencies: ["Analytics", "AnalyticsMocks"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
