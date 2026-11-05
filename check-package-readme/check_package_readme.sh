#!/usr/bin/env bash
# Check that the toolbox package built from MLToolboxInfo.json will have a readme.
#
# Usage: check_package_readme.sh [tools_directory]
#
#   tools_directory  Directory containing MLToolboxInfo.json (default: tools)
#
# From MATLAB R2026b an .mltbx file is a package file with a readme, and
# File Exchange refuses a package file without one. The package has a readme
# when MLToolboxInfo.json has at least one of:
#   - a top-level RootFilesToPackage list that contains "README.md". MatBox
#     copies the file to the root of the package, where MATLAB uses it as
#     the readme.
#   - a non-empty ToolboxOptions.Readme, which names the readme file.
#   - a ToolboxOptions.Description that is not empty or whitespace only.
#     MATLAB writes it to a README.md in the package.
set -euo pipefail

toolsDirectory="${1:-tools}"
toolboxInfoFile="${toolsDirectory}/MLToolboxInfo.json"

if [ ! -f "$toolboxInfoFile" ]; then
    echo "::error::${toolboxInfoFile} does not exist. The release workflow reads the toolbox metadata from it."
    exit 1
fi

if ! jq empty "$toolboxInfoFile" 2>/dev/null; then
    echo "::error file=${toolboxInfoFile}::${toolboxInfoFile} is not valid JSON. Fix the file before releasing."
    exit 1
fi

# RootFilesToPackage may be a list or a single file name.
listsReadmeFile="$(jq '(.RootFilesToPackage // []) | (if type == "string" then [.] else . end) | index("README.md") != null' "$toolboxInfoFile")"
hasReadmeOption="$(jq '(.ToolboxOptions.Readme // "") | (type == "string" and test("\\S"))' "$toolboxInfoFile")"
hasDescription="$(jq '(.ToolboxOptions.Description // "") | (type == "string" and test("\\S"))' "$toolboxInfoFile")"

if [ "$listsReadmeFile" = "true" ]; then
    echo "The package readme is README.md, listed in RootFilesToPackage."
elif [ "$hasReadmeOption" = "true" ]; then
    echo "The package readme is $(jq -r '.ToolboxOptions.Readme' "$toolboxInfoFile"), set as ToolboxOptions.Readme."
elif [ "$hasDescription" = "true" ]; then
    echo "The package readme is generated from ToolboxOptions.Description."
else
    echo "::error file=${toolboxInfoFile}::The packaged toolbox will have no readme, and File Exchange refuses a package without one. Add \"README.md\" to the top-level \"RootFilesToPackage\" list in ${toolboxInfoFile} to package the repository README, or write a description of the toolbox in \"Description\" under \"ToolboxOptions\"."
    exit 1
fi
