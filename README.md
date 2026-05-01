<a href="https://github.com/user-attachments/assets/7309a8d9-eb9f-40ce-ac67-53769cca5af3">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/7309a8d9-eb9f-40ce-ac67-53769cca5af3">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/7309a8d9-eb9f-40ce-ac67-53769cca5af3">
    <img alt="matbox-actions-logo" src="https://github.com/user-attachments/assets/7309a8d9-eb9f-40ce-ac67-53769cca5af3" title="matbox-actions" align="right" height="70"​>
  </picture>
</a>


# matbox-actions

A collection of GitHub Actions for MATLAB toolbox development, testing, and release automation using the MatBox toolbox. These actions provide a complete CI/CD solution for MATLAB toolbox projects with automated testing, code analysis, packaging, and release management.

<div align="center">
  <img src="https://github.com/user-attachments/assets/99ff243f-f5b8-404b-85e0-b0984df15896" alt="chat_gpt_illustration_inspired_by_sven_nordquist" title="Illustration by ChatGPT, inspired by Sven Nordquist" width=550px height=auto>

</div>

<p align="center"><strong>
Is your toolbox full of code smells, bugs, and curious critters?<br>
matbox-actions helps you test, polish, and release with confidence!
</strong></p>

## Overview

matbox-actions enables automated workflows for MATLAB toolbox development by providing:

- **Code Quality Analysis** - Static code analysis with SARIF integration for GitHub's security tab
- **Automated Testing** - Test suite execution with report generation and badge creation
- **Release Management** - Automated toolbox packaging and GitHub release creation
- **Workflow Templates** - Ready-to-use workflow templates for common CI/CD scenarios

All actions are built around the [MatBox toolbox](https://github.com/ehennestad/MatBox) and support both custom task functions and built-in MatBox functionality.

## Quick Start

### 1. Repository Structure

Organize your MATLAB toolbox repository with the following structure:

```
your-toolbox/
├── src/                    # Main MATLAB source code
├── tests/                  # Unittests and test helpers
├── tools/                  # CI tools and metadata
│   ├── MLToolboxInfo.json  # Toolbox metadata
│   └── tasks/              # Custom/extended MatBox task functions (optional)
└── .github/
    └── workflows/          # GitHub workflow files
```

### 2. Basic Workflow Example

```yaml
name: Test and Analyze Code

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
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
        
      - name: Test Code
        uses: ehennestad/matbox-actions/test-code@v1
        
      - name: Check Code Quality
        uses: ehennestad/matbox-actions/check-code@v1
```

## Available Actions

### Core Actions

| Action | Description |
|--------|-------------|
| [`install-matbox`](./install-matbox/) | Install MatBox framework in MATLAB environment |
| [`test-code`](./test-code/) | Run MATLAB test suites with report generation |
| [`check-code`](./check-code/) | Analyze MATLAB code quality with SARIF integration |
| [`package-toolbox`](./package-toolbox/) | Package MATLAB toolbox into MLTBX file |

### Release and Utility Actions

| Action | Description |
|--------|-------------|
| [`create-github-release`](./create-github-release/) | Create GitHub releases with MLTBX attachments |
| [`validate-version`](./validate-version/) | Validate version numbers and extract from git tags |
| [`configure-matlab-test-matrix`](./configure-matlab-test-matrix/) | Configure MATLAB version test matrices |
| [`generate-tested-with-badge`](./generate-tested-with-badge/) | Generate "tested with" badges for MATLAB versions |
| [`push-badges`](./push-badges/) | Push generated badges to repository |

## Badge Updates

The reusable code analysis and test workflows commit generated badges on `push` events and ready pull requests by default. Draft pull requests skip badge generation and badge commits.

Use the `update_badges` input to opt out of badge commits or restrict stable branch updates:

```yaml
jobs:
  test:
    uses: ehennestad/matbox-actions/.github/workflows/test-code-workflow.yml@v1
    with:
      update_badges: ${{ github.event_name == 'push' && (
        github.ref == 'refs/heads/main' ||
        github.ref == 'refs/heads/dev' ||
        startsWith(github.ref, 'refs/heads/release/')
      ) }}
```

If `update_badges` is omitted, badge updates run for all `push` events and same-repository pull requests that are ready for review. To run badge updates when a draft pull request becomes ready, include the `ready_for_review` activity type in the calling workflow's `pull_request` trigger.

## Workflow Templates

Pre-configured workflow templates are available in [`.github/workflow-templates/`](./.github/workflow-templates/) for common scenarios:

- **`analyse-code.yml`** - Code analysis workflow
- **`test-code.yml`** - Comprehensive testing workflow  
- **`prepare-release.yml`** - Complete release automation
- **`run-codespell.yml`** - Spell checking for documentation

See the [workflow templates README](./.github/workflow-templates/README.md) for detailed usage instructions.

## Features

### 🔍 Code Quality Analysis
- Static code analysis with MATLAB Code Analyzer
- SARIF report generation for GitHub security integration
- Custom code check task support

### 🧪 Automated Testing
- Unit test execution with customizable test runners
- Test report generation and publishing
- Badge creation for test status
- Multi-version MATLAB testing support

### 📦 Release Automation
- Automated toolbox packaging with version management
- GitHub release creation with MLTBX attachments
- Version validation and tag processing
- Release notes generation

### 🎯 Customization
- Support for custom MatBox task functions
- Configurable directory structures
- Flexible MATLAB version matrices
- Optional Python integration support

## Requirements

- **MATLAB**: Actions require MATLAB to be installed (use [`matlab-actions/setup-matlab`](https://github.com/matlab-actions/setup-matlab))
- **MatBox toolbox**: Automatically installed by the `install-matbox` action
- **Repository Structure**: Follow the recommended directory layout with `src/`, `tests/` and `tools/` directories
- **Metadata**: `MLToolboxInfo.json` file required for packaging and release workflows

## Advanced Usage

### Custom Task Functions

You can override default behavior by providing custom MatBox task functions in your `tools/` directory:

- `testToolbox.m` - Custom test execution
- `codecheckToolbox.m` - Custom code analysis  
- `packageToolbox.m` - Custom packaging logic
- `verifyToolboxInstallation` - Verify installation of a packaged toolbox

### Release Workflow

Automate releases on version tags:

```yaml
on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+' # Matches v1.2.3

jobs:
  release:
    uses: ehennestad/matbox-actions/.github/workflows/prepare-release-workflow.yml@v1
    with:
      source_directory: src
      tools_directory: tools
    secrets:
      DEPLOY_KEY: ${{ secrets.DEPLOY_KEY }}
```

## Contributing

Contributions are welcome! Please see individual action directories for specific documentation and examples.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [MatBox](https://github.com/ehennestad/MatBox) - MATLAB toolbox development framework
- [matlab-actions](https://github.com/matlab-actions) - Official MATLAB GitHub Actions
