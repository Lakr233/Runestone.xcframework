#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f Upstream.versions ]; then
    echo "[!] repository root not found"
    exit 1
fi

# Links whatever Package.swift points at: the released binary on a fresh
# checkout, BinaryTarget/Runestone.xcframework after ./Script/build.sh.

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/clang-module-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/tmp/swiftpm-module-cache}"

format_output() {
    if command -v xcbeautify >/dev/null 2>&1; then
        xcbeautify
    else
        cat
    fi
}

run() {
    echo "[*] $*"
    if ! "$@" 2>&1 | format_output; then
        echo "[!] failed: $*"
        exit 1
    fi
}

for destination in "generic/platform=iOS" "generic/platform=iOS Simulator" "generic/platform=macOS,variant=Mac Catalyst" \
    "generic/platform=visionOS" "generic/platform=visionOS Simulator"; do
    run xcodebuild -scheme Runestone-Package -destination "$destination" build
done

for destination in "generic/platform=iOS" "generic/platform=iOS Simulator" "generic/platform=macOS,variant=Mac Catalyst"; do
    run xcodebuild -project Example/MobileRunestoneApp.xcodeproj -scheme MobileRunestoneApp -destination "$destination" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
done

run xcodebuild -scheme Runestone-Package -destination "platform=macOS,variant=Mac Catalyst" test

echo "[*] all tests passed"
