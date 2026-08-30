#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f Upstream.versions ]; then
    echo "[!] repository root not found"
    exit 1
fi

# shellcheck disable=SC1091
source ./Upstream.versions

REFERENCES_DIR=${1:-"$PWD/References"}
mkdir -p "$REFERENCES_DIR"

clone_pinned() {
    local name="$1"
    local repo="$2"
    local ref="$3"
    local dest="$REFERENCES_DIR/$name"

    if [ ! -d "$dest/.git" ]; then
        rm -rf "$dest"
        git init -q "$dest"
        git -C "$dest" remote add origin "$repo"
    fi

    echo "[*] fetching $name ($repo @ $ref)"
    git -C "$dest" fetch --depth 1 origin "$ref" 2>/dev/null || git -C "$dest" fetch origin "$ref"
    git -C "$dest" checkout --detach "$ref"

    local resolved
    resolved=$(git -C "$dest" rev-parse HEAD)
    if [ "$resolved" != "$ref" ]; then
        echo "[!] $name resolved to $resolved, pinned $ref"
        exit 1
    fi
}

clone_pinned "Runestone" "$RUNESTONE_REPO" "$RUNESTONE_REF"
clone_pinned "RunestoneEditor" "$RUNESTONE_EDITOR_REPO" "$RUNESTONE_EDITOR_REF"

echo "[*] upstream checkouts ready in $REFERENCES_DIR"
