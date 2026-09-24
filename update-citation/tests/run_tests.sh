#!/usr/bin/env bash
# Run update_citation.sh against fixtures and compare the result with expected files.
#
# Usage: bash update-citation/tests/run_tests.sh
set -euo pipefail

testsDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${testsDirectory}/../update_citation.sh"
fixtures="${testsDirectory}/fixtures"

export CITATION_DATE="2026-01-15"

failures=0
workDirectory=""

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# Each case runs in a fresh temporary repository root with its own GITHUB_OUTPUT.
setUpRepository() {
    workDirectory="$(mktemp -d)"
    export GITHUB_OUTPUT="${workDirectory}/github_output"
    : > "$GITHUB_OUTPUT"
}

runScript() {
    (cd "$workDirectory" && bash "$script" "1.2.3")
}

assertUpdated() {
    local name="$1" expected="$2"
    if diff -u "$expected" "${workDirectory}/CITATION.cff" \
        && grep -qx "updated=true" "$GITHUB_OUTPUT"; then
        pass "$name"
    else
        fail "$name"
    fi
}

name="updates version and date-released and leaves every other line as it was"
setUpRepository
cp "${fixtures}/CITATION.cff" "${workDirectory}/CITATION.cff"
runScript > /dev/null
assertUpdated "$name" "${fixtures}/expected/CITATION.cff"

name="appends version and date-released when the file has neither"
setUpRepository
cp "${fixtures}/CITATION_without_release_fields.cff" "${workDirectory}/CITATION.cff"
runScript > /dev/null
assertUpdated "$name" "${fixtures}/expected/CITATION_without_release_fields.cff"

name="keeps Windows line endings, on replaced and appended lines alike"
setUpRepository
sed 's/$/\r/' "${fixtures}/CITATION.cff" > "${workDirectory}/CITATION.cff"
sed 's/$/\r/' "${fixtures}/expected/CITATION.cff" > "${workDirectory}/expected.cff"
runScript > /dev/null
assertUpdated "$name (replaced)" "${workDirectory}/expected.cff"
setUpRepository
sed 's/$/\r/' "${fixtures}/CITATION_without_release_fields.cff" > "${workDirectory}/CITATION.cff"
sed 's/$/\r/' "${fixtures}/expected/CITATION_without_release_fields.cff" > "${workDirectory}/expected.cff"
runScript > /dev/null
assertUpdated "$name (appended)" "${workDirectory}/expected.cff"

name="skips a repository without CITATION.cff"
setUpRepository
if runScript > /dev/null && [ ! -e "${workDirectory}/CITATION.cff" ] \
    && grep -qx "updated=false" "$GITHUB_OUTPUT"; then
    pass "$name"
else
    fail "$name"
fi

name="fails on a file without cff-version and leaves it untouched"
setUpRepository
cp "${fixtures}/CITATION_without_cff_version.cff" "${workDirectory}/CITATION.cff"
if ! runScript > /dev/null 2>&1 \
    && diff -q "${fixtures}/CITATION_without_cff_version.cff" "${workDirectory}/CITATION.cff" > /dev/null \
    && [ ! -s "$GITHUB_OUTPUT" ]; then
    pass "$name"
else
    fail "$name"
fi

if [ "$failures" -ne 0 ]; then
    echo "${failures} test(s) failed"
    exit 1
fi
echo "All tests passed"
