#!/usr/bin/env bash
# pin-internal-refs.sh - Rewrite this repo's internal action/workflow refs.
#
# Reusable workflows in .github/workflows reference this repo's own composite
# actions and sub-workflows by an explicit git ref, e.g.
#   uses: ehennestad/matbox-actions/install-matbox@main
# GitHub resolves each such ref literally and independently, so a floating ref
# (like @v1) means a consumer who pins the entry workflow to an old tag or SHA
# still runs whichever code the floating ref currently points at. To make a
# tagged release reproducible, the internal refs are pinned to the immutable
# release tag at release time; on main they track @main so main stays testable.
#
# Usage: pin-internal-refs.sh <from-ref> <to-ref>
#   e.g. pin-internal-refs.sh main v1.5   (pin main to a release tag)
#        pin-internal-refs.sh v1 main     (move an older pin back to main)
#
# Only self-references (ehennestad/matbox-actions/...) in .github/workflows are
# touched. Third-party actions and the consumer-facing workflow templates keep
# their own pins.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <from-ref> <to-ref>" >&2
    exit 2
fi

fromRef="$1"
toRef="$2"

# fromRef is interpolated into the ERE patterns below; escape regex
# metacharacters (and the # sed delimiter) so a dotted ref like v1.5 matches
# only itself rather than treating '.' as a wildcard.
fromRefPattern="$(printf '%s' "$fromRef" | sed 's/[][(){}.*+?|^$\\#]/\\&/g')"

repoRoot="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflowDir="${repoRoot}/.github/workflows"

changed=0
for file in "${workflowDir}"/*.yml; do
    [ -e "$file" ] || continue
    sed -i.bak -E \
        "s#(uses:[[:space:]]*ehennestad/matbox-actions/[^@[:space:]]+)@${fromRefPattern}([[:space:]]|\$)#\1@${toRef}\2#g" \
        "$file"
    if ! cmp -s "$file" "${file}.bak"; then
        echo "Updated $(basename "$file")"
        changed=1
    fi
    rm -f "${file}.bak"
done

if [ "$changed" -eq 0 ]; then
    echo "Error: no internal refs matched @${fromRef}; nothing was rewritten." >&2
    exit 1
fi

# Verify the rewrite was complete. A self-reference still on @<from-ref> means
# it is written in a form the sed pattern above does not cover (quoting,
# unusual spacing), and releasing with a floating internal ref would defeat the
# reproducibility this script exists to guarantee. The boundary class permits
# ref-name characters so that e.g. @main does not match a ref named @main-foo.
if grep -En "ehennestad/matbox-actions/[^@]*@${fromRefPattern}([^A-Za-z0-9._/-]|\$)" "${workflowDir}"/*.yml; then
    echo "Error: the refs above still point at @${fromRef} after the rewrite." >&2
    exit 1
fi
