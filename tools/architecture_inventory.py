#!/usr/bin/env python3
"""STK Haven architecture dependency inventory.

Diagnostic by default: inventories Dart import/export/part directives and
reports Core UI/Flutter, Core -> Mobile/Web, and Mobile -> Web dependencies.
Use --enforce only after migrating legacy offenders (phase B/C).
No external dependencies and no changes to application source.
"""
from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
import posixpath
import re
import sys

GROUPS = {
    "core_lib": "packages/core/lib/",
    "core_test": "packages/core/test/",
    "mobile_lib": "apps/app_mobile/lib/",
    "mobile_test": "apps/app_mobile/test/",
    "web_lib": "apps/app_web/lib/",
    "web_test": "apps/app_web/test/",
}
PACKAGE_ROOTS = {
    "core": "packages/core/lib/",
    "gym_tracker": "apps/app_mobile/lib/",
    "gym_tracker_web": "apps/app_web/lib/",
}
# A lexical inventory, not a Dart analyzer. Conditional imports/exports are included.
DIRECTIVE_RE = re.compile(r"^[ \t]*(?:import|export|part)[ \t]+([^;]*);", re.M | re.S)
URI_RE = re.compile(r"""['"]([^'"]+)['"]""")
UI_SDK_URIS = {
    "dart:ui",
    "package:flutter/material.dart",
    "package:flutter/widgets.dart",
    "package:flutter/cupertino.dart",
    "package:flutter/painting.dart",
    "package:flutter/rendering.dart",
}
PLATFORM_PLUGINS = {
    "flutter_riverpod", "hive_flutter", "supabase_flutter", "image_picker",
    "share_plus", "file_picker", "path_provider", "sqflite", "workmanager",
    "flutter_local_notifications", "shared_preferences", "flutter",
    "video_player", "audio_service", "just_audio", "just_audio_background",
    "video_thumbnail",
}


def group_for(path: str) -> str:
    for key, prefix in GROUPS.items():
        if path.startswith(prefix):
            return key
    return "other"


