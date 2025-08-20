# Workflow Templates

This directory contains GitHub workflow templates for MATLAB toolbox development using matbox-actions. These templates provide ready-to-use CI/CD workflows that can be easily added to MATLAB toolbox repositories.

## Available Templates

### Code Analysis and Testing

- **`analyse-code.yml`** - Runs code analysis on MATLAB code using MatBox tools
- **`test-code.yml`** - Comprehensive testing workflow that runs code analysis and unit tests
- **`run-codespell.yml`** - Spell checking workflow for documentation and comments

### Release Management

- **`prepare-release.yml`** - Complete release workflow for packaging and publishing MATLAB toolboxes
- **`prepare-release-modular.yml`** - Modular version of the release workflow with additional customization options

## Usage

These templates are designed to work with repositories that follow the matbox-actions conventions:

- **Source code directory**: Contains the main MATLAB source code. Default: `src`.
- **Tests directory**: Contains unit tests, test helpers, etc. Default: `tests`.
- **Tools directory**: Contains CI tools, and `MLToolboxInfo.json` metadata file. Default: `tools`.

### Getting Started

1. [Add these templates](https://docs.github.com/en/actions/sharing-automations/creating-workflow-templates-for-your-organization) to the `workflow-templates` folder in a `.github` repository in your GitHub organization
2. Navigate to your repository's "Actions" tab
3. Click "New workflow"
4. Look for these templates in the workflow template suggestions
5. Choose the appropriate template for your needs
6. Customize the configuration parameters as needed

### Configuration

Each template includes configurable parameters such as:

- Directory paths for source, tests and tools folders
- MATLAB release versions
- Additional MATLAB products to install
- Python version requirements (for toolboxes with Python dependencies)
- Caching options for faster builds

## Requirements

- Repository must be set up for MATLAB toolbox development
- For release workflows: `DEPLOY_KEY` secret must be configured for protected branch access
- Recommended directory structure with `src`, `tests` and `tools` folders

## Related Actions

These templates use the custom actions defined in the [matbox-actions](https://github.com/ehennestad/matbox-actions) repository.
