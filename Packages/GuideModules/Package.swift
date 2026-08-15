// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GuideModules",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "GuideCore", targets: ["GuideCore"]),
        .library(name: "GuideMac", targets: ["GuideMac"]),
        .library(name: "GuideUI", targets: ["GuideUI"])
    ],
    targets: [
        .target(name: "GuideCore"),
        .target(
            name: "GuideMac",
            dependencies: ["GuideCore"]
        ),
        .target(
            name: "GuideUI",
            dependencies: ["GuideCore", "GuideMac"]
        ),
        .testTarget(
            name: "GuideCoreTests",
            dependencies: ["GuideCore", "GuideMac"]
        )
    ]
)
