// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Persistence",
            targets: ["Persistence"]
        )
    ],
    dependencies: [
        .package(path: "../DomainCore")
    ],
    targets: [
        .target(
            name: "Persistence",
            dependencies: ["DomainCore"]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence", "DomainCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
