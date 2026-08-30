#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f .root ]; then
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

    if [ -d "$dest/.git" ]; then
        echo "[*] updating $name at $ref"
        git -C "$dest" fetch --depth 1 origin "$ref" 2>/dev/null || git -C "$dest" fetch origin "$ref"
        git -C "$dest" checkout --detach "$ref"
    else
        echo "[*] cloning $name ($repo @ $ref)"
        rm -rf "$dest"
        if git clone --depth 1 --branch "$ref" "$repo" "$dest" 2>/dev/null; then
            :
        else
            git clone "$repo" "$dest"
            git -C "$dest" checkout "$ref"
        fi
    fi

    local resolved
    resolved=$(git -C "$dest" rev-parse HEAD)
    if [ "$resolved" != "$ref" ] && ! git -C "$dest" describe --tags --exact-match "$resolved" >/dev/null 2>&1; then
        echo "[*] $name resolved to $resolved (requested $ref)"
    fi
}

clone_pinned "Runestone" "$RUNESTONE_REPO" "$RUNESTONE_REF"
clone_pinned "RunestoneEditor" "$RUNESTONE_EDITOR_REPO" "$RUNESTONE_EDITOR_REF"

echo "[*] upstream checkouts ready in $REFERENCES_DIR"
