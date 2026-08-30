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
            url: "https://github.com/Lakr233/Runestone.xcframework/releases/download/storage.0.2.0/Runestone.xcframework.zip",
            checksum: "25c19bad885c9b1d41ab7fe334a2c2934d520563af2f3d80cbef8677b4d1f6b4"
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
            dependencies: ["Runestone"]
        ),
        .target(
            name: "RunestoneThemeSupport",
            dependencies: ["Runestone"]
        ),
        .testTarget(
            name: "RunestoneTests",
            dependencies: ["Runestone", "RunestoneEditor", "RunestoneLanguageSupport", "RunestoneThemeSupport"]
        ),
    ]
)
