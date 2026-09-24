# Action for updating CITATION.cff
This action updates the release-specific fields of a [Citation File Format](https://citation-file-format.github.io) file, `CITATION.cff`, in the repository root, so that a citation of the released source names the version it cites.

This action is used by MatBox release workflows after the toolbox has been packaged and before the release is created, next to [`update-codemeta`](../update-codemeta/). It sets two top-level keys from the release version and date. Every other line of the file is left exactly as it was, so authors, the abstract, keywords and comments remain under the repository's control.

A repository opts in simply by having a `CITATION.cff` in its root. Repositories without one are skipped, so the action can run unconditionally in shared workflows.

## Usage
```yaml
- uses: ehennestad/matbox-actions/update-citation@v1
  with:
    # Version number of the release, without a leading v (required)
    version_number: ${{ steps.validate.outputs.version_number }}
```

> [!NOTE]  
> This action needs only `bash` and `awk`, which are present on every GitHub-hosted runner. It does not need MATLAB. The updated file is written in place and must be committed by a later step, such as `create-github-release`, which stages `CITATION.cff` when it exists.

## Features

- Updates only the two keys that change per release, and preserves every other line, including comments, block scalars and key order
- Touches top-level keys only, so the `version` of a `preferred-citation` or of a reference is never changed
- Quotes both values, so that no YAML parser reads the version as a number or the date as a date object
- Appends either key when the file does not have it yet
- Keeps Windows line endings in a file that uses them
- Skips repositories without a `CITATION.cff`, and fails clearly on a file without a top-level `cff-version`

## Inputs

| Input | Description |
|-------|-------------|
| `version_number` | [Required] Version number of the release (without 'v' prefix) |

## Outputs

| Output | Description |
|--------|-------------|
| `updated` | `true` when `CITATION.cff` was updated, `false` when the repository has none |

## Updated Fields

| Field | Value |
|-------|-------|
| `version` | The `version_number` input, quoted |
| `date-released` | The current date in UTC, formatted as `YYYY-MM-DD` and quoted |

Each key is replaced as a whole line, so a comment written at the end of either line is not kept. The file is edited line by line rather than parsed, because no YAML tool on a GitHub-hosted runner rewrites a file without also restyling the rest of it. The action does not validate the file against the CFF schema.
