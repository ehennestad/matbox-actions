# Action for validating a version number
This action validates and sanitizes a version number from manual input or git tags by ensuring they follow semantic versioning conventions.

This action is used by MatBox workflows responsible for initializing new versioned releases. It will validate and sanitize a version number that originates either from a git tag (`push.tags` event) or from running a workflow manually from the **Actions** tab (`workflow_dispatch` event) and provide the output `version_number` that follows the semantic versioning format (`major.minor.patch`).

The motivation is to enable triggering a release-related workflow either via Git tags (e.g., `v1.0.0`) or via manual input (e.g., `1.0.0`), and to ensure both result in a consistent version number.

## Usage
```yaml
- uses: ehennestad/matbox-actions/validate-version@v1
  with:
    # Version number in major.minor.patch format (for manual triggers). Should be empty if "ref_name" is non-empty.
    version: ${{ inputs.version }}

    # GitHub ref name (for tag triggers) formatted as `vx.y.z`. Should be empty if "version" is non-empty.
    ref_name: ${{ github.ref_name }} 
```

> [!NOTE]  
> Either `version` or `ref_name` should be empty.

## Example
```yaml
name: Prepare Release (Modular)

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+' # Matches tags like v1.2.3
  workflow_dispatch:
    inputs:
      version:
        description: 'Version number in major.minor.patch format'
        required: true
        type: string

jobs:
  display-version:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Validate Version
        id: validate
        uses: ehennestad/matbox-actions/validate-version@v1
        with:
          version: ${{ github.event.inputs.version }}
          
      - name: Display validated version
        run: echo "Version: ${{ steps.validate.outputs.version_number }}"
```

This example illustrates how the action can be used to provide a clean version number to subsequent steps or jobs in a workflow. The version number can originate either from a tag trigger **or** a manual trigger, and will be normalized to the same format in both cases.

## Features

- Validates semantic versioning format (`x.y.z`)
- Handles both manual input and Git tag scenarios
- Strips 'v' prefix from tags automatically
- Skips execution if commit contains `[skip actions]`
- Provides clean version number output

## Inputs

| Input | Description |
|-------|-------------|
| `version` | [Optional*] Version number for manual triggers (format: `x.y.z`) |
| `ref_name` | [Optional*] GitHub ref name for tag triggers (format: `vx.y.z`) |

## Outputs

| Output | Description |
|--------|-------------|
| `version_number` | Validated version number without 'v' prefix |


## Skip CI Feature

The action will automatically fail if the commit message contains `[skip actions]`, effectively skipping release processing when needed (e.g. when re-tagging due to minor updates such as bumping a version number).
