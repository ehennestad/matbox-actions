# Action for generating "tested with" badges
This action generates and updates "tested with" badges for MATLAB toolbox releases, automatically managing badge storage in a dedicated `gh-badges` branch.

This action is used by MatBox workflows responsible for creating release badges. It downloads test reports from workflow artifacts, generates "tested with" badges using MATLAB/MatBox functions, and manages the storage of these badges in a dedicated `gh-badges` branch with version-specific organization.

The motivation is to automatically generate and maintain version-specific "tested with" badges that reflect the testing status of each toolbox release, providing users with clear information about compatibility and testing coverage.

## Usage
```yaml
- uses: ehennestad/matbox-actions/generate-tested-with-badge@v1
  with:
    # Version number for the release (without 'v' prefix)
    version_number: ${{ steps.validate.outputs.version_number }}

    # Directory containing badge tools (optional)
    tools_directory: 'tools'
```

> [!NOTE]  
> This action requires MATLAB and MatBox to be installed in previous workflow steps, and test reports to be available as workflow artifacts.

## Example
```yaml
name: Release with test matrix badge

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+' # Matches tags like v1.2.3

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v2
        
      - name: Install MatBox
        uses: ehennestad/matbox-actions/install-matbox@v1
        
      - name: Run Tests
        run: # Your test commands here
        
      - name: Upload Test Reports
        uses: actions/upload-artifact@v4
        with:
          name: reports-${{ matrix.os }}
          path: docs/reports/

  generate-badge:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Validate version number
        id: validate
        uses: ehennestad/matbox-actions/validate-version@v1
        with:
          ref_name: ${{ github.ref_name }}
          
      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v2
        
      - name: Install MatBox
        uses: ehennestad/matbox-actions/install-matbox@v1
        
      - name: Create "tested with" badge
        uses: ehennestad/matbox-actions/generate-tested-with-badge@v1
        with:
          version_number: ${{ steps.validate.outputs.version_number }}
```

This example illustrates how the action can be used to automatically generate and save "tested with" badges as part of a release workflow. The badges are stored in a dedicated `gh-badges` branch with version-specific organization.

## Features

- Downloads test reports from workflow artifacts
- Generates "tested with" badges using MATLAB/MatBox
- Automatically manages `gh-badges` branch creation
- Version-specific badge organization
- Handles both existing and new `gh-badges` branches
- Only commits when changes are detected

## Inputs

| Input | Description |
|-------|-------------|
| `version_number` | [Required] Version number for the release (without 'v' prefix) |
| `tools_directory` | [Optional] Directory containing MatBox tools (default: 'tools') |

## Outputs

This action does not produce outputs, but creates/updates badge files in the `gh-badges` branch at `.github/badges/v{version}/tested_with.json`.

## Prerequisites

This action requires the following to be set up in previous workflow steps:
- MATLAB must be installed and available
- MatBox must be installed and accessible
- Test reports must be uploaded as workflow artifacts with names matching the pattern `reports-*`
- Badge generation functions must be available (either custom `createTestedWithBadgeforToolbox` or MatBox's `matbox.tasks.createTestedWithBadgeforToolbox`)
