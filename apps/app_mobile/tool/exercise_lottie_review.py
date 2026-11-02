#!/usr/bin/env python3
"""Offline, mobile-only draft Lottie audit and approximate SVG review sheets.

No unreviewed exercise media is registered into Flutter. SVG files here are
review artifacts, not images shipped by either mobile or web applications.
These previews approximate path morphs linearly and DO NOT prove biomechanics
or exactly match the iOS/Android Lottie renderer.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET

FRAMES = (0, 15, 30, 45, 60)
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)
EXPECTED_BATCHES = (40, 60, 70, 59)
REVIEW_KEYS = ("biomechanics", "licenseDocumentation", "renderingIos",
               "renderingAndroid", "accessibility")
STATIC_HINTS = ("hold", "plank", "dead_hang", "pinch", "copenhagen")
RISK_TERMS = ("unilateral", "one_arm", "single", "machine", "cable", "rotat",
              "woodchop", "overhead", "sissy", "nordic", "rollout")


def load_json(path: Path):
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def frame_value(prop: dict, frame: float):
    if prop.get("a") != 1:
        return prop["k"]
    keys = prop["k"]
    if frame <= keys[0]["t"]:
        return keys[0]["s"]
    for index in range(len(keys) - 1):
        before, after = keys[index], keys[index + 1]
        if before["t"] <= frame <= after["t"]:
            span = after["t"] - before["t"]
            mix = (frame - before["t"]) / span if span else 0.0
            start = before["s"]
            end = before.get("e", after["s"])
            if isinstance(start, list) and start and isinstance(start[0], dict):
                s_path, e_path = start[0], end[0]
                if len(s_path["v"]) != len(e_path["v"]):
                    raise ValueError("Path vertex count changes during morph")
                return {"v": [
                    [s[0] + (e[0] - s[0]) * mix,
                     s[1] + (e[1] - s[1]) * mix]
                    for s, e in zip(s_path["v"], e_path["v"])
                ], "c": bool(s_path.get("c", False))}
            if isinstance(start, list) and start and isinstance(start[0], (float, int)):
                return [s + (e - s) * mix for s, e in zip(start, end)]
            return start
    return keys[-1]["s"]


def shape_points(shape: dict, frame: int):
    value = frame_value(shape["ks"], frame)
    if isinstance(value, list) and value and isinstance(value[0], dict):
        return value[0]["v"], bool(value[0].get("c", False))
    return value["v"], bool(value.get("c", False))


def color_rgba(item: dict, default: str) -> tuple[str, float]:
    if not item or item.get("c", {}).get("a") != 0:
        return default, 1.0
    channels = item["c"]["k"]
    if len(channels) != 4:
        return default, 1.0
    return "#" + "".join(f"{round(255 * max(0, min(1, c))):02x}"
                       for c in channels[:3]), float(channels[3])


def svg_label(parent, x, y, text, size=13, fill="#25384a"):
    ET.SubElement(parent, f"{{{SVG_NS}}}text", {
        "x": str(x), "y": str(y), "fill": fill, "font-size": str(size),
        "font-family": "sans-serif"
    }).text = str(text)


def storyboard(doc: dict, item: dict, destination: Path):
    width = 5 * 520 + 24
    root = ET.Element(f"{{{SVG_NS}}}svg", {
        "width": str(width), "height": "605",
        "viewBox": f"0 0 {width} 605",
    })
    ET.SubElement(root, f"{{{SVG_NS}}}rect", {
        "width": str(width), "height": "605", "fill": "#ffffff"
    })
    svg_label(root, 15, 27, item["id"] + " — " + item["name"], 18)
    svg_label(root, 15, 51,
              "BORRADOR SIN APROBAR · trayectoria interpolada aproximada; validar en Flutter y con experto",
              13, "#9b3c32")
    for index, frame in enumerate(FRAMES):
        offset = 12 + index * 520
        svg_label(root, offset + 8, 78, f"Fotograma {frame}/90", 14)
        ET.SubElement(root, f"{{{SVG_NS}}}rect", {
            "x": str(offset), "y": "92", "width": "512", "height": "512",
            "fill": "#f8fafc", "stroke": "#d9e1e9"
        })
        panel = ET.SubElement(root, f"{{{SVG_NS}}}g", {
            "transform": f"translate({offset},92)"
        })
        # Lottie and SVG may layer shapes differently; this is a QA sketch,
        # not a pixel-accurate rasterization of the Flutter implementation.
        for layer in doc["layers"]:
            position = frame_value(layer.get("ks", {}).get("p",
                                      {"a": 0, "k": [0, 0]}), frame)
            if isinstance(position, list) and len(position) >= 2:
                group = ET.SubElement(panel, f"{{{SVG_NS}}}g", {
                    "transform": f"translate({position[0]},{position[1]})"
                })
            else:
                group = panel
            for outer in layer.get("shapes", []):
                content = outer.get("it", []) if outer.get("ty") == "gr" else [outer]
                stroke = next((s for s in content if s.get("ty") == "st"), None)
                fill_item = next((s for s in content if s.get("ty") == "fl"), None)
                stroke_color, alpha = color_rgba(stroke, "#213f58")
                fill_color, fill_alpha = color_rgba(fill_item, "none")
                stroke_width = 1
                if stroke and stroke.get("w", {}).get("a") == 0:
                    stroke_width = stroke["w"]["k"]
                for sub in content:
                    if sub.get("ty") == "sh":
                        points, closed = shape_points(sub, frame)
                        tag = "polygon" if closed else "polyline"
                        ET.SubElement(group, f"{{{SVG_NS}}}{tag}", {
                            "points": " ".join(f"{p[0]:.2f},{p[1]:.2f}" for p in points),
                            "fill": fill_color if fill_item else "none",
                            "fill-opacity": str(fill_alpha),
                            "stroke": stroke_color if stroke else "none",
                            "stroke-opacity": str(alpha),
                            "stroke-width": str(stroke_width),
                            "stroke-linecap": "round",
                            "stroke-linejoin": "round",
                        })
                    elif sub.get("ty") == "el":
                        center = frame_value(sub["p"], frame)
                        diameter = frame_value(sub["s"], frame)
                        ET.SubElement(group, f"{{{SVG_NS}}}ellipse", {
                            "cx": str(center[0]), "cy": str(center[1]),
                            "rx": str(diameter[0] / 2), "ry": str(diameter[1] / 2),
                            "fill": fill_color if fill_item else "none",
                            "fill-opacity": str(fill_alpha),
                            "stroke": stroke_color if stroke else "none",
                            "stroke-width": str(stroke_width),
                        })
    ET.ElementTree(root).write(destination, encoding="utf-8", xml_declaration=True)


def geometry_report(doc: dict):
    warnings = []
    moving = 0
    generic = 0
    total = len(doc.get("layers", []))
    for layer in doc.get("layers", []):
        name = str(layer.get("nm", ""))
        if re.match(r"^(Rig|Base|Estructura)\s+\d+$", name):
            generic += 1
        for outer in layer.get("shapes", []):
            children = outer.get("it", []) if outer.get("ty") == "gr" else [outer]
            for shape in children:
                if shape.get("ty") != "sh":
                    continue
                ks = shape["ks"]
                if ks.get("a") == 1:
                    moving += 1
                try:
                    positions, _ = shape_points(shape, 0)
                    for frame in (0, 30, 60):
                        points, _ = shape_points(shape, frame)
                        if len(points) != len(positions):
                            warnings.append(f"{name}: topology changes")
                        if any(not all(math.isfinite(c) for c in p) for p in points):
                            warnings.append(f"{name}: nonfinite vertex")
                        if any(c < 0 or c > 512 for p in points for c in p):
                            warnings.append(f"{name}: vertex outside canvas")
                except (ValueError, TypeError, KeyError, IndexError) as error:
                    warnings.append(f"{name}: invalid path ({error})")
    if generic:
        warnings.append(f"{generic} base layers need anatomical editorial labels")
    if moving < 3:
        warnings.append("fewer than three moving vector paths")
    if total < 11:
        warnings.append("very few vector layers")
    return moving, total, sorted(set(warnings))


def run(root: Path, output: Path) -> None:
    manifest = load_json(root / "tool/exercise_lottie_batches.json")
    batches = manifest["batches"]
    if len(batches) != 4:
        raise ValueError("Expected four mobile batches")
    ids = set()
    rows = []
    output.mkdir(parents=True, exist_ok=True)
    gallery = output / "storyboards"
    gallery.mkdir(exist_ok=True)
    all_warnings = Counter()
    for index, batch in enumerate(batches):
        if len(batch["items"]) != EXPECTED_BATCHES[index]:
            raise ValueError(f"Batch {index + 1} has the wrong size")
        for item in batch["items"]:
            ex_id = item["id"]
            if ex_id in ids or not re.fullmatch(r"ex(?:v2)?_[a-z0-9_]+", ex_id):
                raise ValueError(f"Duplicate/invalid exercise ID: {ex_id}")
            ids.add(ex_id)
            if item["status"] != "draft" or item["approved"] is not False:
                raise ValueError(f"Unexpectedly released exercise: {ex_id}")
            if any(item.get("review", {}).get(key) is not False for key in REVIEW_KEYS):
                raise ValueError(f"False QA attestation for unapproved draft: {ex_id}")
            path = root / item["assetPath"]
            if not path.is_file() or path.stat().st_size >= 120_000:
                raise ValueError(f"Missing or oversized exercise media: {ex_id}")
            doc = load_json(path)
            if doc.get("assets") != [] or doc.get("w") != 512 or doc.get("h") != 512:
                raise ValueError(f"Non-vector or wrong canvas: {ex_id}")
            if doc.get("fr") != 30 or doc.get("ip") != 0 or doc.get("op") != 90:
                raise ValueError(f"Unexpected Lottie timing: {ex_id}")
            if f" / {ex_id} / {item['view']} / " not in doc.get("nm", ""):
                raise ValueError(f"Wrong exercise media mapping: {ex_id}")
            moving, layer_count, warnings = geometry_report(doc)
            if any("nonfinite" in w or "invalid path" in w or "topology changes" in w
                   for w in warnings):
                raise ValueError(f"Invalid geometry for {ex_id}: {warnings}")
            for warning in warnings:
                all_warnings[warning.split(":")[0]] += 1
            storyboard(doc, item, gallery / f"{ex_id}.svg")
            flags = [term for term in RISK_TERMS if term in ex_id]
            if any(term in ex_id for term in STATIC_HINTS):
                flags.append("isometric")
            rows.append({
                "id": ex_id, "name": item["name"], "lot": index + 1,
                "family": item["family"], "view": item["view"],
                "layers": layer_count, "animated_elements": moving,
                "review_priority": "high" if flags or warnings else "standard",
                "flags": "; ".join(flags),
                "automated_warnings": " | ".join(warnings),
                "visual_review": "pending", "biomechanics": "pending",
                "license_documentation": "pending", "ios_device": "pending",
                "android_device": "pending", "accessibility": "pending",
                "approval": "blocked",
            })
    if len(ids) != 229:
        raise ValueError(f"Expected 229 unique presets, got {len(ids)}")
    with (output / "review_matrix.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    report = {
        "scope": "Flutter mobile iOS and Android only; NOT bundled",
        "coverage": len(ids), "approved": 0, "lot_sizes": list(EXPECTED_BATCHES),
        "storyboards": len(rows), "visual_review_completed": 0,
        "physical_ios_tests_completed": 0, "physical_android_tests_completed": 0,
        "expert_biomechanics_reviews_completed": 0,
        "geometry_warning_exercises": sum(bool(r["automated_warnings"]) for r in rows),
        "priority_high": sum(r["review_priority"] == "high" for r in rows),
        "limits": [
            "SVG panels are approximate, not pixel-accurate Lottie frames",
            "Automated format tests are not biomechanical or physical-device validation",
            "No media can be published before explicit review and approval",
        ],
    }
    (output / "summary.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path("build/lottie_review"))
    args = parser.parse_args()
    try:
        run(args.root.resolve(), args.output.resolve())
    except (ValueError, KeyError, TypeError, OSError) as exc:
        print(f"Exercise Lottie QA failed: {exc}", file=sys.stderr)
        sys.exit(1)
