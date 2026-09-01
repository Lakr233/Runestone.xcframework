#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f Upstream.versions ]; then
    echo "[!] Repository root not found. Run this script from a full checkout of the repository."
    exit 1
fi

INPUT_PATH=${1:-}

if [ -z "$INPUT_PATH" ]; then
    echo "Usage: $0 <xcframework_or_zip>"
    exit 1
fi

if [ ! -e "$INPUT_PATH" ]; then
    echo "[!] Path not found: $INPUT_PATH"
    exit 1
fi

TEMP_DIR=
XCFRAMEWORK_PATH="$INPUT_PATH"

cleanup() {
    if [ -n "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

if [[ "$INPUT_PATH" == *.zip ]]; then
    TEMP_DIR=$(mktemp -d)
    ditto -x -k "$INPUT_PATH" "$TEMP_DIR"
    XCFRAMEWORK_PATH=$(find "$TEMP_DIR" -maxdepth 1 -name "*.xcframework" -type d | head -1)
fi

if [ -z "$XCFRAMEWORK_PATH" ] || [ ! -d "$XCFRAMEWORK_PATH" ]; then
    echo "[!] No xcframework found in $INPUT_PATH"
    exit 1
fi

python3 - "$XCFRAMEWORK_PATH" <<'PY'
import os
import plistlib
import subprocess
import sys

xcframework = sys.argv[1]
info_path = os.path.join(xcframework, "Info.plist")
if not os.path.isfile(info_path):
    raise SystemExit("[!] The xcframework is incomplete. Rebuild it and try again.")

with open(info_path, "rb") as handle:
    info = plistlib.load(handle)

libraries = info.get("AvailableLibraries")
if not isinstance(libraries, list) or not libraries:
    raise SystemExit("[!] The xcframework lists no libraries. Rebuild it and try again.")

expected = {
    ("ios", None): {"arm64"},
    ("ios", "simulator"): {"arm64", "x86_64"},
    ("ios", "maccatalyst"): {"arm64", "x86_64"},
    ("xros", None): {"arm64"},
    ("xros", "simulator"): {"arm64", "x86_64"},
}

for library in libraries:
    identifier = library.get("LibraryIdentifier")
    library_path = library.get("LibraryPath")
    platform = library.get("SupportedPlatform")
    platform_variant = library.get("SupportedPlatformVariant")
    declared = set(library.get("SupportedArchitectures", []))

    if not identifier:
        raise SystemExit("[!] The xcframework metadata is incomplete. Rebuild it and try again.")
    if (platform, platform_variant) not in expected:
        raise SystemExit(f"[!] {identifier} targets an unsupported platform. Rebuild the xcframework and try again.")
    if library_path != "Runestone.framework":
        raise SystemExit(f"[!] {identifier} does not contain Runestone.framework. Rebuild the xcframework and try again.")

    variant_dir = os.path.join(xcframework, identifier)
    framework = os.path.join(variant_dir, library_path)
    binary = os.path.join(framework, "Runestone")
    if not os.path.isdir(framework):
        raise SystemExit(f"[!] {identifier} is missing Runestone.framework. Rebuild the xcframework and try again.")
    if not os.path.isfile(binary):
        raise SystemExit(f"[!] {identifier} is missing the Runestone binary. Rebuild the xcframework and try again.")

    actual = set(subprocess.check_output(["lipo", "-archs", binary], text=True).split())
    if actual != declared:
        raise SystemExit(
            f"[!] {identifier} declares different architectures than it contains. Rebuild the xcframework and try again."
        )
    wanted = expected.get((platform, platform_variant))
    if wanted is not None and actual != wanted:
        print(
            f"[*] {identifier} architectures {sorted(actual)} (expected {sorted(wanted) if wanted else 'any'})",
            file=sys.stderr,
        )

    swiftmodule = os.path.join(framework, "Modules", "Runestone.swiftmodule")
    if not os.path.isdir(swiftmodule):
        raise SystemExit(f"[!] {identifier} is missing its Swift module. Rebuild the xcframework and try again.")

print(f"[*] verified xcframework: {xcframework}")
print(f"[*] slices: {', '.join(identifier for identifier in os.listdir(xcframework) if identifier != 'Info.plist')}")
PY
