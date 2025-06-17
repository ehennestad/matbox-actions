# Action for testing MATLAB code
This action runs MATLAB test suites for a toolbox using either custom test functions or MatBox testing framework, with support for test report generation and result publishing.

This action is used by MatBox workflows responsible for executing testing of MATLAB toolboxes. It can run tests using custom test functions (if available in the tools directory) or fall back to MatBox's built-in testing task. The action supports test report generation, badge creation, and automatic publishing of test results to GitHub Actions for visibility in pull requests and workflow summaries.

The motivation is to provide a standardized way to execute MATLAB toolbox tests across different environments while also making it easy to customize the test execution using a custom MatBox test task function.

## Usage
```yaml
- uses: ehennestad/matbox-actions/test-code@v1
  with:
    # Source code directory to add to MATLAB path (optional)
    source_directory: './src'

    # Directory containing testToolbox function (optional)
    tools_directory: './tools'

    # Directory containing test suites (optional)
    tests_directory: './tests'

    # Subdirectory for test reports - useful for matrix testing (optional)
    report_subdirectory: 'R2023a'

    # Whether to create test badges (optional)
    create_badge: 'true'
```

> [!NOTE]  
> This action requires MATLAB and MatBox to be installed in previous workflow steps.

## Example
```yaml
name: Test Toolbox

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        MATLABVersion: ['R2023a', 'R2023b', 'R2024a']
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v2
        with:
          release: ${{ matrix.MATLABVersion }}
          
      - name: Install MatBox
        uses: ehennestad/matbox-actions/install-matbox@v1
        
      - name: Test code
        uses: ehennestad/matbox-actions/test-code@v1
        with:
          source_directory: './src'
          tools_directory: './tools'
          tests_directory: './tests'
          report_subdirectory: ${{ matrix.MATLABVersion }}
          create_badge: 'true'
          
      - name: Upload test reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-reports-${{ matrix.MATLABVersion }}
          path: docs/reports/
```

This example illustrates how the action can be used to test a toolbox across multiple MATLAB versions using a matrix strategy. Test reports are generated with version-specific subdirectories and uploaded as artifacts for use in subsequent workflow steps.

## Features

- Runs MATLAB test suites using custom task or MatBox testing task
- Supports both custom testToolbox functions and MatBox defaults
- Creates test badges automatically
- Publishes test results to GitHub Actions interface
- Supports matrix testing with version-specific report organization

## Inputs

| Input | Description |
|-------|-------------|
| `source_directory` | [Optional] Source code directory to add to MATLAB path (default: './code') |
| `tools_directory` | [Optional] Directory containing testToolbox function (default: './tools') |
| `tests_directory` | [Optional] Directory containing test suites (default: './tests') |
| `report_subdirectory` | [Optional] Subdirectory for test reports - useful for matrix testing (default: '') |
| `create_badge` | [Optional] Whether to create test badges (default: 'true') |

## Outputs

This action does not produce direct outputs, but generates test reports at `docs/reports/**/test-results.xml` and publishes test results to the GitHub Actions interface.

## Test Function Priority

The action uses the following priority order for test execution:
1. **Custom function**: If `testToolbox` exists in the tools directory, it will be used
2. **MatBox function**: Falls back to `matbox.tasks.testToolbox` with specified parameters

Both functions support the same parameter set for consistent behavior across custom and default implementations.
