# Releasing matbox-actions

This repo is a monorepo of composite actions and reusable workflows that
reference **each other**. GitHub resolves every `uses:` ref independently and
literally, so a reusable workflow that internally references
`ehennestad/matbox-actions/install-matbox@<ref>` runs whatever `<ref>` points at
— regardless of the ref a consumer pinned for the entry workflow. If those
internal refs float (e.g. `@v1`), a consumer who pins the entry point to an old
tag or a SHA still gets the latest action code, so pinning buys no
reproducibility.

To avoid that, the internal refs depend on where the code lives:

- **On `main`:** internal refs are `@main`, so main is internally consistent and
  can be smoke-tested as a unit before release.
- **On a release tag `vX.Y`:** internal refs are pinned to that exact tag, so a
  consumer pinning `@vX.Y` gets a frozen action stack.

## Ref conventions

| Ref a consumer uses            | Meaning                                             |
|--------------------------------|-----------------------------------------------------|
| `@v1`                          | Rolling major — latest `v1.x`. Moves on each release.|
| `@v1.5` (or `@v1.5.1`)        | Immutable release. Reproducible.                    |
| a full commit SHA of `@v1.5`   | No better than `@v1.5`: internal refs still resolve through the `v1.5` tag. Prefer the tag.|
| `@main`                        | Development tip. Not for consumers.                 |

## Cutting a release

Both paths below run the same procedure, `scripts/prepare-release.sh`:

1. Rewrite the internal refs from `@main` to the release tag (via
   `scripts/pin-internal-refs.sh`, which fails if any self-reference escapes
   the rewrite) on a commit that is tagged but **never pushed to `main`**, so
   `main` keeps its `@main` refs.
2. Push only the tag and open a **draft** GitHub release with generated notes.
   If anything fails partway, the tag is rolled back (locally and, if already
   pushed, on origin) so a rerun starts clean.

Versions are `MAJOR.MINOR` or `MAJOR.MINOR.PATCH` (e.g. `1.5`, `1.5.1`).
Patch releases are cut from the current `main` like any other release; there
is no maintenance-branch flow for patching an old minor once `main` has moved
on incompatibly.

Then review and **publish** the draft. Publishing triggers
`_internal-bump-major-tag`, which verifies the release's internal refs are
pinned and force-moves the major tag (`v1`) onto the release commit.
Pre-releases are skipped.

### Preferred: the `Prepare release` workflow

Run the **Prepare release** workflow (`_internal-prepare-release.yml`) from the
Actions tab, giving it the version. The workflow just runs the script from a
clean checkout of `main`.

### Alternative: local script

The same release can be cut locally from a clean, up-to-date `main` (requires
an authenticated `gh`):

```bash
scripts/prepare-release.sh 1.5
```

## Why `main` keeps `@main`

The pinned commit exists only as the tagged commit; it is intentionally not
merged back to `main`. Keeping `@main` on `main` is what lets the whole stack be
tested at `main` before a tag is cut — pointing a consumer (or smoke-test) repo
at `...@main` exercises main's actions end to end, which pinning to a lagging
`@v1` never could.
