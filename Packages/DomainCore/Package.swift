// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DomainCore",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DomainCore",
            targets: ["DomainCore"]
        )
    ],
    targets: [
        .target(
            name: "DomainCore"
        ),
        .testTarget(
            name: "DomainCoreTests",
            dependencies: ["DomainCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
