# Action for updating codemeta.json
This action updates the release-specific fields of a [CodeMeta](https://codemeta.github.io) file, `codemeta.json`, in the repository root so that the metadata describes the version being released.

This action is used by MatBox release workflows after the toolbox has been packaged and before the release is created. It rewrites five fields from the release version, the packaged MLTBX file name and the supported MATLAB releases in `MLToolboxInfo.json`. Every other field in the file is left exactly as it was, so authors, funding, keywords and dates such as `datePublished` remain under the repository's control.

A repository opts in simply by having a `codemeta.json` in its root. Repositories without one are skipped, so the action can run unconditionally in shared workflows.

## Usage
```yaml
- uses: ehennestad/matbox-actions/update-codemeta@v1
  with:
    # Version number of the release, without a leading v (required)
    version_number: ${{ steps.validate.outputs.version_number }}

    # Path to the packaged MLTBX file (required)
    mltbx_path: ${{ steps.package.outputs.mltbx_path }}

    # Directory containing MLToolboxInfo.json (optional)
    tools_directory: 'tools'
```

> [!NOTE]  
> This action only needs `jq`, which is preinstalled on GitHub-hosted runners. It does not need MATLAB. The updated file is written in place and must be committed by a later step, such as `create-github-release`, which stages `codemeta.json` when it exists.

## Example
```yaml
name: Package and Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version number in major.minor.patch format'
        required: true
        type: string

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ssh-key: ${{ secrets.DEPLOY_KEY }}

      - name: Validate Version
        id: validate
        uses: ehennestad/matbox-actions/validate-version@v1
        with:
          version: ${{ inputs.version }}

      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v2

      - name: Install MatBox
        uses: ehennestad/matbox-actions/install-matbox@v1

      - name: Package Toolbox
        id: package
        uses: ehennestad/matbox-actions/package-toolbox@v1
        with:
          version_number: ${{ steps.validate.outputs.version_number }}

      - name: Update codemeta.json
        uses: ehennestad/matbox-actions/update-codemeta@v1
        with:
          version_number: ${{ steps.validate.outputs.version_number }}
          mltbx_path: ${{ steps.package.outputs.mltbx_path }}

      - name: Create GitHub Release
        uses: ehennestad/matbox-actions/create-github-release@v1
        with:
          version_number: ${{ steps.validate.outputs.version_number }}
          mltbx_path: ${{ steps.package.outputs.mltbx_path }}
```

This example illustrates the position of the action in a release job: after packaging, so the MLTBX file name is known, and before the release action commits the check-ins and moves the tag, so the tagged source carries metadata for the released version.

## Features

- Updates only the fields that change per release and preserves everything else, including key order
- Derives the repository URL from the workflow context, so nothing is hard-coded per repository
- Uses the packaged MLTBX file name for `downloadUrl`, so the naming convention lives in one place
- Reads the supported MATLAB releases from `MLToolboxInfo.json`
- Skips repositories without a `codemeta.json` and fails clearly on invalid JSON

## Inputs

| Input | Description |
|-------|-------------|
| `version_number` | [Required] Version number of the release (without 'v' prefix) |
| `mltbx_path` | [Required] Path to the packaged MLTBX file. Its file name becomes the release asset name in `downloadUrl` |
| `tools_directory` | [Optional] Directory containing MLToolboxInfo.json (default: 'tools') |

## Outputs

| Output | Description |
|--------|-------------|
| `updated` | `true` when `codemeta.json` was updated, `false` when the repository has none |

## Updated Fields

| Field | Value |
|-------|-------|
| `version` | The `version_number` input |
| `downloadUrl` | `<repository>/releases/download/v<version>/<mltbx file name>` |
| `releaseNotes` | `<repository>/releases/tag/v<version>`, the release's own page on GitHub |
| `runtimePlatform` | `MATLAB <minimum> or later`, or `MATLAB <minimum> to <maximum>` when `MaximumMatlabRelease` is set. Left unchanged when `MinimumMatlabRelease` is empty |
| `dateModified` | The current date in UTC, formatted as `YYYY-MM-DD` |

Fields that do not exist yet are appended to the end of the file. All other fields, including `datePublished`, `dateCreated`, `author` and `license`, are never touched.

The action does not depend on the CodeMeta version. The five fields it writes are schema.org terms present in both the CodeMeta 2.0 and 3.0 contexts, and `@context` is never touched.
