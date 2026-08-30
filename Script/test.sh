#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f .root ]; then
    echo "[!] repository root not found"
    exit 1
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/clang-module-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/tmp/swiftpm-module-cache}"

format_output() {
    if command -v xcbeautify >/dev/null 2>&1; then
        xcbeautify
    else
        cat
    fi
}

test_build() {
    local destination="$1"

    echo "[*] build scheme=MobileRunestoneApp destination=$destination"
    xcodebuild \
        -project Example/MobileRunestoneApp.xcodeproj \
        -scheme MobileRunestoneApp \
        -destination "$destination" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        build 2>&1 | format_output
    local exit_code=${PIPESTATUS[0]}
    if [ "$exit_code" -ne 0 ]; then
        echo "[!] failed destination=$destination"
        exit "$exit_code"
    fi
}

if [ ! -d BinaryTarget/Runestone.xcframework ]; then
    echo "[!] BinaryTarget/Runestone.xcframework is missing. Run ./Script/build.sh first."
    exit 1
fi

test_build "generic/platform=iOS"
test_build "generic/platform=iOS Simulator"
test_build "generic/platform=macOS,variant=Mac Catalyst"

echo "[*] all tests passed"
