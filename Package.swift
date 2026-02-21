// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CloudDrop",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "CloudDrop",
            path: "Sources/CloudDrop"
        ),
    ]
)
