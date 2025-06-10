# Action for installing MatBox
This action installs MatBox in MATLAB on GitHub runners, providing access to MatBox's testing, packaging, and code analysis task functions for MATLAB toolbox workflows.

This action is used by MatBox workflows to set up the MatBox framework in the MATLAB environment. It can install either the latest released version or the latest development version from the repository commit. The action installs MatBox in the runner's temporary directory to keep it separate from the repository being tested, and verifies the installation by checking the MatBox version.

## Usage
```yaml
- uses: ehennestad/matbox-actions/install-matbox@v1
  with:
    # Installation mode: 'release' or 'commit' (optional)
    mode: 'commit'
```

> [!NOTE]  
> This action requires MATLAB to be installed in previous workflow steps.

## Example
```yaml
name: Test Toolbox with MatBox

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

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
          
      - name: Test Code
        uses: ehennestad/matbox-actions/test-code@v1
        
      - name: Check Code Quality
        uses: ehennestad/matbox-actions/check-code@v1
```

This example illustrates how the action can be used to install MatBox before running other MatBox actions. The MatBox framework provides the underlying functionality for testing, code analysis, and packaging operations.

## Features

- Installs MatBox framework in MATLAB environment
- Supports both release and development versions
- Verifies installation with version check
- Provides access to all MatBox tools and functions
- Required prerequisite for other MatBox actions

## Inputs

| Input | Description |
|-------|-------------|
| `mode` | [Optional] Installation mode: 'release' for latest released version or 'commit' for latest development version (default: 'commit') |

## Outputs

This action does not produce direct outputs, but makes MatBox functions available in the MATLAB environment for subsequent workflow steps.

## Installation Modes

The action supports two installation modes:
1. **Release mode** (`'release'`): Installs the latest stable released version of MatBox
2. **Commit mode** (`'commit'`): Installs the latest development version from the repository

The commit mode is recommended for most workflows as it provides access to the latest features and bug fixes, while release mode offers more stability for production workflows.
