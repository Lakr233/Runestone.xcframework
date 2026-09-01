#!/bin/bash

# Release tag helpers, read against the origin remote so answers match GitHub.
#
#   ./Script/next-tag.sh upstream [version]   upstream.<version>-<rev>, rev = highest existing + 1
#                                             (version defaults to RUNESTONE_VERSION in Upstream.versions)
#   ./Script/next-tag.sh has-upstream <version>
#                                             exit 0 if any upstream.<version>-<rev> tag exists, else 1
#   ./Script/next-tag.sh exists <tag>         exit 0 if the tag exists on origin, 1 if not
#   ./Script/next-tag.sh package              <major>.<minor>.<patch + 1> of the highest package tag
#
# Any other exit status means origin could not be listed; callers must not read
# that as "no".

set -euo pipefail

cd "$(dirname "$0")/.."
if [ ! -f Upstream.versions ]; then
    echo "[!] Repository root not found. Run this script from a full checkout of the repository." >&2
    exit 1
fi

# shellcheck disable=SC1091
source ./Upstream.versions

remote_tags() {
    git ls-remote --tags --refs origin | sed 's|.*refs/tags/||'
}

require_semver() {
    if ! echo "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "[!] Version must be semantic, for example 0.5.2. Received: $1" >&2
        exit 1
    fi
}

# Prints the revs already published for an upstream version, one per line.
upstream_revs() {
    local prefix="upstream.$1-"
    local pattern="^${prefix//./\\.}[0-9]+$"
    remote_tags | { grep -E "$pattern" || true; } | sed "s|^$prefix||"
}

case "${1:-}" in
    upstream)
        version=${2:-$RUNESTONE_VERSION}
        require_semver "$version"
        last=$(upstream_revs "$version" | sort -n | tail -1)
        echo "upstream.$version-$((${last:-0} + 1))"
        ;;
    has-upstream)
        version=${2:-}
        require_semver "$version"
        # Assign first so a failed ls-remote exits with git's status instead of reading as "no".
        revs=$(upstream_revs "$version")
        [ -n "$revs" ]
        ;;
    exists)
        tag=${2:-}
        if [ -z "$tag" ]; then
            echo "Usage: $0 exists <tag>" >&2
            exit 1
        fi
        rc=0
        git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null || rc=$?
        case "$rc" in
            0) exit 0 ;;
            2) exit 1 ;;
            *)
                echo "[!] Could not list tags on origin (git exited $rc). Check the network and try again." >&2
                exit "$rc"
                ;;
        esac
        ;;
    package)
        last=$(remote_tags | { grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true; } | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
        if [ -z "$last" ]; then
            echo "0.1.0"
            exit 0
        fi
        IFS=. read -r major minor patch <<<"$last"
        echo "$major.$minor.$((patch + 1))"
        ;;
    *)
        echo "Usage: $0 upstream [version] | has-upstream <version> | exists <tag> | package" >&2
        exit 1
        ;;
esac
