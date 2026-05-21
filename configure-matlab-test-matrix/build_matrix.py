#!/usr/bin/env python3
"""Build MATLAB/Python GitHub Actions matrices for MatBox workflows."""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
from typing import Any


# Match MATLAB release names such as R2025a.
RELEASE_PATTERN = re.compile(r"^R(?P<year>\d{4})(?P<half>[ab])$")


def parse_release(release: str) -> tuple[int, str]:
    match = RELEASE_PATTERN.match(release)
    if not match:
        raise ValueError(f"Invalid MATLAB release: {release!r}")
    return int(match.group("year")), match.group("half")


def compare_releases(left: str, right: str) -> int:
    left_year, left_half = parse_release(left)
    right_year, right_half = parse_release(right)
    if left_year != right_year:
        return left_year - right_year
    return (left_half > right_half) - (left_half < right_half)


def max_release(left: str, right: str) -> str:
    return left if compare_releases(left, right) >= 0 else right


def min_release(left: str, right: str) -> str:
    return left if compare_releases(left, right) <= 0 else right


def is_blank(value: Any) -> bool:
    return value is None or value == ""


def generate_matlab_releases(minimum: str, maximum: str) -> list[str]:
    min_year, min_half = parse_release(minimum)
    max_year, max_half = parse_release(maximum)

    if compare_releases(minimum, maximum) > 0:
        return []

    releases: list[str] = []
    for year in range(min_year, max_year + 1):
        if year == min_year and year == max_year:
            start_half = min_half
            end_half = max_half
        elif year == min_year:
            start_half = min_half
            end_half = "b"
        elif year == max_year:
            start_half = "a"
            end_half = max_half
        else:
            start_half = "a"
            end_half = "b"

        if start_half == "a":
            releases.append(f"R{year}a")
            if end_half == "b":
                releases.append(f"R{year}b")
        elif start_half == "b":
            releases.append(f"R{year}b")

    return releases


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def parse_json_input(value: str, default: Any) -> Any:
    if value in ("", "null"):
        return default
    return json.loads(value)


def determine_auto_matlab_versions(
    toolbox_info: dict[str, Any],
    config: dict[str, Any],
    latest_release: str,
) -> list[str]:
    options = toolbox_info.get("ToolboxOptions", {})
    config_min = config["minimumMatlabRelease"]
    min_raw = options.get("MinimumMatlabRelease")
    max_raw = options.get("MaximumMatlabRelease")

    minimum = config_min
    if not is_blank(min_raw):
        minimum = max_release(str(min_raw), config_min)

    maximum = latest_release
    if not is_blank(max_raw) and str(max_raw).lower() != "latest":
        maximum = min_release(str(max_raw), latest_release)

    return generate_matlab_releases(minimum, maximum)


def filter_manual_matlab_versions(
    versions: list[str],
    config: dict[str, Any],
    latest_release: str,
) -> list[str]:
    config_min = config["minimumMatlabRelease"]
    result = []
    for version in versions:
        if compare_releases(version, config_min) >= 0 and compare_releases(version, latest_release) <= 0:
            result.append(version)
        else:
            print(f"Excluding {version} (outside config range {config_min} to {latest_release})")
    return result


def resolve_python_version(version: str, python_versions: dict[str, str]) -> tuple[str, str]:
    if version in python_versions:
        return python_versions[version], version

    previous_versions = [
        mapped_version
        for mapped_version in python_versions
        if compare_releases(mapped_version, version) < 0
    ]
    if not previous_versions:
        raise ValueError(
            "Missing Python version mapping for MATLAB release "
            f"{version}, and no earlier MATLAB release mapping is available."
        )

    nearest_version = max(previous_versions, key=lambda mapped_version: parse_release(mapped_version))
    return python_versions[nearest_version], nearest_version


def build_matrix(
    matlab_versions: list[str],
    config: dict[str, Any],
    python_overrides: dict[str, str],
    include_python: bool,
) -> dict[str, Any]:
    matrix: dict[str, Any] = {"MATLABVersion": matlab_versions}
    if not include_python:
        return matrix

    python_versions = dict(config.get("pythonVersions", {}))
    python_versions.update(python_overrides)
    include = []
    for version in matlab_versions:
        python_version, source_version = resolve_python_version(version, python_versions)
        if source_version != version:
            print(f"Using Python {python_version} from {source_version} for {version}")
        include.append({"MATLABVersion": version, "pythonVersion": python_version})

    matrix["include"] = include
    return matrix


def write_github_output(values: dict[str, str], output_path: str | None) -> None:
    if output_path is None:
        return
    with Path(output_path).open("a", encoding="utf-8") as file:
        for key, value in values.items():
            file.write(f"{key}={value}\n")


def run(args: argparse.Namespace) -> dict[str, str]:
    config = load_json(Path(args.config_file))
    toolbox_info = load_json(Path(args.toolbox_info_file))
    manual_versions = parse_json_input(args.matlab_versions, [])
    python_overrides = parse_json_input(args.python_versions, {})
    include_python = args.include_python.lower() == "true"

    if manual_versions:
        matlab_versions = filter_manual_matlab_versions(manual_versions, config, args.latest_release)
        print(f"Using input MATLAB versions (filtered by config limits): {json.dumps(matlab_versions)}")
    else:
        matlab_versions = determine_auto_matlab_versions(toolbox_info, config, args.latest_release)
        print(f"Using auto-determined MATLAB versions: {json.dumps(matlab_versions)}")

    matrix = build_matrix(matlab_versions, config, python_overrides, include_python)
    output_values = {
        "matlab_versions": json.dumps(matlab_versions, separators=(",", ":")),
        "matrix": json.dumps(matrix, separators=(",", ":")),
    }

    print(f"Generated MATLAB versions: {output_values['matlab_versions']}")
    print(f"Generated matrix: {output_values['matrix']}")
    write_github_output(output_values, os.environ.get("GITHUB_OUTPUT"))
    return output_values


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config-file", required=True)
    parser.add_argument("--toolbox-info-file", required=True)
    parser.add_argument("--latest-release", required=True)
    parser.add_argument("--matlab-versions", default="[]")
    parser.add_argument("--python-versions", default="{}")
    parser.add_argument("--include-python", default="true")
    return parser.parse_args()


if __name__ == "__main__":
    run(parse_args())
