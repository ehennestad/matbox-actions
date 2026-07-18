#!/usr/bin/env bash
# prepare-release.sh - Cut a reproducible release tag for matbox-actions.
#
# On main, the reusable workflows reference this repo's own actions with @main
# so main is internally consistent and testable. A release must instead ship
# workflows whose internal refs are pinned to the immutable release tag, so that
# a consumer pinning @vX.Y gets a frozen action stack.
#
# This script builds that pinned commit off to the side, tags it, pushes ONLY
# the tag, and opens a draft GitHub release for it. main is never modified: it
# keeps its @main internal refs. Publishing the draft triggers
# _internal-bump-major-tag, which moves the floating major tag (e.g. v1) onto
# the release commit.
#
# Before doing any of that, it refuses to release unless the most recently
# completed smoke-test runs (test-code.yml and prepare-release.yml on
# ehennestad/matbox-actions-smoketest's main) both succeeded. This checks the
# latest run, not one tied to this exact commit — the smoke repo's runs are
# its own commits, so there is no direct SHA correlation — but since every
# non-doc push to main dispatches a fresh smoke run, the latest result closely
# tracks the current tip by the time a release is cut.
#
# Usage: scripts/prepare-release.sh <MAJOR.MINOR[.PATCH]>
#   e.g. scripts/prepare-release.sh 1.5
#        scripts/prepare-release.sh 1.5.1
set -euo pipefail

smokeRepo="ehennestad/matbox-actions-smoketest"

check_smoke_workflow() {
    local workflowFile="$1"
    local runs status conclusion url

    runs="$(gh run list --repo "$smokeRepo" --workflow "$workflowFile" --branch main \
        --limit 1 --json status,conclusion,url 2>/dev/null || echo '[]')"

    if [ "$(echo "$runs" | jq 'length')" -eq 0 ]; then
        echo "Error: no runs of ${workflowFile} found on ${smokeRepo} (main)." >&2
        echo "Push to main (or dispatch it manually) and let it complete before releasing." >&2
        exit 1
    fi

    status="$(echo "$runs" | jq -r '.[0].status')"
    conclusion="$(echo "$runs" | jq -r '.[0].conclusion')"
    url="$(echo "$runs" | jq -r '.[0].url')"

    if [ "$status" != "completed" ]; then
        echo "Error: the latest ${workflowFile} run on ${smokeRepo} (main) is still ${status}." >&2
        echo "Wait for it to finish, then retry: ${url}" >&2
        exit 1
    fi
    if [ "$conclusion" != "success" ]; then
        echo "Error: the latest ${workflowFile} run on ${smokeRepo} (main) did not pass (${conclusion})." >&2
        echo "Fix the regression before releasing: ${url}" >&2
        exit 1
    fi
    echo "Smoke check passed: ${workflowFile} on ${smokeRepo} (main) — ${url}"
}

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <MAJOR.MINOR[.PATCH]>   e.g. $0 1.5" >&2
    exit 2
fi

version="$1"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: version must be MAJOR.MINOR or MAJOR.MINOR.PATCH, e.g. 1.5 or 1.5.1" >&2
    exit 2
fi
tag="v${version}"

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
cd "$repoRoot"

# Preconditions: gh and jq available, clean tree, on main, in sync with
# origin, tag is free, smoke tests green. Tooling is checked first so a
# missing CLI cannot strand a pushed tag without its draft release.
if ! command -v gh >/dev/null 2>&1; then
    echo "Error: the gh CLI is required to create the draft release." >&2
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required to check smoke-test status." >&2
    exit 1
fi
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

echo "Checking smoke-test status on ${smokeRepo}..."
check_smoke_workflow "test-code.yml"
check_smoke_workflow "prepare-release.yml"

releaseBranch="release-tmp-${tag}"
tagCreated=0
tagPushed=0
draftCreated=0
cleanup() {
    # The tree was verified clean at the start, so any leftover modifications
    # are this script's own partial rewrite — discard them before leaving the
    # throwaway branch.
    git reset --quiet --hard >/dev/null 2>&1 || true
    git switch --quiet main || true
    git branch -D "$releaseBranch" >/dev/null 2>&1 || true
    # Roll back a partial release so a rerun starts from a clean slate: the
    # tag is only kept once the draft release exists.
    if [ "$draftCreated" -eq 0 ]; then
        if [ "$tagPushed" -eq 1 ]; then
            git push --quiet origin ":refs/tags/${tag}" || \
                echo "Warning: could not delete remote tag ${tag}; delete it manually before retrying." >&2
        fi
        if [ "$tagCreated" -eq 1 ]; then
            git tag -d "$tag" >/dev/null 2>&1 || true
        fi
    fi
}
trap cleanup EXIT

# Build the pinned commit on a throwaway branch so main is left untouched.
git switch --quiet -c "$releaseBranch"
"${scriptDir}/pin-internal-refs.sh" main "$tag"
git commit --quiet -am "Release ${tag}: pin internal action refs"
git tag -a "$tag" -m "Release ${tag}"
tagCreated=1
git push origin "$tag"
tagPushed=1
gh release create "$tag" --draft --generate-notes --title "$tag"
draftCreated=1

echo
echo "Pushed tag ${tag} with internal refs pinned to @${tag}. main is unchanged."
echo "Next: review and publish the draft release for ${tag};"
echo "publishing moves the major tag (v${version%%.*}) onto the release commit."
