// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Runestone",
    platforms: [
        .iOS(.v15),
        .macCatalyst(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Runestone", targets: ["Runestone"]),
        .library(name: "RunestoneEditor", targets: ["RunestoneEditor"]),
        .library(name: "RunestoneLanguageSupport", targets: ["RunestoneLanguageSupport"]),
        .library(name: "RunestoneThemeSupport", targets: ["RunestoneThemeSupport"]),
    ],
    targets: [
        .binaryTarget(
            name: "Runestone",
            url: "https://github.com/Lakr233/Runestone.xcframework/releases/download/upstream.0.5.2-4/Runestone.xcframework.zip",
            checksum: "995d274a337737c3f2ddb309709d57d1d1e7cb00a3072a9605b7fd4306bc30dd"
        ),
        .target(
            name: "RunestoneEditor",
            dependencies: ["Runestone"],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
        .target(
            name: "RunestoneLanguageSupport",
            dependencies: ["Runestone"],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
        .target(
            name: "RunestoneThemeSupport",
            dependencies: ["Runestone"],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
        .testTarget(
            name: "RunestoneTests",
            dependencies: ["Runestone", "RunestoneEditor", "RunestoneLanguageSupport", "RunestoneThemeSupport"]
        ),
    ]
)
