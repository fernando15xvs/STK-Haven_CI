#!/usr/bin/env python3
"""Strict Phase C exit gate: pure Dart Core, no UI or platform imports.

Web is paused: its historical imports are excluded from missing-target checks.
"""
from __future__ import annotations

from pathlib import Path
import json
import sys

from architecture_inventory import audit

ROOT = Path(__file__).resolve().parent.parent
CHECKED = ("packages/core/lib/", "packages/core/test/",
           "apps/app_mobile/lib/", "apps/app_mobile/test/")


def inspect(root: Path = ROOT) -> dict:
    report = audit(root)
    direct = report["direct"]
    forbidden = {
        name: items
        for name, items in direct.items()
        if name in {
            "core_ui", "core_flutter", "core_platform_packages",
            "core_to_mobile_or_web", "mobile_to_web", "mobile_to_core_ui",
        } and items
    }
    core_ui_files = sorted(
        p.relative_to(root).as_posix()
        for p in (root / "packages/core/lib").rglob("*.dart")
        if "/presentation/" in p.as_posix() or "/core/theme/" in p.as_posix()
    )
    unresolved = [
        entry for entry in report["unresolved_imports"]
        if entry["path"].startswith(CHECKED)
    ]
    return {
        "status": "pass" if not (forbidden or core_ui_files or
                               report["core_ui_transitive"] or unresolved)
                  else "fail",
        "direct": forbidden,
        "core_ui_files": core_ui_files,
        "core_ui_transitive": report["core_ui_transitive"],
        "unresolved_core_or_mobile_imports": unresolved,
        "total_checked_dart": report["total_dart"],
    }


def main() -> int:
    result = inspect()
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
