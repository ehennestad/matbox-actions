# Action for packaging MATLAB toolbox
This action packages a MATLAB toolbox into an MLTBX file with a specified version number, using either a custom `packageToolbox` task or MatBox's default `packageToolbox` task.

This action is used by MatBox workflows responsible for creating distributable toolbox packages. It can run packaging using custom packaging task functions (if available in the tools directory) or fall back to MatBox's default packaging task. The action reads toolbox information from MLToolboxInfo.json, applies the specified version number, and generates an MLTBX file ready for distribution or release.

The motivation is to provide automated toolbox packaging for MATLAB toolboxes with consistent versioning and packaging standards, enabling streamlined release workflows and ensuring proper toolbox metadata and structure.

## Usage
```yaml
- uses: ehennestad/matbox-actions/package-toolbox@v1
  with:
    # Version number to use for packaging (required)
    version_number: ${{ steps.validate.outputs.version_number }}

    # Directory containing MATLAB code to package (optional)
    source_directory: 'code'

    # Directory containing packaging tools and MLToolboxInfo.json (optional)
    tools_directory: 'tools'
```

> [!NOTE]  
> This action requires MATLAB and MatBox to be installed in previous workflow steps, and MLToolboxInfo.json must be present in the tools directory.

## Example
```yaml
name: Package and Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+' # Matches tags like v1.2.3

jobs:
  package:
    runs-on: ubuntu-latest
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
          source_directory: 'src'
          tools_directory: 'tools'
          
      - name: Upload MLTBX Artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ steps.package.outputs.toolbox_name }}-${{ steps.validate.outputs.version_number }}
          path: ${{ steps.package.outputs.mltbx_path }}
```

This example illustrates how the action can be used to package a toolbox for release. The packaged MLTBX file is uploaded as an artifact and can be used in subsequent workflow steps or downloaded for distribution.

## Features

- Packages MATLAB toolboxes into distributable MLTBX files
- Supports both custom `packageToolbox` task function and MatBox default
- Applies specified version numbers to toolbox metadata
- Reads toolbox information from MLToolboxInfo.json
- Provides outputs for toolbox name and MLTBX file path
- Handles custom source directory configurations

## Inputs

| Input | Description |
|-------|-------------|
| `version_number` | [Required] Version number to use for packaging (without 'v' prefix) |
| `source_directory` | [Optional] Directory containing MATLAB code to package (default: 'code') |
| `tools_directory` | [Optional] Directory containing packaging tools and MLToolboxInfo.json (default: 'tools') |

## Outputs

| Output | Description |
|--------|-------------|
| `mltbx_path` | Path to the packaged MLTBX file |
| `toolbox_name` | Name of the toolbox from MLToolboxInfo.json |

## Packaging Function Priority

The action uses the following priority order for toolbox packaging:
1. **Custom function**: If `packageToolbox` exists in the tools directory, it will be used with the "specific" mode and version string
2. **MatBox function**: Falls back to `matbox.tasks.packageToolbox` with the specified parameters including source folder configuration

Both functions generate MLTBX files with the specified version number and toolbox metadata from MLToolboxInfo.json.
