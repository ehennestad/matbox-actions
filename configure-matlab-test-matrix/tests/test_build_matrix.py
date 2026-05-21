import importlib.util
import io
import json
import os
import tempfile
import unittest
from argparse import Namespace
from contextlib import redirect_stdout
from pathlib import Path


ACTION_DIR = Path(__file__).resolve().parents[1]
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"

spec = importlib.util.spec_from_file_location("build_matrix", ACTION_DIR / "build_matrix.py")
build_matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_matrix)


class BuildMatrixTest(unittest.TestCase):
    def run_builder(
        self,
        toolbox_fixture,
        *,
        latest_release="R2024b",
        matlab_versions="[]",
        python_versions="{}",
        include_python="true",
    ):
        args = Namespace(
            config_file=str(FIXTURES_DIR / "config.json"),
            toolbox_info_file=str(FIXTURES_DIR / toolbox_fixture),
            latest_release=latest_release,
            matlab_versions=matlab_versions,
            python_versions=python_versions,
            include_python=include_python,
        )
        with redirect_stdout(io.StringIO()):
            return build_matrix.run(args)

    def test_auto_versions_use_toolbox_range(self):
        outputs = self.run_builder("toolbox_range.json")

        self.assertEqual(
            json.loads(outputs["matlab_versions"]),
            ["R2022b", "R2023a", "R2023b", "R2024a"],
        )
        self.assertEqual(
            json.loads(outputs["matrix"]),
            {
                "MATLABVersion": ["R2022b", "R2023a", "R2023b", "R2024a"],
                "include": [
                    {"MATLABVersion": "R2022b", "pythonVersion": "3.10"},
                    {"MATLABVersion": "R2023a", "pythonVersion": "3.10"},
                    {"MATLABVersion": "R2023b", "pythonVersion": "3.11"},
                    {"MATLABVersion": "R2024a", "pythonVersion": "3.11"},
                ],
            },
        )

    def test_auto_versions_clamp_old_toolbox_minimum_to_config_minimum(self):
        outputs = self.run_builder("toolbox_old_minimum.json")

        self.assertEqual(json.loads(outputs["matlab_versions"]), ["R2021a", "R2021b"])

    def test_latest_toolbox_maximum_uses_latest_release(self):
        outputs = self.run_builder("toolbox_latest_maximum.json", latest_release="R2025a")

        self.assertEqual(json.loads(outputs["matlab_versions"]), ["R2024a", "R2024b", "R2025a"])

    def test_missing_toolbox_releases_use_config_minimum_and_latest_release(self):
        outputs = self.run_builder("toolbox_missing_releases.json", latest_release="R2021b")

        self.assertEqual(json.loads(outputs["matlab_versions"]), ["R2021a", "R2021b"])

    def test_manual_versions_are_filtered_by_supported_range(self):
        outputs = self.run_builder(
            "toolbox_range.json",
            latest_release="R2024a",
            matlab_versions='["R2020b", "R2021a", "R2024a", "R2024b"]',
        )

        self.assertEqual(json.loads(outputs["matlab_versions"]), ["R2021a", "R2024a"])

    def test_python_overrides_merge_with_defaults(self):
        outputs = self.run_builder(
            "toolbox_range.json",
            python_versions='{"R2023b": "3.12"}',
        )

        include = json.loads(outputs["matrix"])["include"]
        self.assertIn({"MATLABVersion": "R2023b", "pythonVersion": "3.12"}, include)

    def test_missing_python_mapping_uses_nearest_previous_release(self):
        outputs = self.run_builder("toolbox_latest_maximum.json", latest_release="R2026a")

        include = json.loads(outputs["matrix"])["include"]
        self.assertIn({"MATLABVersion": "R2026a", "pythonVersion": "3.13"}, include)

    def test_missing_python_mapping_fails_when_no_previous_mapping_exists(self):
        with self.assertRaisesRegex(ValueError, "no earlier MATLAB release mapping"):
            build_matrix.build_matrix(
                ["R2020b"],
                {"pythonVersions": {"R2021a": "3.8"}},
                {},
                include_python=True,
            )

    def test_python_override_can_supply_missing_latest_mapping(self):
        outputs = self.run_builder(
            "toolbox_latest_maximum.json",
            latest_release="R2026a",
            python_versions='{"R2026a": "3.14"}',
        )

        include = json.loads(outputs["matrix"])["include"]
        self.assertIn({"MATLABVersion": "R2026a", "pythonVersion": "3.14"}, include)

    def test_python_can_be_excluded(self):
        outputs = self.run_builder("toolbox_range.json", include_python="false")

        self.assertEqual(
            json.loads(outputs["matrix"]),
            {"MATLABVersion": ["R2022b", "R2023a", "R2023b", "R2024a"]},
        )

    def test_writes_github_outputs(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            output_path = Path(temp_dir) / "github_output.txt"
            previous_output = os.environ.get("GITHUB_OUTPUT")
            os.environ["GITHUB_OUTPUT"] = str(output_path)
            try:
                self.run_builder("toolbox_range.json", include_python="false")
            finally:
                if previous_output is None:
                    os.environ.pop("GITHUB_OUTPUT", None)
                else:
                    os.environ["GITHUB_OUTPUT"] = previous_output

            output_lines = output_path.read_text(encoding="utf-8").splitlines()

        self.assertIn('matlab_versions=["R2022b","R2023a","R2023b","R2024a"]', output_lines)
        self.assertIn(
            'matrix={"MATLABVersion":["R2022b","R2023a","R2023b","R2024a"]}',
            output_lines,
        )


if __name__ == "__main__":
    unittest.main()
