#!/usr/bin/env python3
"""Validate the public checkout against the canonical product-tree manifest.

The public runner has no access to the private repository. The publisher must
first compare the two authenticated Git trees and derive this manifest from
private main. All code, binaries, tests, SQL and lockfiles are covered by the
recursive Git tree IDs; only private docs and CI-owned paths are excluded.
"""
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
EXCLUDED = frozenset({"docs", "ci", ".github", "PUBLIC_CI_SNAPSHOT.md"})


def tree_entries(recursive=False):
    args = ["git", "ls-tree", "-z"]
    if recursive:
        args.append("-r")
    raw = subprocess.check_output([*args, "HEAD"], cwd=ROOT)
    result = {}
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        metadata, path = entry.split(b"\t", 1)
        mode, kind, sha = metadata.decode("ascii").split()
        result[path.decode("utf-8")] = {"mode": mode, "type": kind, "sha": sha}
    return result


def main():
    manifest = json.loads(
        (ROOT / "ci/public/product_snapshot.json").read_text(encoding="utf-8")
    )
    if (
        manifest.get("schema") != 1
        or manifest.get("source_repository") != "fernando15xvs/STK-Haven"
        or not re.fullmatch(r"[0-9a-f]{40}", manifest.get("source_commit", ""))
    ):
        raise SystemExit("Invalid canonical snapshot provenance")
    expected = manifest["product_roots"]
    actual = {p: v for p, v in tree_entries().items() if p not in EXCLUDED}
    mismatches = sorted(
        p for p in set(expected) | set(actual)
        if expected.get(p) != actual.get(p)
    )
    product_count = sum(
        1 for path, entry in tree_entries(recursive=True).items()
        if path.split("/", 1)[0] not in EXCLUDED and entry["type"] == "blob"
    )
    if mismatches:
        print("Product tree differs from approved private snapshot:", file=sys.stderr)
        for path in mismatches:
            print(f"  {path}: expected {expected.get(path)}, got {actual.get(path)}",
                  file=sys.stderr)
    if product_count != manifest["product_file_count"]:
        print("Product file count mismatch:", product_count, file=sys.stderr)
        return 1
    if mismatches:
        return 1
    if (ROOT / ".github/workflows/flutter_ci.yml").read_bytes() != (
        ROOT / "ci/public/flutter_ci.yml"
    ).read_bytes():
        print("CI workflow and its template differ", file=sys.stderr)
        return 1
    print(f"Product parity manifest verified: {product_count} files; "
          f"canonical {manifest['source_commit']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
