// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LightoffReading",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.3")
    ],
    targets: [
        .executableTarget(
            name: "LightoffReading",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        )
    ]
)
