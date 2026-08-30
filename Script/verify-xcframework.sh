#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f .root ]; then
    echo "[!] repository root not found"
    exit 1
fi

INPUT_PATH=${1:-}

if [ -z "$INPUT_PATH" ]; then
    echo "Usage: $0 <xcframework_or_zip>"
    exit 1
fi

if [ ! -e "$INPUT_PATH" ]; then
    echo "[!] not found: $INPUT_PATH"
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
    echo "[!] xcframework not found in input: $INPUT_PATH"
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
    raise SystemExit(f"[!] missing xcframework Info.plist: {info_path}")

with open(info_path, "rb") as handle:
    info = plistlib.load(handle)

libraries = info.get("AvailableLibraries")
if not isinstance(libraries, list) or not libraries:
    raise SystemExit("[!] AvailableLibraries is empty or missing")

expected = {
    ("ios", None): {"arm64"},
    ("ios", "simulator"): {"arm64", "x86_64"},
    ("ios", "maccatalyst"): {"arm64", "x86_64"},
}

seen = set()
for library in libraries:
    identifier = library.get("LibraryIdentifier")
    library_path = library.get("LibraryPath")
    platform = library.get("SupportedPlatform")
    platform_variant = library.get("SupportedPlatformVariant")
    declared = set(library.get("SupportedArchitectures", []))
    seen.add((platform, platform_variant))

    if not identifier:
        raise SystemExit("[!] library entry missing LibraryIdentifier")
    if platform != "ios":
        raise SystemExit(f"[!] unsupported platform in {identifier}: {platform}")
    if library_path != "Runestone.framework":
        raise SystemExit(f"[!] {identifier} must reference Runestone.framework, got {library_path!r}")

    variant_dir = os.path.join(xcframework, identifier)
    framework = os.path.join(variant_dir, library_path)
    binary = os.path.join(framework, "Runestone")
    if not os.path.isdir(framework):
        raise SystemExit(f"[!] missing framework: {framework}")
    if not os.path.isfile(binary):
        raise SystemExit(f"[!] missing framework binary: {binary}")

    actual = set(subprocess.check_output(["lipo", "-archs", binary], text=True).split())
    if actual != declared:
        raise SystemExit(
            f"[!] {identifier} architecture metadata mismatch: plist={sorted(declared)} binary={sorted(actual)}"
        )
    wanted = expected.get((platform, platform_variant))
    if wanted is not None and actual != wanted:
        print(
            f"[*] {identifier} architectures {sorted(actual)} (expected {sorted(wanted) if wanted else 'any'})",
            file=sys.stderr,
        )

    swiftmodule = os.path.join(framework, "Modules", "Runestone.swiftmodule")
    if not os.path.isdir(swiftmodule):
        raise SystemExit(f"[!] missing swiftmodule: {swiftmodule}")

print(f"[*] verified xcframework: {xcframework}")
print(f"[*] slices: {', '.join(identifier for identifier in os.listdir(xcframework) if identifier != 'Info.plist')}")
PY
