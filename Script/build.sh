#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f .root ]; then
    echo "[!] repository root not found"
    exit 1
fi

usage() {
    cat <<'EOF'
Usage: ./Script/build.sh [options]

Options:
  --platforms <csv>        Platform slices to build. Default: ios,iossimulator,maccatalyst
  --skip-fetch             Use existing ./References checkouts
  --skip-tests             Skip consumer verification
  --download-url <url>     Generate Package.swift from the template
  -h, --help               Show this help

Notes:
  - Fetches pinned upstreams, flattens them into one framework, then
    archives iOS / iOS Simulator / Mac Catalyst into Runestone.xcframework
  - Output: BinaryTarget/Runestone.xcframework and build/Runestone.xcframework.zip
EOF
}

PLATFORMS="ios,iossimulator,maccatalyst"
SKIP_FETCH=0
SKIP_TESTS=0
DOWNLOAD_URL=${DOWNLOAD_URL:-}

while [ $# -gt 0 ]; do
    case "$1" in
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --skip-fetch)
            SKIP_FETCH=1
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=1
            shift
            ;;
        --download-url)
            DOWNLOAD_URL="$2"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "[!] unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

ROOT_DIR=$PWD
ARCHIVE_DIR="$ROOT_DIR/build/archives"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
XCFRAMEWORK="$ROOT_DIR/BinaryTarget/Runestone.xcframework"
ZIP_PATH="$ROOT_DIR/build/Runestone.xcframework.zip"

if [ "$SKIP_FETCH" -eq 0 ]; then
    ./Script/fetch-upstream.sh
fi

python3 ./Script/assemble.py --root "$ROOT_DIR" --references "$ROOT_DIR/References"

rm -rf "$ARCHIVE_DIR" "$DERIVED_DATA" "$XCFRAMEWORK" "$ZIP_PATH"
mkdir -p "$ARCHIVE_DIR" "$(dirname "$XCFRAMEWORK")"

format_output() {
    if command -v xcbeautify >/dev/null 2>&1; then
        xcbeautify
    else
        cat
    fi
}

archive_platform() {
    local name="$1"
    local destination="$2"
    local extra_archs="${3:-}"
    local archive_path="$ARCHIVE_DIR/$name.xcarchive"

    echo "[*] archiving $name ($destination)"
    local command=(
        xcodebuild archive
        -project "$ROOT_DIR/Runestone.xcodeproj"
        -scheme Runestone
        -destination "$destination"
        -archivePath "$archive_path"
        -derivedDataPath "$DERIVED_DATA"
        -configuration Release
        SKIP_INSTALL=NO
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES
        ONLY_ACTIVE_ARCH=NO
        COMPILER_INDEX_STORE_ENABLE=NO
    )
    if [ -n "$extra_archs" ]; then
        command+=(ARCHS="$extra_archs")
    fi

    "${command[@]}" 2>&1 | format_output
    local exit_code=${PIPESTATUS[0]}
    if [ "$exit_code" -ne 0 ]; then
        echo "[!] archive failed: $name"
        exit "$exit_code"
    fi

    local framework="$archive_path/Products/Library/Frameworks/Runestone.framework"
    if [ ! -d "$framework" ]; then
        echo "[!] framework missing from $name archive: $framework"
        find "$archive_path/Products" -maxdepth 5 -print
        exit 1
    fi
    printf '%s' "$framework" >"$ARCHIVE_DIR/$name.frameworkpath"
}

XCFRAMEWORK_ARGS=()
IFS=',' read -r -a PLATFORM_LIST <<<"$PLATFORMS"
for platform in "${PLATFORM_LIST[@]}"; do
    case "$platform" in
        ios)
            archive_platform "ios" "generic/platform=iOS" "arm64"
            XCFRAMEWORK_ARGS+=("-framework" "$(cat "$ARCHIVE_DIR/ios.frameworkpath")")
            ;;
        iossimulator)
            archive_platform "ios-simulator" "generic/platform=iOS Simulator" "arm64 x86_64"
            XCFRAMEWORK_ARGS+=("-framework" "$(cat "$ARCHIVE_DIR/ios-simulator.frameworkpath")")
            ;;
        maccatalyst)
            archive_platform "maccatalyst" "generic/platform=macOS,variant=Mac Catalyst" "arm64 x86_64"
            XCFRAMEWORK_ARGS+=("-framework" "$(cat "$ARCHIVE_DIR/maccatalyst.frameworkpath")")
            ;;
        *)
            echo "[!] unknown platform: $platform"
            exit 1
            ;;
    esac
done

echo "[*] creating xcframework"
xcodebuild -create-xcframework \
    "${XCFRAMEWORK_ARGS[@]}" \
    -output "$XCFRAMEWORK"

./Script/verify-xcframework.sh "$XCFRAMEWORK"

(
    cd "$(dirname "$XCFRAMEWORK")"
    ditto -c -k --sequesterRsrc --keepParent "$(basename "$XCFRAMEWORK")" "$(basename "$ZIP_PATH")"
)
mv "$(dirname "$XCFRAMEWORK")/$(basename "$ZIP_PATH")" "$ZIP_PATH"
echo "[*] packed $ZIP_PATH"

if [ -n "$DOWNLOAD_URL" ]; then
    ./Script/build-manifest.sh "$ZIP_PATH" "$DOWNLOAD_URL"
else
    cp Package.local.swift Package.swift
fi

if [ "$SKIP_TESTS" -eq 0 ]; then
    ./Script/test-xcframework-consumer.sh "$XCFRAMEWORK"
fi

echo "[*] build complete"
echo "    $XCFRAMEWORK"
echo "    $ZIP_PATH"
