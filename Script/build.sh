#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f Upstream.versions ]; then
    echo "[!] repository root not found"
    exit 1
fi

usage() {
    cat <<'EOF'
Usage: ./Script/build.sh [options]

Options:
  --platforms <csv>        Platform slices to build.
                           Default: ios,iossimulator,maccatalyst,visionos,visionossimulator
  --skip-fetch             Use existing ./References checkouts
  --skip-tests             Skip consumer verification
  -h, --help               Show this help

Notes:
  - Fetches pinned upstreams, flattens them into one framework, then archives
    every platform slice into Runestone.xcframework
  - Output: BinaryTarget/Runestone.xcframework and build/Runestone.xcframework.zip
  - Points Package.swift at the local BinaryTarget; Script/build-manifest.sh
    writes the release manifest
EOF
}

PLATFORMS="ios,iossimulator,maccatalyst,visionos,visionossimulator"
SKIP_FETCH=0
SKIP_TESTS=0

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
        -project "$ROOT_DIR/build/Runestone.xcodeproj"
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

    if ! "${command[@]}" 2>&1 | format_output; then
        echo "[!] archive failed: $name"
        exit 1
    fi

    local framework="$archive_path/Products/Library/Frameworks/Runestone.framework"
    if [ ! -d "$framework" ]; then
        echo "[!] framework missing from $name archive: $framework"
        find "$archive_path/Products" -maxdepth 5 -print
        exit 1
    fi
    XCFRAMEWORK_ARGS+=("-framework" "$framework")
}

XCFRAMEWORK_ARGS=()
IFS=',' read -r -a PLATFORM_LIST <<<"$PLATFORMS"
for platform in "${PLATFORM_LIST[@]}"; do
    case "$platform" in
        ios)
            archive_platform "ios" "generic/platform=iOS" "arm64"
            ;;
        iossimulator)
            archive_platform "ios-simulator" "generic/platform=iOS Simulator" "arm64 x86_64"
            ;;
        maccatalyst)
            archive_platform "maccatalyst" "generic/platform=macOS,variant=Mac Catalyst" "arm64 x86_64"
            ;;
        visionos)
            archive_platform "visionos" "generic/platform=visionOS" "arm64"
            ;;
        visionossimulator)
            archive_platform "visionos-simulator" "generic/platform=visionOS Simulator" "arm64 x86_64"
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

sed -e 's|url: "__DOWNLOAD_URL__",|path: "BinaryTarget/Runestone.xcframework"|' \
    -e '/checksum: "__CHECKSUM__"/d' \
    Package.swift.template >Package.swift

if [ "$SKIP_TESTS" -eq 0 ]; then
    ./Script/test-xcframework-consumer.sh "$XCFRAMEWORK"
fi

echo "[*] build complete"
echo "    $XCFRAMEWORK"
echo "    $ZIP_PATH"
