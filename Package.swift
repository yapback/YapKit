// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YapKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
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
