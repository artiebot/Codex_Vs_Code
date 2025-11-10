// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SkyFeederUI",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "SkyFeederUI", targets: ["SkyFeederUI"])
    ],
    targets: [
        .target(
            name: "SkyFeederUI",
            path: "Sources",
            resources: []
        ),
        .testTarget(
            name: "SkyFeederUITests",
            dependencies: ["SkyFeederUI"],
            path: "Tests"
        )
    ]
)
