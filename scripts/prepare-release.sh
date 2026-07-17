#!/usr/bin/env bash
# prepare-release.sh - Cut a reproducible release tag for matbox-actions.
#
# On main, the reusable workflows reference this repo's own actions with @main
# so main is internally consistent and testable. A release must instead ship
# workflows whose internal refs are pinned to the immutable release tag, so that
# a consumer pinning @vX.Y (or its SHA) gets a fully frozen action stack.
#
# This script builds that pinned commit off to the side, tags it, and pushes
# ONLY the tag. main is never modified: it keeps its @main internal refs. The
# tag push (from the maintainer's credentials) then triggers the repo's
# _internal-draft-release workflow; publishing that draft triggers
# _internal-bump-major-tag, which moves the floating major tag (e.g. v1) onto
# the release commit.
#
# Usage: scripts/prepare-release.sh <MAJOR.MINOR>
#   e.g. scripts/prepare-release.sh 1.5
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <MAJOR.MINOR>   e.g. $0 1.5" >&2
    exit 2
fi

version="$1"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version must be MAJOR.MINOR, e.g. 1.5" >&2
    exit 2
fi
tag="v${version}"

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
cd "$repoRoot"

# Preconditions: clean tree, on main, in sync with origin, tag is free.
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: working tree is not clean. Commit or stash changes first." >&2
    exit 1
fi
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
    echo "Error: releases are cut from main." >&2
    exit 1
fi
git fetch origin --tags --quiet
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    echo "Error: local main is not in sync with origin/main." >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null || \
   git ls-remote --tags origin "$tag" | grep -q "refs/tags/${tag}$"; then
    echo "Error: tag ${tag} already exists." >&2
    exit 1
fi

releaseBranch="release-tmp-${tag}"
cleanup() {
    git switch --quiet main
    git branch -D "$releaseBranch" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Build the pinned commit on a throwaway branch so main is left untouched.
git switch --quiet -c "$releaseBranch"
"${scriptDir}/pin-internal-refs.sh" main "$tag"
git commit --quiet -am "Release ${tag}: pin internal action refs"
git tag -a "$tag" -m "Release ${tag}"
git push origin "$tag"

echo
echo "Pushed tag ${tag} with internal refs pinned to @${tag}. main is unchanged."
echo "Next: review and publish the draft release GitHub creates for ${tag};"
echo "publishing moves the major tag (v${version%%.*}) onto the release commit."
