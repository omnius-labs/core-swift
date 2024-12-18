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
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.77.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "Base",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
            ]
        ),
        .target(
            name: "RocketPack",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
            ]
        ),
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
