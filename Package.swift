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
        // The XCFramework is static, so the products above link Runestone into
        // every binary that depends on them. This one vends the same modules as
        // a single dynamic framework instead — the one place a Runestone dylib
        // exists. Use it, or the products above, not both.
        .library(
            name: "RunestoneDynamic",
            type: .dynamic,
            targets: ["RunestoneEditor", "RunestoneLanguageSupport", "RunestoneThemeSupport"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "Runestone",
            url: "https://github.com/Lakr233/Runestone.xcframework/releases/download/upstream.0.5.2-3/Runestone.xcframework.zip",
            checksum: "7dcc4fc94bd33c4e8963c37373ecb2d21640f33d999abd9549ff972bbc01913d"
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
