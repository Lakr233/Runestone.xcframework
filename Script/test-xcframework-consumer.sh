#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f Upstream.versions ]; then
    echo "[!] repository root not found"
    exit 1
fi

XCFRAMEWORK_PATH=${1:-BinaryTarget/Runestone.xcframework}

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    echo "[!] xcframework not found: $XCFRAMEWORK_PATH"
    exit 1
fi

format_output() {
    if command -v xcbeautify >/dev/null 2>&1; then
        xcbeautify
    else
        cat
    fi
}

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$WORK_DIR/Consumer/BinaryTarget" \
    "$WORK_DIR/Consumer/Sources/Consumer"
ditto "$XCFRAMEWORK_PATH" "$WORK_DIR/Consumer/BinaryTarget/Runestone.xcframework"

cat >"$WORK_DIR/Consumer/Package.swift" <<'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Consumer",
    platforms: [
        .iOS(.v15),
        .macCatalyst(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Consumer", targets: ["Consumer"]),
    ],
    targets: [
        .binaryTarget(
            name: "Runestone",
            path: "BinaryTarget/Runestone.xcframework"
        ),
        .target(
            name: "Consumer",
            dependencies: ["Runestone"],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
    ]
)
EOF

cat >"$WORK_DIR/Consumer/Sources/Consumer/Consumer.swift" <<'EOF'
import Runestone
import UIKit

public func makeEditor() -> RunestoneEditorView {
    let textView = RunestoneEditorView.new()
    textView.apply(theme: TomorrowTheme())
    if let language = TreeSitterLanguage.language(withIdentifier: "swift") {
        textView.apply(language: language)
    }
    return textView
}
EOF

test_build() {
    local destination="$1"
    echo "[*] consumer build destination=$destination"
    if ! xcodebuild \
        -scheme Consumer \
        -destination "$destination" \
        -derivedDataPath "$WORK_DIR/DerivedData" \
        -packageCachePath "$WORK_DIR/PackageCache" \
        build 2>&1 | format_output; then
        echo "[!] consumer build failed destination=$destination"
        exit 1
    fi
}

(
    cd "$WORK_DIR/Consumer"
    test_build "generic/platform=iOS"
    test_build "generic/platform=iOS Simulator"
    test_build "generic/platform=macOS,variant=Mac Catalyst"
    test_build "generic/platform=visionOS"
    test_build "generic/platform=visionOS Simulator"
)

echo "[*] xcframework consumer tests passed"
