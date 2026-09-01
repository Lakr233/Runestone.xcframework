#!/bin/bash

# Resolves a simonbs/Runestone version to the commit it should be built from.
#
#   ./Script/resolve-upstream.sh                 the pin in Upstream.versions
#   ./Script/resolve-upstream.sh latest          highest semver tag on RUNESTONE_REPO
#   ./Script/resolve-upstream.sh 0.5.3           that tag
#   ./Script/resolve-upstream.sh latest --write  also rewrite the pin in Upstream.versions
#
# stdout is eval-able: RUNESTONE_VERSION=<version> and RUNESTONE_REF=<sha>.
# Everything else goes to stderr.

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f Upstream.versions ]; then
    echo "[!] repository root not found" >&2
    exit 1
fi

# shellcheck disable=SC1091
source ./Upstream.versions

REQUESTED=""
WRITE=0
for arg in "$@"; do
    case "$arg" in
        --write) WRITE=1 ;;
        *) REQUESTED=$arg ;;
    esac
done

if [ -z "$REQUESTED" ]; then
    VERSION=$RUNESTONE_VERSION
    REF=$RUNESTONE_REF
else
    TAGS=$(git ls-remote --tags "$RUNESTONE_REPO")
    if [ "$REQUESTED" = "latest" ]; then
        VERSION=$(echo "$TAGS" | sed -n 's|.*refs/tags/\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$|\1|p' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
        if [ -z "$VERSION" ]; then
            echo "[!] no semantic tags on $RUNESTONE_REPO" >&2
            exit 1
        fi
    else
        VERSION=$REQUESTED
    fi
    if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "[!] version must be semantic, for example 0.5.2: $VERSION" >&2
        exit 1
    fi
    # Annotated tags list both the tag object and the peeled commit (^{}); prefer the commit.
    REF=$(echo "$TAGS" | awk -v t="refs/tags/$VERSION^{}" '$2 == t { print $1 }')
    if [ -z "$REF" ]; then
        REF=$(echo "$TAGS" | awk -v t="refs/tags/$VERSION" '$2 == t { print $1 }')
    fi
    if [ -z "$REF" ]; then
        echo "[!] tag $VERSION not found on $RUNESTONE_REPO" >&2
        exit 1
    fi
fi

echo "RUNESTONE_VERSION=$VERSION"
echo "RUNESTONE_REF=$REF"

if [ "$WRITE" -eq 1 ]; then
    # Only the two pin lines change; the file keeps its own comments.
    sed -e "s|^RUNESTONE_VERSION=.*|RUNESTONE_VERSION=$VERSION|" \
        -e "s|^RUNESTONE_REF=.*|RUNESTONE_REF=$REF|" \
        Upstream.versions >Upstream.versions.tmp
    mv Upstream.versions.tmp Upstream.versions
    echo "[*] Upstream.versions pinned to simonbs/Runestone $VERSION ($REF)" >&2
fi
