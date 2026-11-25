"""Strict architecture boundary regression tests (no Flutter runtime)."""
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from core_purity_gate import inspect


class CorePurityGateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write("packages/core/pubspec.yaml",
                   "name: core\ndependencies:\n  hive: ^2.2.3\ndev_dependencies:\n  test: ^1.26.3\n")
        self.write("packages/core/lib/logic.dart", "class Logic {}")
        self.write("apps/app_web/lib/page.dart", "class WebPage {}")
        self.write("apps/app_mobile/lib/page.dart", "import 'package:core/logic.dart';")

    def write(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

    def test_clean_dart_and_mobile_boundary(self):
        self.assertEqual(inspect(self.root)["status"], "pass")

    def test_historical_core_flutter_import_is_not_exempt(self):
        self.write("packages/core/lib/features/workout/application/active_workout_provider.dart",
                   "import 'package:flutter/widgets.dart';")
        self.assertEqual(inspect(self.root)["status"], "fail")

    def test_core_test_cannot_import_flutter(self):
        self.write("packages/core/test/bad.dart", "import 'package:flutter_test/flutter_test.dart';")
        self.assertEqual(inspect(self.root)["status"], "fail")

    def test_mobile_test_cannot_import_web(self):
        self.write("apps/app_mobile/test/bad.dart", "export 'package:gym_tracker_web/page.dart';")
        self.assertEqual(inspect(self.root)["status"], "fail")

    def test_conditional_browser_import_is_rejected(self):
        self.write("packages/core/lib/bad.dart",
                   "import 'logic.dart' if (dart.library.html) 'dart:html';")
        self.assertEqual(inspect(self.root)["status"], "fail")

    def test_unknown_plugin_without_import_is_rejected(self):
        self.write("packages/core/pubspec.yaml",
                   "name: core\ndependencies:\n  some_new_plugin: ^1.0.0\n")
        self.assertEqual(inspect(self.root)["status"], "fail")

    def test_dependency_override_of_approved_name_is_rejected(self):
        self.write("packages/core/pubspec.yaml",
                   "name: core\ndependencies:\n  hive:\n    path: ../mobile_hive\n")
        self.assertEqual(inspect(self.root)["status"], "fail")

    def test_inline_dependency_mapping_is_rejected(self):
        self.write("packages/core/pubspec.yaml",
                   "name: core\ndependencies: {hive: ^2.2.3, flutter: any}\n")
        self.assertEqual(inspect(self.root)["status"], "fail")

    def test_top_level_dependency_overrides_are_rejected(self):
        self.write("packages/core/pubspec.yaml",
                   "name: core\ndependency_overrides:\n  hive: ^2.2.3\n")
        self.assertEqual(inspect(self.root)["status"], "fail")

    def test_unexpected_dependency_indentation_is_rejected(self):
        self.write("packages/core/pubspec.yaml",
                   "name: core\ndependencies:\n    flutter: any\n")
        self.assertEqual(inspect(self.root)["status"], "fail")

    def test_quoted_version_constraint_and_comment_are_accepted(self):
        self.write("packages/core/pubspec.yaml",
                   'name: core\ndependencies:\n  hive: ">=2.2.0 <3.0.0" # valid\n')
        self.assertEqual(inspect(self.root)["status"], "pass")


if __name__ == "__main__":
    unittest.main()
