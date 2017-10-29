// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "neo4j-fluent-driver",
    products: [
        .library(
            name: "neo4j-fluent-driver",
            targets: ["neo4j-fluent-driver"]),
    ],
    dependencies: [
        .package(url: "https://github.com/niklassaers/neo4j-ios.git", .branch("feature/4.0.0")),
        .package(url: "https://github.com/vapor/fluent.git", from: "2.4.1"),
        // Random number generation
        //.package(url: "https://github.com/vapor/random.git", from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "neo4j-fluent-driver",
            dependencies: [.byNameItem(name: "Fluent"), .byNameItem(name: "Theo")]),
        .testTarget(
            name: "neo4j-fluent-driverTests",
            dependencies: ["neo4j-fluent-driver"]),
    ]
)
