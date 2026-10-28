// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DayCue",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DayCue", targets: ["DayCue"])
    ],
    targets: [
        .executableTarget(name: "DayCue")
    ]
)
