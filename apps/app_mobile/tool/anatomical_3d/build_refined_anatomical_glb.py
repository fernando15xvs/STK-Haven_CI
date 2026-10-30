#!/usr/bin/env python3
"""STK Haven v3.2 internal prototype: anatomical junction surfaces for GLB.

Extends the stable 19-joint GLB generator, preserving its exported IK motions,
IDs, material roles and non-production flags.  Surfaces are hand-authored lofts,
not a high-fidelity sculpture, clinical anatomy, or biomechanical validation.
No network, downloaded assets, GIFs, external packages, or web integration.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import build_anatomical_glb as base

ORIGINAL_HUMANOID = base.humanoid
SIDES = ((-1, 'L'), (1, 'R'))


def _add(a, b):
    return tuple(a[k] + b[k] for k in range(3))


def _sub(a, b):
    return tuple(a[k] - b[k] for k in range(3))


def _mul(v, x):
    return tuple(value * x for value in v)


def _dot(a, b):
    return sum(a[k] * b[k] for k in range(3))


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _unit(v):
    length = math.sqrt(_dot(v, v))
    if length < 1e-8:
        raise ValueError('Degenerate anatomical junction axis')
    return _mul(v, 1.0 / length)


def _normalize_skin(anchors):
    cleaned = [(name, float(weight)) for name, weight in anchors
               if float(weight) > 1e-8]
    if not cleaned or len(cleaned) > 4:
        raise ValueError('Junction must use 1–4 bone weights')
    for name, weight in cleaned:
        if name not in base.INDEX or weight < 0:
            raise ValueError('Invalid junction skin anchor')
    total = sum(weight for _, weight in cleaned)
    return [(name, weight / total) for name, weight in cleaned]


def sweep(g, name, rings, role='body', segments=16):
    """Closed, smooth elliptical sweep with continuously blended joint weights.

    Each ring is (centerXYZ, rx, rz, skinWeights), with both axes perpendicular
    to the tangent, producing an oriented soft-volume sleeve rather than an
    independent egg-shaped primitive at each joint. Material role is stable.
    """
    if len(rings) < 3 or segments < 12:
        raise ValueError('Insufficient anatomical sweep resolution')
    positions, weights, faces = [], [], []
    for i, (center, radius_a, radius_b, anchors) in enumerate(rings):
        if min(radius_a, radius_b) < .008:
            raise ValueError('Junction radius too small')
        tangent = _unit(_sub(rings[min(i + 1, len(rings) - 1)][0],
                             rings[max(i - 1, 0)][0]))
        guide = (0., 0., 1.) if abs(tangent[2]) < .85 else (0., 1., 0.)
        side_a = _unit(_cross(tangent, guide))
        side_b = _cross(tangent, side_a)
        influence = _normalize_skin(anchors)
        for j in range(segments):
            theta = 2 * math.pi * j / segments
            contour = _add(_mul(side_a, radius_a * math.cos(theta)),
                           _mul(side_b, radius_b * math.sin(theta)))
            positions.append(_add(center, contour))
            weights.append(influence)
    for i in range(len(rings) - 1):
        for j in range(segments):
            a = i * segments + j
            b = i * segments + (j + 1) % segments
            c = (i + 1) * segments + j
            d = (i + 1) * segments + (j + 1) % segments
            faces.extend(((a, b, c), (b, d, c)))
    # Closures are deliberately inside existing body volumes.
    for end, reverse in ((0, True), (len(rings) - 1, False)):
        center_index = len(positions)
        positions.append(tuple(rings[end][0]))
        weights.append(_normalize_skin(rings[end][3]))
        for j in range(segments):
            a = end * segments + j
            b = end * segments + (j + 1) % segments
            faces.append((center_index, b, a) if reverse else
                         (center_index, a, b))
    g.add(name, positions, faces, role, weights=weights)


def refined_humanoid(exercise):
    """Add connected ring meshes bridging the disconnected v3 body volumes.

    This improves continuity *between neighbouring shapes* but does not make
    the entire body one watertight skin or guarantee anatomical accuracy.
    """
    g = ORIGINAL_HUMANOID(exercise)

    # Neck base: overlapping chest, trapezius, cervical volume and skull.
    sweep(g, 'cervico_thoracic_junction', [
        ((0., 1.585, 0.), .133, .103, [('chest', 1.)]),
        ((0., 1.635, 0.), .119, .097, [('chest', .78), ('neck', .22)]),
        ((0., 1.675, .002), .097, .086, [('chest', .32), ('neck', .68)]),
        ((0., 1.715, .004), .081, .077, [('neck', 1.)]),
        ((0., 1.765, .009), .073, .069, [('neck', .81), ('head', .19)]),
    ])
    for sign, side in SIDES:
        # Shoulder transition: clavicle/deltoid/upper-arm one tapered bridge.
        sweep(g, 'scapular_humeral_junction_' + side, [
            ((sign * .153, 1.563, -.014), .104, .103,
             [('chest', .76), ('clavicle_' + side, .24)]),
            ((sign * .222, 1.557, -.005), .140, .121,
             [('chest', .34), ('clavicle_' + side, .55),
              ('upper_arm_' + side, .11)]),
            ((sign * .302, 1.522, .007), .127, .118,
             [('clavicle_' + side, .37), ('upper_arm_' + side, .63)]),
            ((sign * .377, 1.447, .011), .096, .091,
             [('upper_arm_' + side, .88), ('clavicle_' + side, .12)]),
            ((sign * .422, 1.388, .014), .083, .081,
             [('upper_arm_' + side, 1.)]),
        ], 'body', segments=20)
        # Clavicular/trapezius rise visually bridges shoulder to the neck.
        sweep(g, 'superior_trapezius_' + side, [
            ((sign * .072, 1.635, -.049), .050, .048,
             [('neck', .68), ('chest', .32)]),
            ((sign * .137, 1.623, -.058), .069, .051,
             [('neck', .30), ('chest', .56), ('clavicle_' + side, .14)]),
            ((sign * .217, 1.578, -.042), .058, .048,
             [('chest', .28), ('clavicle_' + side, .72)]),
        ], 'muscle', segments=16)
        # Hip contour from iliac crest to upper leg, soft blend across pelvis.
        sweep(g, 'iliac_femoral_junction_' + side, [
            ((sign * .128, 1.090, -.012), .111, .113,
             [('pelvis', 1.)]),
            ((sign * .160, 1.027, -.018), .158, .135,
             [('pelvis', .77), ('thigh_' + side, .23)]),
            ((sign * .180, .964, -.011), .156, .136,
             [('pelvis', .48), ('thigh_' + side, .52)]),
            ((sign * .180, .893, .003), .135, .117,
             [('pelvis', .14), ('thigh_' + side, .86)]),
            ((sign * .180, .820, .009), .121, .101,
             [('thigh_' + side, 1.)]),
        ], 'body', segments=18)
        # Knee transition around patella, blended thigh/shin. Small mesh,
        # not a separately rotating sphere that detaches on flexion.
        sweep(g, 'femoral_tibial_junction_' + side, [
            ((sign * .180, .680, .023), .121, .111,
             [('thigh_' + side, 1.)]),
            ((sign * .180, .611, .032), .129, .119,
             [('thigh_' + side, .78), ('shin_' + side, .22)]),
            ((sign * .180, .548, .042), .108, .117,
             [('thigh_' + side, .47), ('shin_' + side, .53)]),
            ((sign * .180, .488, .041), .093, .095,
             [('thigh_' + side, .18), ('shin_' + side, .82)]),
            ((sign * .180, .436, .036), .089, .083,
             [('shin_' + side, 1.)]),
        ], 'body', segments=20)
        # Visible anatomical contour with adjacent role, no new rig joint.
        sweep(g, 'patellar_tendon_' + side, [
            ((sign * .180, .576, .141), .040, .022,
             [('thigh_' + side, .61), ('shin_' + side, .39)]),
            ((sign * .180, .536, .146), .047, .025,
             [('thigh_' + side, .35), ('shin_' + side, .65)]),
            ((sign * .180, .495, .134), .037, .020,
             [('shin_' + side, .9), ('thigh_' + side, .1)]),
        ], 'muscle', segments=12)
    return g


def build(output):
    original = base.humanoid
    try:
        base.humanoid = refined_humanoid
        result = base.build(output)
    finally:
        base.humanoid = original
    result['geometryStage'] = 'v3.2 junction-surface candidate, unapproved'
    result['junctionMeshesPerPilot'] = 1 + 2 * 5
    result['qualityGate'] = 'review seams, skinning and 16 appearances on mobile'
    Path(output, 'manifest.json').write_text(
        json.dumps(result, indent=2) + '\n', encoding='utf8')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    print(json.dumps(build(parser.parse_args().output), indent=2))
