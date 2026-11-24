"""Core repositories must use pure Dart Hive contracts, not the Flutter plugin."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
REPOSITORIES = (
    "features/profile/data/settings_repository.dart",
    "features/routines/data/routine_repository.dart",
    "features/workout/data/active_workout_repository.dart",
    "features/home/data/hydration_repository.dart",
    "features/workout/data/workout_repository.dart",
    "features/workout/data/personal_record_repository.dart",
    "features/profile/data/gamification_repository.dart",
    "features/profile/data/personal_reminder_repository.dart",
)


class PureHiveRepositoryContractTest(unittest.TestCase):
    def test_no_flutter_hive_dependency_in_migrated_repositories(self):
        for name in REPOSITORIES:
            with self.subTest(name=name):
                path = ROOT / "packages/core/lib" / name
                text = path.read_text(encoding="utf-8")
                self.assertIn("import 'package:hive/hive.dart';", text)
                self.assertNotIn("hive_flutter", text)
                self.assertNotIn("initFlutter(", text)


if __name__ == "__main__":
    unittest.main()
