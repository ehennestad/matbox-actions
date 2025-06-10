# Validate Version Action

A GitHub Action that validates version number formats from either manual input or Git tags, ensuring they follow semantic versioning conventions.

## Description

This action validates version numbers in two scenarios:
1. **Manual triggers**: Validates a version number provided as input
2. **Tag triggers**: Validates a Git tag and extracts the version number

The action ensures version numbers follow the semantic versioning format (`major.minor.patch`).

## Features

- ✅ Validates semantic versioning format (`x.y.z`)
- ✅ Handles both manual input and Git tag scenarios
- ✅ Strips 'v' prefix from tags automatically
- ✅ Skips execution if commit contains `[skip-ci]`
- ✅ Provides clean version number output

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `version` | Version number for manual triggers (format: `x.y.z`) | No | - |
| `ref_name` | GitHub ref name for tag triggers (format: `vx.y.z`) | No | - |

Note: Either `version` or `ref_name` must be passed as input, but not both.

## Outputs

| Output | Description |
|--------|-------------|
| `version_number` | Validated version number without 'v' prefix |

## Usage

### Manual Trigger with Version Input

```yaml
- name: Validate Version
  id: validate
  uses: ehennestad/matbox-actions/validate-version@v1
  with:
    version: '1.2.3'

- name: Use validated version
  run: echo "Version: ${{ steps.validate.outputs.version_number }}"
```

### Tag Trigger

```yaml
on:
  push:
    tags:
      - 'v*'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Validate Version from Tag
        id: validate
        uses: ehennestad/matbox-actions/validate-version@v1
        with:
          ref_name: ${{ github.ref_name }}
          
      - name: Use validated version
        run: echo "Version: ${{ steps.validate.outputs.version_number }}"
```

### Workflow Dispatch with Version Input

```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to release'
        required: true
        type: string

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Validate Version
        id: validate
        uses: ehennestad/matbox-actions/validate-version@v1
        with:
          version: ${{ github.event.inputs.version }}
          
      - name: Use validated version
        run: echo "Version: ${{ steps.validate.outputs.version_number }}"
```

## Version Format Requirements

### For Manual Input (`version`)
- Must follow format: `x.y.z` (e.g., `1.2.3`)
- Each component must be a number
- No 'v' prefix allowed

### For Tag Input (`ref_name`)
- Must follow format: `vx.y.z` (e.g., `v1.2.3`)
- Each component must be a number
- 'v' prefix is required

## Skip CI Feature

The action will automatically fail if the commit message contains `[skip-ci]`, allowing you to skip CI runs when needed.

## Error Handling

The action will fail with descriptive error messages in the following cases:

1. **Invalid manual version format**:
   ```
   Error: Input for 'version' ('1.2') is not in the expected major.minor.patch format.
   ```

2. **Invalid tag format**:
   ```
   Error: Tag name ('v1.2') is not in the expected v*.*.* format.
   ```

3. **Skip CI detected**:
   ```
   Error: Commit message contains [skip-ci], skipping.
   ```

## Examples

### Valid Inputs

| Input Type | Valid Examples |
|------------|----------------|
| Manual version | `1.0.0`, `2.1.3`, `10.20.30` |
| Tag name | `v1.0.0`, `v2.1.3`, `v10.20.30` |

### Invalid Inputs

| Input Type | Invalid Examples | Reason |
|------------|------------------|--------|
| Manual version | `v1.0.0` | Contains 'v' prefix |
| Manual version | `1.0` | Missing patch version |
| Manual version | `1.0.0-beta` | Contains pre-release identifier |
| Tag name | `1.0.0` | Missing 'v' prefix |
| Tag name | `v1.0` | Missing patch version |

## License

This action is part of the matbox-actions repository. See the main repository for license information.
