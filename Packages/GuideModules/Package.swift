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
    dependencies: [
        .package(
            url: "https://github.com/getsentry/sentry-cocoa.git",
            exact: "9.27.0"
        )
    ],
    targets: [
        .target(name: "GuideCore"),
        .target(
            name: "GuideMac",
            dependencies: [
                "GuideCore",
                .product(name: "Sentry", package: "sentry-cocoa")
            ]
        ),
        .target(
            name: "GuideUI",
            dependencies: ["GuideCore", "GuideMac"]
        ),
        .testTarget(
            name: "GuideCoreTests",
            dependencies: ["GuideCore", "GuideMac", "GuideUI"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "GuideMacTests",
            dependencies: ["GuideCore", "GuideMac"]
        )
    ]
)
