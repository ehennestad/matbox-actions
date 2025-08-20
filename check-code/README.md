# Action for checking MATLAB code
This action analyzes MATLAB code for code issues and uploads the analysis report to GitHub's security tab using SARIF format for integration with GitHub's code scanning features.

This action is used by MatBox workflows for code quality analysis and static code checking. It can run code analysis using a custom code check task function (if available in the tools directory) or fall back to MatBox's built-in code checking task. The action generates SARIF-formatted reports that integrate with GitHub's security and code scanning features, providing visibility into code quality issues directly in the GitHub interface.

The motivation is to provide automated code quality analysis for MATLAB toolboxes with seamless integration into GitHub's native code scanning and security features, enabling developers to identify and address code issues early in the development process.

## Usage
```yaml
- uses: ehennestad/matbox-actions/check-code@v1
  with:
    # Directory containing source code to analyze (optional)
    source_directory: './src'

    # Directory containing codecheckToolbox function (optional)
    tools_directory: './tools'
```

> [!NOTE]  
> This action requires MATLAB and MatBox to be installed in previous workflow steps. SARIF upload requires MATLAB R2023a or later.

## Example
```yaml
name: Code Quality Check

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  code-analysis:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v2
          
      - name: Install MatBox
        uses: ehennestad/matbox-actions/install-matbox@v1
        
      - name: Check Code Quality
        uses: ehennestad/matbox-actions/check-code@v1
        with:
          source_directory: './src'
          tools_directory: './tools'
```

This example illustrates how the action can be used to perform automated code quality analysis. The SARIF report is automatically uploaded to GitHub's security tab, where code issues can be reviewed and tracked.

## Features

- Analyzes MATLAB code for quality issues and potential problems
- Supports both custom `codecheckToolbox` task function and MatBox defaults
- Generates SARIF-formatted reports for GitHub integration
- Uploads results to GitHub's security and code scanning features
- Continues execution even if SARIF upload fails

## Inputs

| Input | Description |
|-------|-------------|
| `source_directory` | [Optional] Directory containing source code to analyze (default: './src') |
| `tools_directory` | [Optional] Directory containing codecheckToolbox function (default: './tools') |

## Outputs

This action does not produce direct outputs, but generates a SARIF report at `docs/reports/code_issues.sarif` and uploads it to GitHub's security tab for code scanning integration.

## Code Check Function Priority

The action uses the following priority order for code analysis:
1. **Custom function**: If `codecheckToolbox` exists in the tools directory, it will be used
2. **MatBox function**: Falls back to `matbox.tasks.codecheckToolbox` with the specified code directory

Both functions generate SARIF-formatted reports compatible with GitHub's code scanning features.
