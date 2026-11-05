#!/usr/bin/env bash
# Run check_package_readme.sh against MLToolboxInfo.json files and check
# whether it passes or fails.
#
# Usage: bash check-package-readme/tests/run_tests.sh
set -euo pipefail

testsDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${testsDirectory}/../check_package_readme.sh"

failures=0
workDirectory=""
output=""

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; echo "$output" | sed 's/^/     | /'; failures=$((failures + 1)); }

# Each case runs in a fresh temporary repository root. With no argument the
# repository has no MLToolboxInfo.json.
setUpRepository() {
    workDirectory="$(mktemp -d)"
    mkdir -p "${workDirectory}/tools"
    if [ "$#" -gt 0 ]; then
        printf '%s\n' "$1" > "${workDirectory}/tools/MLToolboxInfo.json"
    fi
}

runScript() {
    (cd "$workDirectory" && bash "$script" "tools" 2>&1)
}

expectPass() {
    local name="$1" expectedOutput="$2"
    if output="$(runScript)" && [[ "$output" == *"$expectedOutput"* ]]; then
        pass "$name"
    else
        fail "$name"
    fi
}

expectFailure() {
    local name="$1" expectedOutput="$2"
    if ! output="$(runScript)" && [[ "$output" == *"::error"*"$expectedOutput"* ]]; then
        pass "$name"
    else
        fail "$name"
    fi
}

setUpRepository '{"ToolboxOptions": {"ToolboxName": "Example", "Description": "Reads example files."}}'
expectPass "passes with a Description" "generated from ToolboxOptions.Description"

setUpRepository '{"RootFilesToPackage": ["LICENSE", "README.md"], "ToolboxOptions": {"ToolboxName": "Example", "Description": ""}}'
expectPass "passes with README.md in RootFilesToPackage and an empty Description" "README.md, listed in RootFilesToPackage"

setUpRepository '{"RootFilesToPackage": "README.md", "ToolboxOptions": {"ToolboxName": "Example"}}'
expectPass "passes with RootFilesToPackage given as one file name" "README.md, listed in RootFilesToPackage"

setUpRepository '{"ToolboxOptions": {"ToolboxName": "Example", "Description": "", "Readme": "docs/overview.md"}}'
expectPass "passes with a Readme in ToolboxOptions" "docs/overview.md, set as ToolboxOptions.Readme"

setUpRepository '{"RootFilesToPackage": ["LICENSE"], "ToolboxOptions": {"ToolboxName": "Example", "Description": ""}}'
expectFailure "fails with an empty Description and no README.md" "no readme"

setUpRepository '{"ToolboxOptions": {"ToolboxName": "Example", "Description": " \n\t "}}'
expectFailure "fails with a Description of whitespace only" "no readme"

setUpRepository '{"ToolboxOptions": {"ToolboxName": "Example", "Description": null, "Readme": ""}}'
expectFailure "fails with a null Description and an empty Readme" "no readme"

setUpRepository
expectFailure "fails without MLToolboxInfo.json" "does not exist"

setUpRepository '{ "ToolboxOptions": {'
expectFailure "fails on invalid JSON" "not valid JSON"

if [ "$failures" -ne 0 ]; then
    echo "${failures} test(s) failed"
    exit 1
fi
echo "All tests passed"
