#!/usr/bin/env python3
"""Strict Phase C exit gate: pure Dart Core, no UI or platform imports.

Web is paused: its historical imports are excluded from missing-target checks.
"""
from __future__ import annotations

from pathlib import Path
import json
import re
import sys

from architecture_inventory import audit, resolve_uri, platform_package

ROOT = Path(__file__).resolve().parent.parent
CHECKED = ("packages/core/lib/", "packages/core/test/",
           "apps/app_mobile/lib/", "apps/app_mobile/test/")


# These are the reviewed Dart-only direct dependencies, not exceptions for
# prohibited imports. A new dependency requires a review of its SDK/platform
# requirements, rather than silently extending the old migration baseline.
PURE_CORE_DEPENDENCIES = frozenset({
    "riverpod", "supabase", "hive", "intl", "uuid", "path", "http", "csv",
    "test", "lints",
})
FORBIDDEN_DART = frozenset({
    "dart:ui", "dart:html", "dart:js", "dart:js_util", "dart:js_interop",
    "dart:js_interop_unsafe", "dart:svg", "dart:web_audio",
})


def manifest_violations(root: Path) -> list[str]:
    manifest = root / "packages/core/pubspec.yaml"
    if not manifest.is_file():
        return ["missing Core pubspec.yaml"]
    content = manifest.read_text(encoding="utf-8")
    violations = []
    section = ""
    for raw in content.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        # Deliberately use explicit ASCII classes: no double escaping in
        # Python raw strings. Accept the reviewed block-form YAML only.
        top = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*):[ ]*(.*)", line)
        if top:
            section, value = top.groups()
            if section in {"flutter", "dependency_overrides"}:
                violations.append(f"forbidden Core manifest section: {section}")
            if section in {"dependencies", "dev_dependencies"} and value not in {"", "{}"}:
                violations.append(f"unsupported inline Core dependency section: {section}")
            continue
        if section not in {"dependencies", "dev_dependencies"}:
            continue
        dep = re.fullmatch(r"  ([A-Za-z_][A-Za-z0-9_]*):[ ]*(.*)", line)
        if not dep:
            violations.append(f"unsupported Core dependency declaration: {line.strip()}")
            continue
        name, version = dep.groups()
        if name not in PURE_CORE_DEPENDENCIES:
            violations.append(f"unreviewed Core dependency: {name}")
        # Only simple version constraints are accepted, not SDK/path/git
        # mappings or inline dependency objects.
        if len(version) >= 2 and version[0] in ('"', "'") and version[-1] == version[0]:
            version = version[1:-1]
        if not re.fullmatch(r"[0-9.^~<>=*+ -]+", version):
            violations.append(f"non-version Core dependency: {name}")
    return violations


def boundary_violations(report: dict) -> list[dict]:
    failures = []
    for path, uris in report["all_imports"].items():
        core = path.startswith(("packages/core/lib/", "packages/core/test/"))
        mobile = path.startswith(("apps/app_mobile/lib/", "apps/app_mobile/test/"))
        if not (core or mobile):
            continue
        for uri in uris:
            target = resolve_uri(path, uri)
            package = uri[8:].split("/", 1)[0] if uri.startswith("package:") else ""
            web = (package == "gym_tracker_web" or "apps/app_web/" in uri
                   or bool(target and target.startswith("apps/app_web/")))
            mobile_target = (package == "gym_tracker" or "apps/app_mobile/" in uri
                             or bool(target and target.startswith("apps/app_mobile/")))
            forbidden = (mobile and web) or (core and (
                web or mobile_target or uri in FORBIDDEN_DART
                or platform_package(uri) is not None
                or package.startswith("flutter")
            ))
            if forbidden:
                failures.append({"path": path, "uri": uri})
    return failures


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
    manifest = manifest_violations(root)
    boundary = boundary_violations(report)
    return {
        "status": "pass" if not (forbidden or core_ui_files or
                               report["core_ui_transitive"] or unresolved
                               or manifest or boundary)
                  else "fail",
        "core_manifest_violations": manifest,
        "production_and_test_boundary_violations": boundary,
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
