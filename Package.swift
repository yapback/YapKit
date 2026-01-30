// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YapKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "YapKit",
            targets: ["YapKit"]
        ),
    ],
    targets: [
        .target(
            name: "YapKit"
        ),
        .testTarget(
            name: "YapKitTests",
            dependencies: ["YapKit"]
        ),
    ]
)
