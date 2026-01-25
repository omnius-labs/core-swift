// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OmniusCore",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "OmniusCore",
            targets: ["OmniusCoreBase", "OmniusCoreOmnikit", "OmniusCoreRocketPack"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.92.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.26.0"),
        .package(url: "https://github.com/groue/Semaphore.git", from: "0.1.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "OmniusCoreBase",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
            ],
            path: "Sources/Base",
        ),
        .target(
            name: "OmniusCoreOmnikit",
            dependencies: [
                "OmniusCoreBase",
                "OmniusCoreRocketPack",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
                "Semaphore",
                "CryptoSwift",
            ],
            path: "Sources/Omnikit",
        ),
        .target(
            name: "OmniusCoreRocketPack",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
            ],
            path: "Sources/RocketPack",
        ),
        .testTarget(
            name: "OmniusCoreBaseTests",
            dependencies: ["OmniusCoreBase"],
            path: "Tests/BaseTests",
        ),
        .testTarget(
            name: "OmniusCoreOmnikitTests",
            dependencies: ["OmniusCoreBase", "OmniusCoreOmnikit", "OmniusCoreRocketPack"],
            path: "Tests/OmnikitTests",
        ),
        .testTarget(
            name: "OmniusCoreRocketPackTests",
            dependencies: ["OmniusCoreBase", "OmniusCoreRocketPack"],
            path: "Tests/RocketPackTests",
        ),
    ]
)
