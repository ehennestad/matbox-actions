# Action for creating GitHub release
This action creates a GitHub release with a packaged MATLAB toolbox, handling tag management, file commits, and release notes generation with automated badge integration.

This action is used by MatBox workflows responsible for publishing toolbox releases. It commits any final changes (such as updated Contents.m files), manages Git tags by updating or recreating them as needed, and creates a draft GitHub release with the packaged MLTBX file attached. The action automatically generates release notes and includes "tested with" badges that link to the `gh-badges` branch for version-specific compatibility information.

## Usage
```yaml
- uses: ehennestad/matbox-actions/create-github-release@v1
  with:
    # Version number for the release (required)
    version_number: ${{ steps.validate.outputs.version_number }}

    # Path to the packaged MLTBX file (required)
    mltbx_path: ${{ steps.package.outputs.mltbx_path }}
```

> [!NOTE]  
> This action requires appropriate repository permissions for creating releases, pushing tags, and committing files.

## Example
```yaml
name: Create Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+' # Matches tags like v1.2.3

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Validate Version
        id: validate
        uses: ehennestad/matbox-actions/validate-version@v1
        with:
          ref_name: ${{ github.ref_name }}
          
      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v2
          
      - name: Install MatBox
        uses: ehennestad/matbox-actions/install-matbox@v1
        
      - name: Package Toolbox
        id: package
        uses: ehennestad/matbox-actions/package-toolbox@v1
        with:
          version_number: ${{ steps.validate.outputs.version_number }}
          
      - name: Create GitHub Release
        uses: ehennestad/matbox-actions/create-github-release@v1
        with:
          version_number: ${{ steps.validate.outputs.version_number }}
          mltbx_path: ${{ steps.package.outputs.mltbx_path }}
```

This example illustrates how the action can be used to create a complete release workflow. The action handles all Git operations and creates a draft release with the packaged toolbox and automated badge integration.

## Features

- Commits final changes to Contents.m files before release
- Manages Git tags by updating or recreating them as needed
- Creates draft GitHub releases with packaged MLTBX files
- Automatically generates release notes
- Includes "tested with" badges from `gh-badges` branch
- Uses [skip actions] markers to prevent recursive workflow triggers

## Inputs

| Input | Description |
|-------|-------------|
| `version_number` | [Required] Version number for the release (without 'v' prefix) |
| `mltbx_path` | [Required] Path to the packaged MLTBX file to attach to the release |

## Outputs

This action does not produce direct outputs, but creates a draft GitHub release with the specified version tag and attached MLTBX file.

## Release Process

The action follows this process:
1. **Commit Changes**: Commits any updated Contents.m files with [skip actions] marker
2. **Tag Management**: Deletes existing tags (local and remote) and creates new ones
3. **Release Creation**: Creates a draft GitHub release with automatic release notes
4. **Badge Integration**: Includes "tested with" badges linking to `gh-badges` branch
5. **Artifact Attachment**: Attaches the packaged MLTBX file to the release

