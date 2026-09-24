#!/usr/bin/env bash
# Update the release-specific fields of the CITATION.cff in the repository root.
#
# Usage: update_citation.sh <version_number>
#
#   version_number   Release version without a leading "v", e.g. 1.2.3
#
# The script owns exactly these top-level keys and leaves every other line
# as it was, comments and formatting included:
#   version, date-released
#
# Environment:
#   GITHUB_OUTPUT   Receives "updated=true|false" when set
#   CITATION_DATE   Overrides today's date for date-released (used by tests)
set -euo pipefail

usage="Usage: update_citation.sh <version_number>"
versionNumber="${1:?${usage}}"

citationFile="CITATION.cff"

setOutput() {
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "updated=$1" >> "$GITHUB_OUTPUT"
    fi
}

# A repository opts in by having a CITATION.cff in its root, so repositories
# without one are left alone rather than failing the release.
if [ ! -f "$citationFile" ]; then
    echo "::notice::No CITATION.cff in the repository root. Skipping the citation update."
    setOutput false
    exit 0
fi

# Every CITATION.cff declares its format in a top-level cff-version key. A file
# without one is not a file this script can safely edit line by line.
if ! grep -Eq '^cff-version:' "$citationFile"; then
    echo "::error file=${citationFile}::CITATION.cff has no top-level cff-version key. Fix the file before releasing."
    exit 1
fi

dateReleased="${CITATION_DATE:-$(date -u +%Y-%m-%d)}"

# The file is YAML, and no tool on a GitHub-hosted runner rewrites YAML without
# also restyling the rest of the file. The two keys are replaced line by line
# instead. Only top-level keys start in the first column, so the version of a
# reference or of the preferred citation, which is indented, is never matched.
# The values are quoted, so that no YAML parser reads the version as a number
# or the date as a date object. Keys that do not exist yet are appended, and a
# file with Windows line endings keeps them.
awk -v version="$versionNumber" -v dateReleased="$dateReleased" '
    NR == 1 { eol = (substr($0, length($0)) == "\r") ? "\r" : "" }
    function lineEnding(    last) {
        last = substr($0, length($0))
        return (last == "\r") ? "\r" : ""
    }
    /^version:/       { print "version: \"" version "\"" lineEnding(); hasVersion = 1; next }
    /^date-released:/ { print "date-released: \"" dateReleased "\"" lineEnding(); hasDate = 1; next }
    { print }
    END {
        if (!hasVersion) print "version: \"" version "\"" eol
        if (!hasDate)    print "date-released: \"" dateReleased "\"" eol
    }
' "$citationFile" > "${citationFile}.tmp"
mv "${citationFile}.tmp" "$citationFile"

echo "Updated ${citationFile} for v${versionNumber} (${dateReleased})"
setOutput true
