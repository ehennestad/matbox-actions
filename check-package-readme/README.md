# Action for checking the package readme
This action fails when the toolbox package built from `MLToolboxInfo.json` would have no readme.

From MATLAB R2026b an `.mltbx` file is a package file with a readme, which the Add-Ons panel and File Exchange show. File Exchange refuses a package file without one. The release workflows package with the latest MATLAB release, so the reusable `create-matrix-job.yml` runs this action before any test job starts, instead of letting the release fail after it is published.

The package has a readme when `MLToolboxInfo.json` has at least one of:

- `"README.md"` in the top-level `RootFilesToPackage` list. MatBox copies the repository README to the root of the package, where MATLAB uses it as the readme.
- A non-empty `Readme` under `ToolboxOptions`, which names the readme file.
- A `Description` under `ToolboxOptions` that is not empty or whitespace only. MATLAB writes it to a generated `README.md` in the package.

When none of them is present, the action fails with an error that names the first two ways to add a readme. A `README.md` committed in the source folder also becomes the readme, but the action does not see it, because it does not know the source folder.

## Usage
```yaml
- uses: ehennestad/matbox-actions/check-package-readme@v1
  with:
    # Directory containing MLToolboxInfo.json (optional)
    tools_directory: 'tools'
```

> [!NOTE]  
> This action only needs `jq`, which is preinstalled on GitHub-hosted runners. It does not need MATLAB.

## Example
`MLToolboxInfo.json` that packages the repository README as the readme:

```json
{
    "Namespace": "mytoolbox",
    "RootFilesToPackage": ["LICENSE", "README.md"],
    "ToolboxOptions": {
        "Identifier": "00000000-0000-0000-0000-000000000000",
        "ToolboxName": "My Toolbox",
        "Summary": "A short summary",
        "Description": ""
    }
}
```

## Tests
```bash
bash check-package-readme/tests/run_tests.sh
```
