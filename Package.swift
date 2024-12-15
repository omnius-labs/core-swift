// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OmniusCore",
    products: [
        .library(
            name: "OmniusCore",
            targets: ["Base", "RocketPack"])
    ],
    targets: [
        .target(
            name: "Base"),
        .target(
            name: "RocketPack"),
        .testTarget(
            name: "BaseTests",
            dependencies: ["Base"]
        ),
        .testTarget(
            name: "RocketPackTests",
            dependencies: ["Base", "RocketPack"]
        ),
    ]
)
