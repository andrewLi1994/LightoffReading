// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LightoffReading",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "LightoffReading"
        )
    ]
)
