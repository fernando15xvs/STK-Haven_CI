#!/usr/bin/env python3
"""STK Haven v9.21 — sampled RENDERED fingertip triangles vs rigid bar.

QA ONLY. Samples actual *skinned, morphed triangle interiors* (not just
vertices or distal joint positions) for each of the 3 disabled exercise GLBs
over 121 poses at 30 Hz. Captures potential triangle/cylinder clipping and
surface gaps. This is NOT continuous triangle/cylinder collision detection,
not pressure/friction, not a solved finger IK grip and not an expert approval.

The triangle surface is the linear interpolation of its fully transformed
vertices, matching the glTF rasterized surface (not interpolated bone weights).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import EXERCISES, qconj, qrot
from exercise_surface_collision_v911 import (
    _samplers, _sample, _skin_vertex, capped_cylinder_sdf,
)
from review_fingertip_mesh_v919 import (
    _verified_mesh, FPS, FRAMES, SHAFT_RADIUS, SHAFT_MIN_X, SHAFT_MAX_X,
    MAX_ALLOWED_CONTACT_GAP,
)
from sculpt_finger_pads_v920 import _faces
from animate_hand_grip_v917 import DIGITS, SIDES

MAX_PER_FINGER_TRIANGLES = 900
DEEP_PENETRATION_METERS = -.002
SAMPLES_PER_TRIANGLE = 7
BARYCENTRIC = (
    (1., 0., 0.), (0., 1., 0.), (0., 0., 1.),
    (.5, .5, 0.), (.5, 0., .5), (0., .5, .5),
    (1./3., 1./3., 1./3.),
)


def _point(a, b, c, bary):
    return tuple(a[i]*bary[0] + b[i]*bary[1] + c[i]*bary[2]
                 for i in range(3))


def triangle_probe(a, b, c):
    """QA signed distances for 7 exact points on a rendered, linear triangle.

    Inputs are BAR-LOCAL coordinates in metres. This detects more surface
    crossings than vertex-only audits, but may miss small unsampled contacts.
    """
    if not all(math.isfinite(x) for p in (a, b, c) for x in p):
        raise ValueError('Nonfinite triangle')
    signed = [
        capped_cylinder_sdf(_point(a, b, c, bary),
                            SHAFT_MIN_X, SHAFT_MAX_X, SHAFT_RADIUS)
        for bary in BARYCENTRIC
    ]
    if not all(math.isfinite(x) for x in signed):
        raise ValueError('Nonfinite collision distance')
    return min(signed)


def _select_faces(glb, groups, points):
    faces, _ = _faces(glb, len(points))
    # A triangle is a finger candidate if it contains a weighted surface
    # vertex from the v9.19 distal-phalanx region. Do not invent a fingertip
    # marker, and do not truncate a region silently when it grows too large.
    buckets = {}
    for side in SIDES:
        for digit in DIGITS:
            name = f'{digit}_{side}'
            selected = set(groups[(side, digit)])
            matched = [
                (a, b, c) for a, b, c in faces
                if a in selected or b in selected or c in selected
            ]
            if not 1 <= len(matched) <= MAX_PER_FINGER_TRIANGLES:
                raise ValueError('Missing or unbounded actual finger faces: '+name)
            buckets[name] = matched
    return buckets


def audit(raw, exercise, *, candidate):
    """Audit an original v9.18 model or a v9.20 sculpt, never production."""
    (glb, positions, joints, weights, deltas, ibm, skin, groups
     ) = _verified_mesh(raw, exercise, True)
    extra = glb.doc['extras']
    version = extra.get('fingerPadReviewVersion')
    if candidate:
        if version != 920 or extra.get('surfaceCandidateOnly') is not True:
            raise ValueError('Expected v9.20 disabled hand-pad source')
    elif version is not None:
        raise ValueError('Expected unchanged v9.18 hand-pad baseline')
    if extra.get('approved') is not False or extra.get('enabled') is not False:
        raise ValueError('Only unapproved assets may be reviewed')
    buckets = _select_faces(glb, groups, positions)
    vertices = sorted({
        vertex for faces in buckets.values()
        for triangle in faces for vertex in triangle
    })
    if not 60 <= len(vertices) <= len(positions):
        raise ValueError('Implausible fingertip triangle vertex count')
    channels = {
        i: (positions[i], [d[i] for d in deltas], weights[i], joints[i])
        for i in vertices
    }
    animation = _samplers(glb)
    bar_node = glb.by_name['STK_EXERCISE_BAR']
    stats = {
        name: dict(frameCount=0, trianglesPerFrame=len(faces),
                   surfacePointSamples=0, framesWithin10mm=0,
                   framesPossiblePenetrationOver2mm=0,
                   meanPositiveGapSum=0., worstPositiveGap=0.,
                   minSignedDistance=float('inf'))
        for name, faces in buckets.items()
    }
    # Each pose uses precisely the glTF animation/IK plus 8 morph weights.
    for frame in range(FRAMES):
        world, rotation, morph = _sample(glb, animation, frame/FPS)
        bar = world[bar_node]
        inverse = qconj(rotation[bar_node])
        if len(bar) != 3 or len(inverse) != 4:
            raise ValueError('Malformed animated bar frame')
        local = {}
        for i, (position, delta, weight, joint) in channels.items():
            p = _skin_vertex(position, delta, weight, joint, ibm,
                             world, rotation, skin, morph)
            local[i] = qrot(inverse, (p[0]-bar[0], p[1]-bar[1],
                                       p[2]-bar[2]))
        for name, faces in buckets.items():
            nearest = min(
                triangle_probe(local[a], local[b], local[c])
                for a, b, c in faces
            )
            stat = stats[name]
            stat['frameCount'] += 1
            stat['surfacePointSamples'] += len(faces)*SAMPLES_PER_TRIANGLE
            stat['meanPositiveGapSum'] += max(0., nearest)
            stat['worstPositiveGap'] = max(
                stat['worstPositiveGap'], max(0., nearest))
            stat['minSignedDistance'] = min(
                stat['minSignedDistance'], nearest)
            if nearest <= MAX_ALLOWED_CONTACT_GAP:
                stat['framesWithin10mm'] += 1
            if nearest < DEEP_PENETRATION_METERS:
                stat['framesPossiblePenetrationOver2mm'] += 1

    details = {}
    for name, stat in stats.items():
        if (stat['frameCount'] != FRAMES or
            stat['surfacePointSamples'] !=
                FRAMES * stat['trianglesPerFrame'] * SAMPLES_PER_TRIANGLE):
            raise ValueError('Incomplete triangle surface sampling')
        details[name] = {
            'trianglesPerFrame': stat['trianglesPerFrame'],
            'frames': stat['frameCount'],
            'barycentricSamplesPerTriangle': SAMPLES_PER_TRIANGLE,
            'totalSurfaceSamples': stat['surfacePointSamples'],
            'meanNearestPositiveGapMeters': round(
                stat['meanPositiveGapSum']/FRAMES, 7),
            'worstNearestPositiveGapMeters': round(
                stat['worstPositiveGap'], 7),
            'minimumSignedSurfaceGapMeters': round(
                stat['minSignedDistance'], 7),
            'framesWithin10mmOfShaft': stat['framesWithin10mm'],
            'framesPossibleTrianglePenetrationOver2mm': stat[
                'framesPossiblePenetrationOver2mm'],
            'expertReviewPending': True,
        }
    return {
        'exerciseId': exercise, 'candidateV920': candidate,
        'framesPerExercise': FRAMES,
        'uniqueSkinnedVerticesPerFrame': len(vertices),
        'fingerRegions': 10, 'triangleInteriorSamples': True,
        'surfaceMetrics': details,
        'sourceSha256': hashlib.sha256(raw).hexdigest(),
        'continuousCollisionCertified': False,
        'exactTriangleCylinderIntersectionCertified': False,
        'anatomicalGripApproved': False,
        'physicalDeviceVerified': False,
        'approved': False, 'enabled': False,
    }


def build(root, output_dir):
    """Create read-only comparison; outputs JSON only, no production GLB."""
    base = Path(root)
    before_dir = base/'contact_v918'
    after_dir = before_dir/'skin_v919'/'hand_v920'
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    comparisons = []
    for exercise in EXERCISES:
        prior = (before_dir / f'{exercise}_v918_contact_mobile_qa.glb'
                ).read_bytes()
        sculpted = (after_dir / f'{exercise}_v920_hand_surface_mobile_qa.glb'
                   ).read_bytes()
        a = audit(prior, exercise, candidate=False)
        b = audit(sculpted, exercise, candidate=True)
        changes = {}
        for name, old in a['surfaceMetrics'].items():
            current = b['surfaceMetrics'][name]
            if old['trianglesPerFrame'] != current['trianglesPerFrame']:
                raise ValueError('Triangle topology changed during hand relief')
            changes[name] = {
                'baselineMeanPositiveGapMeters': old[
                    'meanNearestPositiveGapMeters'],
                'candidateMeanPositiveGapMeters': current[
                    'meanNearestPositiveGapMeters'],
                'meanGapDeltaMeters': round(
                    current['meanNearestPositiveGapMeters']-
                    old['meanNearestPositiveGapMeters'], 7),
                'candidateFramesPossibleDeepPenetration': current[
                    'framesPossibleTrianglePenetrationOver2mm'],
                'requiresFingerRetopologyAndContactSolverReview': True,
            }
        comparisons.append({
            'exerciseId': exercise, 'v918': a, 'v920': b,
            'perFingerComparison': changes,
            'fingertipCollisionResolved': False,
        })
    report = {
        'schema': 'stk_v921_skinned_triangle_bar_proximity_qa',
        'catalogCount': 229, 'pilotCount': 3, 'rigJoints': 55,
        'morphTargets': 8, 'frames': FRAMES, 'fps': FPS,
        'pointSamplesPerTriangle': SAMPLES_PER_TRIANGLE,
        'barCylinderRadiusMeters': SHAFT_RADIUS,
        'barFrameIncludesAnimatedQuaternion': True,
        'approved': False, 'enabled': False,
        'retopologyComplete': False,
        'contactIKComplete': False,
        'continuousCollisionCertified': False,
        'expertReviewed': False,
        'physicalDeviceVerified': False,
        'limitations': [
            'Seven barycentric samples on each selected skinned triangle',
            'Small collisions between samples and between frames can be missed',
            'The bar is an idealized 19mm shaft, without collars, hands-on pressure, or friction',
            'Surface vertex skin weights identify approximate distal zones only',
            'This audits an existing mesh; it does not sculpt or solve an anatomical grip',
        ],
        'pilots': comparisons,
    }
    (output/'finger_triangle_bar_v921_report.json').write_text(
        json.dumps(report, indent=2)+'\n', encoding='utf8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = build(args.input, args.output)
    print(json.dumps({'schema':report['schema'], 'pilotCount':3,
                      'continuousCollisionCertified':False,
                      'approved':False, 'enabled':False}, indent=2))
