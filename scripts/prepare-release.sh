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
# Usage: scripts/prepare-release.sh <MAJOR.MINOR[.PATCH] | major | minor | patch>
#   e.g. scripts/prepare-release.sh 1.5      # explicit version
#        scripts/prepare-release.sh minor    # infer from the latest release tag
#
# With a bump keyword the new version is derived from the highest existing
# vMAJOR.MINOR[.PATCH] tag: major -> (MAJOR+1).0, minor -> MAJOR.(MINOR+1),
# patch -> MAJOR.MINOR.(PATCH+1). Major and minor releases keep the repo's
# two-part tag convention; only patch releases carry a third component.
set -euo pipefail

# Emits a GitHub Actions error annotation (visible on the run summary,
# without opening the step log) when running in Actions, in addition to the
# plain stderr line that's the only output when the script runs locally per
# .github/RELEASING.md. Multi-line messages are %0A-escaped, as the
# ::error:: workflow command does not accept a literal newline.
annotate_error() {
    local message="$1"
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::error::${message//$'\n'/%0A}" >&2
    fi
    echo "Error: ${message}" >&2
}

# Emits a GitHub Actions notice annotation (visible on the run summary) when
# running in Actions, in addition to the plain stdout line printed locally.
annotate_notice() {
    local message="$1"
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::notice::${message//$'\n'/%0A}"
    fi
    echo "${message}"
}

smokeRepo="ehennestad/matbox-actions-smoketest"

check_smoke_workflow() {
    local workflowFile="$1"
    local runs status conclusion url

    runs="$(gh run list --repo "$smokeRepo" --workflow "$workflowFile" --branch main \
        --limit 1 --json status,conclusion,url 2>/dev/null || echo '[]')"

    if [ "$(echo "$runs" | jq 'length')" -eq 0 ]; then
        annotate_error "no runs of ${workflowFile} found on ${smokeRepo} (main).
Push to main (or dispatch it manually) and let it complete before releasing."
        exit 1
    fi

    status="$(echo "$runs" | jq -r '.[0].status')"
    conclusion="$(echo "$runs" | jq -r '.[0].conclusion')"
    url="$(echo "$runs" | jq -r '.[0].url')"

    if [ "$status" != "completed" ]; then
        annotate_error "the latest ${workflowFile} run on ${smokeRepo} (main) is still ${status}.
Wait for it to finish, then retry: ${url}"
        exit 1
    fi
    if [ "$conclusion" != "success" ]; then
        annotate_error "the latest ${workflowFile} run on ${smokeRepo} (main) did not pass (${conclusion}).
Fix the regression before releasing: ${url}"
        exit 1
    fi
    echo "Smoke check passed: ${workflowFile} on ${smokeRepo} (main) — ${url}"
}

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <MAJOR.MINOR[.PATCH] | major | minor | patch>   e.g. $0 1.5 or $0 minor" >&2
    exit 2
fi

version=""
bump=""
case "$1" in
    major|minor|patch)
        bump="$1"
        ;;
    *)
        version="$1"
        if [[ ! "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            annotate_error "argument must be a version (MAJOR.MINOR or MAJOR.MINOR.PATCH, e.g. 1.5 or 1.5.1) or one of: major, minor, patch"
            exit 2
        fi
        ;;
esac

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
cd "$repoRoot"

# Preconditions: gh and jq available, clean tree, on main, in sync with
# origin, tag is free, smoke tests green. Tooling is checked first so a
# missing CLI cannot strand a pushed tag without its draft release.
if ! command -v gh >/dev/null 2>&1; then
    annotate_error "the gh CLI is required to create the draft release."
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    annotate_error "jq is required to check smoke-test status."
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    annotate_error "working tree is not clean. Commit or stash changes first."
    exit 1
fi
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
    annotate_error "releases are cut from main."
    exit 1
fi
git fetch origin --tags --quiet
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    annotate_error "local main is not in sync with origin/main."
    exit 1
fi

# Resolve a bump keyword into a concrete version, now that all tags are
# fetched. Pure major tags like v1 are floating aliases, so only full
# vMAJOR.MINOR[.PATCH] release tags count as the latest release.
if [ -n "$bump" ]; then
    latestTag="$(git tag --list | grep -E '^v[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | tail -n 1 || true)"
    if [ -z "$latestTag" ]; then
        annotate_error "no existing vMAJOR.MINOR[.PATCH] tag to bump from. Pass an explicit version instead."
        exit 1
    fi
    IFS=. read -r latestMajor latestMinor latestPatch <<< "${latestTag#v}"
    case "$bump" in
        major) version="$((latestMajor + 1)).0" ;;
        minor) version="${latestMajor}.$((latestMinor + 1))" ;;
        patch) version="${latestMajor}.${latestMinor}.$((${latestPatch:-0} + 1))" ;;
    esac
    echo "Latest release tag is ${latestTag}; ${bump} bump gives version ${version}."
fi
tag="v${version}"

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null || \
   git ls-remote --tags origin "$tag" | grep -q "refs/tags/${tag}$"; then
    annotate_error "tag ${tag} already exists."
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
releaseUrl="$(gh release create "$tag" --draft --generate-notes --title "$tag")"
draftCreated=1

echo
echo "Pushed tag ${tag} with internal refs pinned to @${tag}. main is unchanged."
annotate_notice "Draft release ${tag} is ready to review: ${releaseUrl}
Publishing it moves the major tag (v${version%%.*}) onto the release commit."
