#!/usr/bin/env bash
# Update the release-specific fields of the codemeta.json in the repository root.
#
# Usage: update_codemeta.sh <version_number> <mltbx_path> [tools_directory]
#
#   version_number   Release version without a leading "v", e.g. 1.2.3
#   mltbx_path       Path to the packaged MLTBX. Its file name is the release asset name.
#   tools_directory  Directory containing MLToolboxInfo.json (default: tools)
#
# The script owns exactly these fields and leaves every other field untouched:
#   version, downloadUrl, releaseNotes, runtimePlatform, dateModified
#
# Environment:
#   GITHUB_SERVER_URL, GITHUB_REPOSITORY  Build the repository URL (set by GitHub Actions)
#   GITHUB_OUTPUT                         Receives "updated=true|false" when set
#   CODEMETA_DATE                         Overrides today's date for dateModified (used by tests)
set -euo pipefail

usage="Usage: update_codemeta.sh <version_number> <mltbx_path> [tools_directory]"
versionNumber="${1:?${usage}}"
mltbxPath="${2:?${usage}}"
toolsDirectory="${3:-tools}"

codemetaFile="codemeta.json"
toolboxInfoFile="${toolsDirectory}/MLToolboxInfo.json"

setOutput() {
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "updated=$1" >> "$GITHUB_OUTPUT"
    fi
}

# A repository opts in by having a codemeta.json in its root, so repositories
# without one are left alone rather than failing the release.
if [ ! -f "$codemetaFile" ]; then
    echo "::notice::No codemeta.json in the repository root. Skipping the codemeta update."
    setOutput false
    exit 0
fi

if ! jq empty "$codemetaFile" 2>/dev/null; then
    echo "::error file=${codemetaFile}::codemeta.json is not valid JSON. Fix the file before releasing."
    exit 1
fi

if [ ! -f "$toolboxInfoFile" ]; then
    echo "::error::Cannot read the supported MATLAB releases because ${toolboxInfoFile} does not exist."
    exit 1
fi

: "${GITHUB_SERVER_URL:?GITHUB_SERVER_URL must be set}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"

repositoryUrl="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}"
tag="v${versionNumber}"
assetName="$(basename "$mltbxPath")"
downloadUrl="${repositoryUrl}/releases/download/${tag}/${assetName}"
# GitHub anchors each release section on the releases page by its tag.
releaseNotesUrl="${repositoryUrl}/releases#release-${tag}"
dateModified="${CODEMETA_DATE:-$(date -u +%Y-%m-%d)}"

minimumRelease="$(jq -r '.ToolboxOptions.MinimumMatlabRelease // ""' "$toolboxInfoFile")"
maximumRelease="$(jq -r '.ToolboxOptions.MaximumMatlabRelease // ""' "$toolboxInfoFile")"

if [ -z "$minimumRelease" ]; then
    echo "::notice::MinimumMatlabRelease is not set in ${toolboxInfoFile}. Leaving runtimePlatform unchanged."
    runtimePlatform=""
elif [ -z "$maximumRelease" ]; then
    runtimePlatform="MATLAB ${minimumRelease} or later"
else
    runtimePlatform="MATLAB ${minimumRelease} to ${maximumRelease}"
fi

# jq keeps the key order and content of every field it does not assign.
# Fields that do not exist yet are appended at the end of the object.
jq --indent 2 \
    --arg version "$versionNumber" \
    --arg downloadUrl "$downloadUrl" \
    --arg releaseNotes "$releaseNotesUrl" \
    --arg runtimePlatform "$runtimePlatform" \
    --arg dateModified "$dateModified" \
    '.version = $version
     | .downloadUrl = $downloadUrl
     | .releaseNotes = $releaseNotes
     | (if $runtimePlatform != "" then .runtimePlatform = $runtimePlatform else . end)
     | .dateModified = $dateModified' \
    "$codemetaFile" > "${codemetaFile}.tmp"
mv "${codemetaFile}.tmp" "$codemetaFile"

echo "Updated ${codemetaFile} for ${tag} (${downloadUrl})"
setOutput true
