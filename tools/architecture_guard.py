#!/usr/bin/env python3
"""Prevent new prohibited Core/Mobile dependency declarations.

Phase B incremental guard: legacy imports are frozen at a reviewed snapshot
and can only decrease. The final architecture gate additionally requires an
empty legacy allowlist after migrations. This program never changes app code.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import sys
import zlib

from architecture_inventory import audit

CATEGORIES = (
    "core_ui",
    "core_flutter",
    "core_platform_packages",
    "core_to_mobile_or_web",
    "mobile_to_web",
)

# These two Core source files depend transitively on Flutter UI through older
# providers. Their dependencies may be removed but no new transitive consumer
# may be introduced.
BASELINE_TRANSITIVE = frozenset({
    "packages/core/lib/features/sync/application/cloud_sync_provider.dart",
    "packages/core/lib/features/workout/application/active_workout_suggestions_provider.dart",
})


def fingerprint(path: str, uri: str) -> str:
    """Stable identifier per violating declaration (path + NUL + import URI)."""
    return hashlib.sha256((path + "\0" + uri).encode("utf-8")).hexdigest()[:16]


def load_baseline(file: Path) -> set[str]:
    source = file.read_text(encoding="utf-8")
    match = re.search(r"^\x60{3}base64\s*\n([A-Za-z0-9+/=\n]+)\n\x60{3}", source, re.M)
    if not match:
        raise ValueError(f"Missing base64 block in {file}")
    raw = zlib.decompress(base64.b64decode("".join(match.group(1).split()), validate=True))
    result = raw.decode("ascii").splitlines()
    if len(result) != 303 or len(result) != len(set(result)):
        raise ValueError("Legacy baseline must contain exactly 303 distinct original declarations")
    if any(re.fullmatch(r"[0-9a-f]{16}", digest) is None for digest in result):
        raise ValueError("Invalid legacy SHA-256 digest")
    return set(result)


def violations(report: dict) -> set[tuple[str, str]]:
    return {
        (entry["path"], entry["uri"])
        for key in CATEGORIES
        for entry in report["direct"][key]
    }


def assess(report: dict, frozen: set[str]) -> dict:
    current = violations(report)
    regressions = sorted(
        ({"path": path, "uri": uri} for path, uri in current
         if fingerprint(path, uri) not in frozen),
        key=lambda x: (x["path"], x["uri"]),
    )
    still_frozen = {fingerprint(path, uri) for path, uri in current} & frozen
    extra_transitive = sorted(set(report["core_ui_transitive"]) - BASELINE_TRANSITIVE)
    return {
        "status": "fail" if regressions or extra_transitive else "pass",
        "baseline_legacy_declarations": len(frozen),
        "remaining_legacy_declarations": len(still_frozen),
        "removed_legacy_declarations": len(frozen - still_frozen),
        "new_prohibited_declarations": regressions,
        "new_transitive_core_ui_paths": extra_transitive,
        "core_to_mobile_or_web_direct_count": len(report["direct"]["core_to_mobile_or_web"]),
        "mobile_to_web_direct_count": len(report["direct"]["mobile_to_web"]),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--baseline",
        default="docs/architecture/STK_CORE_LEGACY_IMPORT_BASELINE_20261123.md",
    )
    parser.add_argument("--json-out", default="")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    report = audit(root)
    baseline = load_baseline(root / args.baseline)
    result = assess(report, baseline)
    if args.json_out:
        target = Path(args.json_out)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n",
                          encoding="utf-8")
    print("STK Haven architecture no-new-dependencies gate")
    for key, value in result.items():
        if isinstance(value, list):
            print(f"{key}: {len(value)}")
            for item in value[:30]:
                print("  ", item)
        else:
            print(f"{key}: {value}")
    if result["status"] == "fail":
        print(
            "Regression blocked. Do not extend the legacy baseline; migrate or"
            " remove prohibited imports instead.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
