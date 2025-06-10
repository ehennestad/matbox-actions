# Action for configuring MATLAB test matrix
This action configures a set of matrix variables for testing a MATLAB toolbox across different MATLAB releases using a matrix strategy.

The following variables are set up
 - MATLABVersion : List of MATLAB release names
 - pythonVersion : List of compatible python versions (if `include_python` is true)

determines MATLAB and Python version combinations for testing workflows by determining appropriate version ranges from toolbox requirements and building .

This action is used by MatBox workflows responsible for setting up testing environments. It reads MATLAB version requirements from MLToolboxInfo.json, applies configuration constraints, maps compatible Python versions, and configures matrix variables that can be used by GitHub Actions matrix strategies for comprehensive testing across multiple MATLAB (and Python versions).

The motivation is to automatically configure appropriate testing environments based on toolbox compatibility requirements, ensuring comprehensive testing coverage while respecting version constraints and compatibility mappings.

## Usage
```yaml
- uses: ehennestad/matbox-actions/configure-matlab-test-matrix@v1
  with:
    # Directory containing MLToolboxInfo.json (optional)
    tools_directory: 'tools'

    # MATLAB versions to test - overrides auto-detection (optional)
    matlab_versions: '["R2023a", "R2023b", "R2024a"]'

    # Python version mappings for specific MATLAB versions (optional)
    python_versions: '{"R2023a": "3.9", "R2023b": "3.10"}'

    # Whether to include Python versions in the matrix (optional)
    include_python: 'true'
```

> [!NOTE]  
> This action reads MATLAB version requirements from MLToolboxInfo.json and applies configuration constraints to determine appropriate testing versions.

## Example
```yaml
name: Test Toolbox

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  configure-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.configure.outputs.matrix }}
      matlab_versions: ${{ steps.configure.outputs.matlab_versions }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Configure Test Matrix
        id: configure
        uses: ehennestad/matbox-actions/configure-matlab-test-matrix@v1
        with:
          tools_directory: 'tools'
          
  test:
    needs: configure-matrix
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{ fromJson(needs.configure-matrix.outputs.matrix) }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v2
        with:
          release: ${{ matrix.MATLABVersion }}
          
      - name: Setup Python
        if: matrix.pythonVersion
        uses: actions/setup-python@v4
        with:
          python-version: ${{ matrix.pythonVersion }}
          
      - name: Run Tests
        run: echo "Testing with MATLAB ${{ matrix.MATLABVersion }} and Python ${{ matrix.pythonVersion }}"
```

This example illustrates how the action can be used to configure a test matrix that is then consumed by a testing job. The matrix includes both MATLAB and Python versions, if some tests depends on python functionality

## Features

- Determines MATLAB versions from toolbox requirements
- Applies configuration constraints and version limits
- Maps compatible Python versions to MATLAB releases
- Handles version range calculations automatically
- Supports manual version overrides
- Configurable Python version inclusion
- Validates versions against MathWorks API limits

## Inputs

| Input | Description |
|-------|-------------|
| `tools_directory` | [Optional] Directory containing MLToolboxInfo.json (default: 'tools') |
| `matlab_versions` | [Optional] MATLAB versions to test - overrides auto-detection (default: '[]') |
| `python_versions` | [Optional] Python version mappings for specific MATLAB versions (default: '{}') |
| `include_python` | [Optional] Whether to include Python versions in the matrix (default: 'true') |

## Outputs

| Output | Description |
|--------|-------------|
| `matrix` | Test matrix with MATLAB and Python versions for GitHub Actions matrix strategy |
| `matlab_versions` | Determined MATLAB versions array |

## Version Determination Logic

The action determines MATLAB versions using the following priority order:
1. **Manual override**: If `matlab_versions` input is provided, those versions are used (filtered by config constraints)
2. **Toolbox requirements**: Reads MinimumMatlabRelease and MaximumMatlabRelease from MLToolboxInfo.json
3. **Configuration limits**: Applies minimum/maximum constraints from config.json
4. **API validation**: Validates against latest MATLAB release from MathWorks API

The action automatically generates all MATLAB releases (both 'a' and 'b' versions) within the determined range, ensuring comprehensive testing coverage.
