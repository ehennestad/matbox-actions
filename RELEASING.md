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
  consumer pinning `@vX.Y` (or its SHA) gets a fully frozen action stack.

## Ref conventions

| Ref a consumer uses            | Meaning                                             |
|--------------------------------|-----------------------------------------------------|
| `@v1`                          | Rolling major — latest `v1.x`. Moves on each release.|
| `@v1.5`                        | Immutable minor release. Reproducible.              |
| a full commit SHA of `@v1.5`   | Immutable and reproducible (internal refs are pinned).|
| `@main`                        | Development tip. Not for consumers.                 |

## Cutting a release

Releases are cut from a clean, up-to-date `main`:

```bash
scripts/prepare-release.sh 1.5
```

The script:

1. Rewrites the internal refs from `@main` to `@v1.5` on a throwaway branch
   (via `scripts/pin-internal-refs.sh`), so **`main` is never modified**.
2. Commits that change, tags it `v1.5`, and pushes **only the tag**.

The tag push (with your credentials, not `GITHUB_TOKEN`) then drives the
existing automation:

- **`_internal-draft-release`** — on the `vX.Y` tag push, opens a draft GitHub
  release with generated notes.
- **`_internal-bump-major-tag`** — when you publish that release, force-moves the
  major tag (`v1`) onto the release commit. Pre-releases are skipped.

So the manual steps are: run the script, then review and **publish** the draft
release GitHub creates.

## Why `main` keeps `@main`

The pinned commit exists only as the tagged commit; it is intentionally not
merged back to `main`. Keeping `@main` on `main` is what lets the whole stack be
tested at `main` before a tag is cut — pointing a consumer (or smoke-test) repo
at `...@main` exercises main's actions end to end, which pinning to a lagging
`@v1` never could.
