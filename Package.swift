// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Runestone",
    platforms: [
        .iOS(.v15),
        .macCatalyst(.v15),
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
            path: "BinaryTarget/Runestone.xcframework"
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
    ]
)
