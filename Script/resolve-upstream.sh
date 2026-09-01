#!/bin/bash

# Resolves a simonbs/Runestone version to the commit it should be built from.
#
#   ./Script/resolve-upstream.sh                 the pin in Upstream.versions
#   ./Script/resolve-upstream.sh latest          highest semver tag on RUNESTONE_REPO
#   ./Script/resolve-upstream.sh 0.5.3           that tag
#   ./Script/resolve-upstream.sh latest --write  also rewrite the pin in Upstream.versions
#   ./Script/resolve-upstream.sh 0.5.3 --ref <sha> --write
#                                                pin exactly this version/commit, no lookup
#                                                (CI writes the pair its plan job resolved)
#
# stdout is eval-able: RUNESTONE_VERSION=<version> and RUNESTONE_REF=<sha>.
# Everything else goes to stderr.

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f Upstream.versions ]; then
    echo "[!] Repository root not found. Run this script from a full checkout of the repository." >&2
    exit 1
fi

# shellcheck disable=SC1091
source ./Upstream.versions

REQUESTED=""
REQUESTED_REF=""
WRITE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --write) WRITE=1 ;;
        --ref)
            shift
            REQUESTED_REF=${1:-}
            ;;
        *) REQUESTED=$1 ;;
    esac
    shift
done

if [ -n "$REQUESTED_REF" ]; then
    if ! echo "$REQUESTED" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "[!] --ref needs a semantic version too, for example 0.5.2. Received: $REQUESTED" >&2
        exit 1
    fi
    if ! echo "$REQUESTED_REF" | grep -Eq '^[0-9a-f]{40}$'; then
        echo "[!] --ref must be a full 40-character lowercase commit hash. Received: $REQUESTED_REF" >&2
        exit 1
    fi
    VERSION=$REQUESTED
    REF=$REQUESTED_REF
elif [ -z "$REQUESTED" ]; then
    VERSION=$RUNESTONE_VERSION
    REF=$RUNESTONE_REF
else
    TAGS=$(git ls-remote --tags "$RUNESTONE_REPO")
    if [ "$REQUESTED" = "latest" ]; then
        VERSION=$(echo "$TAGS" | sed -n 's|.*refs/tags/\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$|\1|p' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
        if [ -z "$VERSION" ]; then
            echo "[!] No semantic version tags found on $RUNESTONE_REPO. Pass a specific version instead." >&2
            exit 1
        fi
    else
        VERSION=$REQUESTED
    fi
    if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "[!] Version must be semantic, for example 0.5.2. Received: $VERSION" >&2
        exit 1
    fi
    # Annotated tags list both the tag object and the peeled commit (^{}); prefer the commit.
    REF=$(echo "$TAGS" | awk -v t="refs/tags/$VERSION^{}" '$2 == t { print $1 }')
    if [ -z "$REF" ]; then
        REF=$(echo "$TAGS" | awk -v t="refs/tags/$VERSION" '$2 == t { print $1 }')
    fi
    if [ -z "$REF" ]; then
        echo "[!] Version $VERSION was not found on $RUNESTONE_REPO. Check the version and try again." >&2
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
