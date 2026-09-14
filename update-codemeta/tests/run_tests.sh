#!/usr/bin/env bash
# Run update_codemeta.sh against fixtures and compare the result with expected files.
#
# Usage: bash update-codemeta/tests/run_tests.sh
set -euo pipefail

testsDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${testsDirectory}/../update_codemeta.sh"
fixtures="${testsDirectory}/fixtures"

export GITHUB_SERVER_URL="https://github.com"
export GITHUB_REPOSITORY="example/example-toolbox"
export CODEMETA_DATE="2026-01-15"

failures=0
workDirectory=""

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# Each case runs in a fresh temporary repository root with its own GITHUB_OUTPUT.
setUpRepository() {
    local toolboxInfoFixture="$1"
    workDirectory="$(mktemp -d)"
    mkdir -p "${workDirectory}/tools"
    cp "${fixtures}/${toolboxInfoFixture}" "${workDirectory}/tools/MLToolboxInfo.json"
    export GITHUB_OUTPUT="${workDirectory}/github_output"
    : > "$GITHUB_OUTPUT"
}

runScript() {
    (cd "$workDirectory" && bash "$script" "1.2.3" "/runner/releases/ExampleToolbox_v1_2_3.mltbx" "tools")
}

assertUpdated() {
    local name="$1" expected="$2"
    if diff -u "${fixtures}/expected/${expected}" "${workDirectory}/codemeta.json" \
        && grep -qx "updated=true" "$GITHUB_OUTPUT"; then
        pass "$name"
    else
        fail "$name"
    fi
}

name="updates the release fields and writes an open-ended runtimePlatform"
setUpRepository "MLToolboxInfo.json"
cp "${fixtures}/codemeta.json" "${workDirectory}/codemeta.json"
runScript > /dev/null
assertUpdated "$name" "codemeta_no_maximum.json"

name="writes a bounded runtimePlatform when a maximum release is set"
setUpRepository "MLToolboxInfo_with_maximum.json"
cp "${fixtures}/codemeta.json" "${workDirectory}/codemeta.json"
runScript > /dev/null
assertUpdated "$name" "codemeta_with_maximum.json"

name="leaves runtimePlatform unchanged when no minimum release is set"
setUpRepository "MLToolboxInfo_no_minimum.json"
cp "${fixtures}/codemeta.json" "${workDirectory}/codemeta.json"
runScript > /dev/null
assertUpdated "$name" "codemeta_no_minimum.json"

name="skips a repository without codemeta.json"
setUpRepository "MLToolboxInfo.json"
if runScript > /dev/null && [ ! -e "${workDirectory}/codemeta.json" ] \
    && grep -qx "updated=false" "$GITHUB_OUTPUT"; then
    pass "$name"
else
    fail "$name"
fi

name="fails on invalid JSON and leaves the file untouched"
setUpRepository "MLToolboxInfo.json"
printf '{ "name": "broken",\n' > "${workDirectory}/codemeta.json"
if ! runScript > /dev/null 2>&1 \
    && [ "$(cat "${workDirectory}/codemeta.json")" = '{ "name": "broken",' ] \
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
