"""Regression tests for the incremental Core/Mobile import boundary."""
from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from architecture_guard import (
    CATEGORIES,
    BASELINE_TRANSITIVE,
    assess,
    fingerprint,
    load_baseline,
)
from architecture_inventory import audit


class ArchitectureGuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.frozen = load_baseline(
            ROOT / "docs/architecture/STK_CORE_LEGACY_IMPORT_BASELINE_20261123.md"
        )

    def test_frozen_baseline_is_intact(self):
        self.assertEqual(len(self.frozen), 303)
        self.assertEqual(len(BASELINE_TRANSITIVE), 2)

    def test_removed_legacy_import_is_allowed(self):
        empty = {
            "direct": {category: [] for category in CATEGORIES},
            "core_ui_transitive": [],
        }
        result = assess(empty, self.frozen)
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["removed_legacy_declarations"], 303)

    def test_existing_exact_declaration_does_not_count_as_new(self):
        path = "packages/core/lib/features/workout/application/active_workout_provider.dart"
        uri = "package:flutter/widgets.dart"
        report = {
            "direct": {category: [] for category in CATEGORIES},
            "core_ui_transitive": [],
        }
        report["direct"]["core_ui"].append({"path": path, "uri": uri})
        self.assertIn(fingerprint(path, uri), self.frozen)
        result = assess(report, self.frozen)
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["remaining_legacy_declarations"], 1)

    def test_new_material_import_in_core_is_rejected(self):
        with tempfile.TemporaryDirectory() as workdir:
            root = Path(workdir)
            target = root / "packages/core/lib/features/workout/application/new_widget.dart"
            target.parent.mkdir(parents=True)
            target.write_text(
                "import 'package:flutter/material.dart';\n"
                "class NewWidget extends StatelessWidget {\n"
                "  const NewWidget({super.key});\n"
                "  @override Widget build(BuildContext c) => const SizedBox();\n"
                "}\n",
                encoding="utf-8",
            )
            result = assess(audit(root), self.frozen)
            self.assertEqual(result["status"], "fail")
            self.assertTrue(any("new_widget.dart" in v["path"]
                                for v in result["new_prohibited_declarations"]))

    def test_new_mobile_to_web_import_is_rejected(self):
        with tempfile.TemporaryDirectory() as workdir:
            root = Path(workdir)
            target = root / "apps/app_mobile/lib/features/profile/a.dart"
            target.parent.mkdir(parents=True)
            target.write_text(
                "import 'package:gym_tracker_web/features/profile/private_web_page.dart';\n",
                encoding="utf-8",
            )
            result = assess(audit(root), self.frozen)
            self.assertEqual(result["status"], "fail")
            self.assertEqual(result["mobile_to_web_direct_count"], 1)

    def test_new_core_transitive_ui_dependency_is_rejected(self):
        report = {
            "direct": {category: [] for category in CATEGORIES},
            "core_ui_transitive": ["packages/core/lib/features/home/application/new_bad.dart"],
        }
        result = assess(report, self.frozen)
        self.assertEqual(result["status"], "fail")
        self.assertEqual(len(result["new_transitive_core_ui_paths"]), 1)

    def test_old_transitive_dependencies_are_frozen(self):
        report = {
            "direct": {category: [] for category in CATEGORIES},
            "core_ui_transitive": sorted(BASELINE_TRANSITIVE),
        }
        self.assertEqual(assess(report, self.frozen)["status"], "pass")


if __name__ == "__main__":
    unittest.main()