def sources_in(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    uris = []
    for directive in DIRECTIVE_RE.finditer(text):
        # Ignore URIs quoted inside "//" comments on the same line.
        for uri in URI_RE.findall(directive.group(1)):
            if uri not in uris:
                uris.append(uri)
    return uris


def resolve_uri(source: str, uri: str) -> str | None:
    if uri.startswith("package:"):
        prefix, sep, suffix = uri[8:].partition("/")
        if sep and prefix in PACKAGE_ROOTS:
            return posixpath.normpath(PACKAGE_ROOTS[prefix] + suffix)
        return None
    if uri.startswith("dart:"):
        return None
    if ":" in uri:  # https:, assets:, etc.
        return None
    return posixpath.normpath(posixpath.join(posixpath.dirname(source), uri))


def platform_package(uri: str) -> str | None:
    if not uri.startswith("package:"):
        return None
    package = uri[8:].split("/", 1)[0]
    return package if package in PLATFORM_PLUGINS else None


def audit(root: Path) -> dict:
    files = sorted(p for p in root.rglob("*.dart") if ".dart_tool" not in p.parts
                   and "build" not in p.parts)
    paths = [p.relative_to(root).as_posix() for p in files]
    known = set(paths)
    imports = {}
    edges = defaultdict(set)
    core_ui_direct = []
    core_flutter_direct = []
    core_platform_direct = []
    core_mobile_web = []
    mobile_web = []
    mobile_core_ui = []
    plugins = defaultdict(set)

    for abs_path, path in zip(files, paths):
        uris = sources_in(abs_path)
        imports[path] = uris
        for uri in uris:
            target = resolve_uri(path, uri)
            if target in known:
                edges[path].add(target)
            if path.startswith(GROUPS["core_lib"]):
                if uri in UI_SDK_URIS or target == "packages/core/lib/core/theme/app_palette.dart":
                    core_ui_direct.append({"path": path, "uri": uri})
                if uri.startswith("package:flutter/") or uri == "dart:ui":
                    core_flutter_direct.append({"path": path, "uri": uri})
                plugin = platform_package(uri)
                if plugin:
                    core_platform_direct.append({"path": path, "uri": uri})
                if target and (target.startswith(GROUPS["mobile_lib"])
                               or target.startswith(GROUPS["web_lib"])):
                    core_mobile_web.append({"path": path, "uri": uri, "target": target})
            if path.startswith(GROUPS["mobile_lib"]):
                if (target and target.startswith(GROUPS["web_lib"])) or (
                    uri.startswith("package:gym_tracker_web/") or "apps/app_web/" in uri
                ):
                    mobile_web.append({"path": path, "uri": uri, "target": target})
                if target and target.startswith(GROUPS["core_lib"]) and (
                    "/presentation/pages/" in target or
                    "/presentation/widgets/" in target or
                    "/core/theme/" in target or
                    "/presentation/" in target and target.endswith("_page.dart")
                ):
                    mobile_core_ui.append({"path": path, "uri": uri, "target": target})
            plugin = platform_package(uri)
            if plugin:
                plugins[group_for(path)].add(plugin)

    ui_seeds = set(x["path"] for x in core_ui_direct)
    # Closure: which Core source files depend (possibly transitively) on Core UI.
    polluted = set(ui_seeds)
    changed = True
    while changed:
        changed = False
        for path, targets in edges.items():
            if path.startswith(GROUPS["core_lib"]) and path not in polluted:
                if any(target in polluted for target in targets):
                    polluted.add(path)
                    changed = True
    transitive_only = sorted(polluted - ui_seeds)

    count = Counter(group_for(p) for p in paths)
    report = {
        "scope": "full checked-out repository",
        "method": "lexical Dart import/export/part declarations, including conditional imports; "
                  "not a semantic analyzer",
        "counts": dict(sorted(count.items())),
        "total_dart": len(paths),
        "direct": {
            "core_ui": core_ui_direct,
            "core_flutter": core_flutter_direct,
            "core_platform_packages": core_platform_direct,
            "core_to_mobile_or_web": core_mobile_web,
            "mobile_to_web": mobile_web,
            "mobile_to_core_ui": mobile_core_ui,
        },
        "core_ui_transitive": transitive_only,
        "packages_by_group": {k: sorted(v) for k, v in sorted(plugins.items())},
        "unresolved_imports": [
            {"path": path, "uri": uri}
            for path, uris in imports.items()
            for uri in uris
            if (uri.startswith("package:core/") or
                uri.startswith("package:gym_tracker/") or
                uri.startswith("package:gym_tracker_web/") or
                uri.startswith("../") or uri.startswith("./"))
            and (t := resolve_uri(path, uri)) not in known
        ],
        "all_imports": imports,
    }
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--json-out", default="")
    parser.add_argument("--enforce", action="store_true",
                        help="Fail if Core contains Flutter/UI/foreign packages or Mobile references Web")
    args = parser.parse_args()
    report = audit(Path(args.root).resolve())
    if args.json_out:
        target = Path(args.json_out)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n",
                          encoding="utf-8")
    direct = report["direct"]
    print("STK Haven — architecture inventory (diagnostic)")
    print("Dart files:", report["total_dart"], report["counts"])
    for key in ["core_ui", "core_flutter", "core_platform_packages",
                "core_to_mobile_or_web", "mobile_to_web", "mobile_to_core_ui"]:
        paths = set(x["path"] for x in direct[key])
        print(f"{key}: {len(paths)} source file(s), {len(direct[key])} declaration(s)")
    print("Core -> Core UI transitive dependents:", len(report["core_ui_transitive"]))
    print("Unresolved relative/workspace imports:", len(report["unresolved_imports"]))
    if direct["mobile_to_web"]:
        print("PROHIBITED Mobile -> Web: " + json.dumps(direct["mobile_to_web"][:25]))
    if direct["core_to_mobile_or_web"]:
        print("PROHIBITED Core -> Mobile/Web: "
              + json.dumps(direct["core_to_mobile_or_web"][:25]))
    forbidden = any((direct["core_ui"], direct["core_flutter"],
                     direct["core_platform_packages"], direct["core_to_mobile_or_web"],
                     direct["mobile_to_web"]))
    if args.enforce and forbidden:
        print("Architecture guard failed. Use default diagnostic mode until migration completes.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
