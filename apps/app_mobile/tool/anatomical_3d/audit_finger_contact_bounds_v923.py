#!/usr/bin/env python3
"""STK Haven v9.23: bounded triangle-to-bar contact QA on REAL v9.22 skin.

At nine discrete glTF poses the 1-Lipschitz signed distance to the animated
finite cylindrical shaft gives a conservative lower bound over each rendered
triangle. Adaptive subdivision distinguishes a sampled penetration, a
provably separated triangle at that pose, and an unresolved near-contact.
This produces evidence, not finger IK, expert biomechanics, anatomical
sculpting or continuous-time collision certification.

Unapproved three-pilot lab only. NO GLB mutation, app registration, or web.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, EXERCISES, SOURCE_SHA, qconj, qrot
from animate_hand_grip_v917 import DIGITS, SIDES
from exercise_surface_collision_v911 import (
    _samplers, _sample, _skin_vertex, capped_cylinder_sdf,
)
from review_fingertip_mesh_v919 import (
    SHAFT_MIN_X, SHAFT_MAX_X, SHAFT_RADIUS,
)
from refine_fingertip_topology_v922 import MAX_MOBILE_BYTES

SAMPLED_FRAMES = tuple(range(0, 121, 15))  # Nine snapshots, 0.5 s apart.
FPS = 30
DEPTH = 2
MIN_DISTAL_WEIGHT = .20
MAX_FINGER_FACES = 2500
MAX_TOTAL_FACES = 20000
EPS = .00001  # Numerical guard, not a permissible skin penetration.


def _distance(p):
    return capped_cylinder_sdf(p, SHAFT_MIN_X, SHAFT_MAX_X, SHAFT_RADIUS)


def bounded_triangle(a, b, c, *, depth=DEPTH):
    """Return conservative per-pose lower and sampled upper SDF bounds.

    The finite-cylinder signed distance is 1-Lipschitz. Every point in a
    triangle lies within max(distance(centroid, vertex)) of the centroid.
    Therefore f(centroid)-radius is a rigorous LOWER bound over the whole
    planar triangle. A sampled value is an UPPER bound for its minimum.
    Subdivision tightens only ambiguous cases; uncertainty is NEVER called
    collision-free. The bounds do not apply between animation frames.
    """
    if depth < 0 or depth > 5:
        raise ValueError('Invalid adaptive contact depth')
    if not all(math.isfinite(v) for p in (a, b, c) for v in p):
        raise ValueError('Nonfinite skinned triangle')

    def half(x, y):
        return tuple((u+v)*.5 for u, v in zip(x, y))

    def walk(pa, pb, pc, level):
        centre = tuple((pa[k]+pb[k]+pc[k])/3 for k in range(3))
        extent = max(math.dist(centre, vertex) for vertex in (pa, pb, pc))
        centre_sdf = _distance(centre)
        upper = min(centre_sdf, _distance(pa), _distance(pb), _distance(pc))
        lower = centre_sdf - extent
        if upper < -EPS or lower > EPS or level == 0:
            return lower, upper, 4
        ab, bc, ca = half(pa, pb), half(pb, pc), half(pc, pa)
        children = (
            (pa, ab, ca), (ab, pb, bc),
            (ca, bc, pc), (ab, bc, ca),
        )
        scans = [walk(*triangle, level-1) for triangle in children]
        return (min(r[0] for r in scans),
                min(r[1] for r in scans),
                4 + sum(r[2] for r in scans))

    lower, upper, samples = walk(a, b, c, depth)
    if lower > upper + 1e-8:
        raise ValueError('Broken conservative signed-distance bounds')
    label = ('sampled_penetration' if upper < -EPS else
             'separated_at_sampled_pose' if lower > EPS else
             'unresolved_near_contact')
    return dict(lower=lower, upper=upper, samples=samples, classification=label)


def _read_refined(raw, exercise):
    if exercise not in EXERCISES or len(raw) > MAX_MOBILE_BYTES:
        raise ValueError('Unknown exercise or GLB above QA byte budget')
    glb = GLB(raw, expected_sha=None)
    d = glb.doc
    meta = d.get('extras', {})
    if (meta.get('exerciseId') != exercise or
            meta.get('sourceSha256') != SOURCE_SHA or
            meta.get('masterExercisePilotVersion') != 910 or
            meta.get('fingerLocalRetopologyVersion') != 922 or
            meta.get('localRetopologyCandidate') is not True or
            meta.get('approved') is not False or
            meta.get('enabled') is not False or
            meta.get('fingerContactIKComplete') is not False or
            len(d.get('skins', [])) != 1 or
            len(d['skins'][0]['joints']) != 55 or
            len(d.get('animations', [])) != 1 or
            len(d['meshes'][0]['primitives']) != 12 or
            'STK_EXERCISE_BAR' not in glb.by_name):
        raise ValueError('Expected quarantined v9.22 master55 GLB')
    parts = d['meshes'][0]['primitives']
    attrs = parts[0]['attributes']
    targets = parts[0]['targets']
    if len(targets) != 8 or any(
            p['attributes'] != attrs or p['targets'] != targets
            for p in parts):
        raise ValueError('Lost shared 8-morph atlas skin')
    points = glb.accessor(attrs['POSITION'])
    joints = glb.accessor(attrs['JOINTS_0'])
    weights = glb.accessor(attrs['WEIGHTS_0'])
    morphs = [glb.accessor(t['POSITION']) for t in targets]
    if not 4727 < len(points) < 8000 or any(
            len(x) != len(points) for x in (joints, weights, *morphs)):
        raise ValueError('Unexpected v9.22 refined skin geometry')
    skin = d['skins'][0]['joints']
    ibm = glb.accessor(d['skins'][0]['inverseBindMatrices'])
    if len(ibm) != 55:
        raise ValueError('Missing inverse bind matrices')
    if any(not .998 < sum(w) < 1.002 for w in weights):
        raise ValueError('Unnormalized skinned vertex')
    triangles = []
    for part in parts:
        ids = [int(x[0]) for x in glb.accessor(part['indices'])]
        if len(ids) % 3 or any(i < 0 or i >= len(points) for i in ids):
            raise ValueError('Invalid refined triangle indices')
        triangles.extend(tuple(ids[k:k+3]) for k in range(0, len(ids), 3))
    if not 9843 < len(triangles) <= MAX_TOTAL_FACES:
        raise ValueError('No bounded v9.22 triangle subdivision')

    groups = {}
    for side in SIDES:
        for digit in DIGITS:
            key = f'{digit}_{side}'
            node = glb.by_name.get(f'{digit}_03_{side}')
            if node is None or node not in skin:
                raise ValueError('Missing real distal digit '+key)
            palette = skin.index(node)
            vertices = {
                i for i, (jj, ww) in enumerate(zip(joints, weights))
                if sum(float(v) for j, v in zip(jj, ww)
                       if int(j) == palette) >= MIN_DISTAL_WEIGHT
            }
            selected = [face for face in triangles if any(
                v in vertices for v in face)]
            if not 6 <= len(vertices) or not 1 <= len(selected) <= MAX_FINGER_FACES:
                raise ValueError('Unbounded fingertip geometry '+key)
            groups[key] = selected
    if len(groups) != 10:
        raise ValueError('Expected both hands and ten distal regions')
    return glb, points, joints, weights, morphs, ibm, skin, groups


def audit(raw, exercise):
    glb, points, joints, weights, morphs, ibm, skin, groups = (
        _read_refined(raw, exercise))
    touched = sorted({
        i for faces in groups.values() for face in faces for i in face
    })
    channels = {
        i: (points[i], [shape[i] for shape in morphs],
            weights[i], joints[i])
        for i in touched
    }
    animation = _samplers(glb)
    bar_node = glb.by_name['STK_EXERCISE_BAR']
    per_finger = {key: dict(trianglesPerFrame=len(faces),
                            sampledPenetrationFrames=0,
                            separatedFrames=0, unresolvedFrames=0,
                            evaluatedTriangles=0, sdfEvaluations=0,
                            minimumSampledSignedDistanceMeters=float('inf'))
                  for key, faces in groups.items()}
    for frame in SAMPLED_FRAMES:
        world, rotations, activation = _sample(
            glb, animation, frame / FPS)
        bar, inv = world[bar_node], qconj(rotations[bar_node])
        local = {}
        for i, (position, deltas, w, j) in channels.items():
            skinned = _skin_vertex(position, deltas, w, j, ibm,
                                   world, rotations, skin, activation)
            local[i] = qrot(inv, tuple(skinned[k]-bar[k] for k in range(3)))
        for key, faces in groups.items():
            stat = per_finger[key]
            minimum_upper = float('inf')
            minimum_lower = float('inf')
            for a, b, c in faces:
                scan = bounded_triangle(local[a], local[b], local[c])
                minimum_upper = min(minimum_upper, scan['upper'])
                minimum_lower = min(minimum_lower, scan['lower'])
                stat['evaluatedTriangles'] += 1
                stat['sdfEvaluations'] += scan['samples']
            stat['minimumSampledSignedDistanceMeters'] = min(
                stat['minimumSampledSignedDistanceMeters'], minimum_upper)
            if minimum_upper < -EPS:
                stat['sampledPenetrationFrames'] += 1
            elif minimum_lower > EPS:
                stat['separatedFrames'] += 1
            else:
                stat['unresolvedFrames'] += 1
    for key, stat in per_finger.items():
        if (sum(stat[label] for label in (
                'sampledPenetrationFrames', 'separatedFrames',
                'unresolvedFrames')) != len(SAMPLED_FRAMES) or
                stat['evaluatedTriangles'] != (
                    stat['trianglesPerFrame'] * len(SAMPLED_FRAMES))):
            raise ValueError('Incomplete adaptive finger evidence '+key)
        stat['minimumSampledSignedDistanceMeters'] = round(
            stat['minimumSampledSignedDistanceMeters'], 7)
    return {
        'exerciseId': exercise,
        'sourceSha256': hashlib.sha256(raw).hexdigest(),
        'sourceTopologyVersion': 922, 'rigJoints': 55,
        'sampledFrames': list(SAMPLED_FRAMES), 'fps': FPS,
        'distalRegions': 10, 'renderedSkinNotJointProxies': True,
        'animatedBarRotationApplied': True,
        'fingerRegions': per_finger,
        'contactIKCompleted': False,
        'collisionFreeAcrossTimeCertified': False,
        'anatomicalHandApproved': False,
        'approved': False, 'enabled': False,
    }


def build(refined_dir, output):
    refined_dir, output = Path(refined_dir), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    for exercise in EXERCISES:
        source = refined_dir / (
            f'{exercise}_v922_fingertip_mesh_mobile_qa.glb')
        reports.append(audit(source.read_bytes(), exercise))
    result = {
        'schema': 'stk_v923_adaptive_skinned_finger_bar_bounds_qa',
        'scope': 'offline_qa_only',
        'catalogCount': 229, 'pilotCount': 3, 'sourceVersion': 922,
        'sampledPoseCount': len(SAMPLED_FRAMES),
        'subdivisionDepth': DEPTH,
        'signedDistanceLipschitzBound': 1,
        'conservativeAtSampledPoses': True,
        'continuousTimeCollisionCertified': False,
        'fingerIKSolved': False,
        'professionalHandSculptCompleted': False,
        'physicalDeviceVerified': False,
        'approved': False, 'enabled': False,
        'limitations': [
            'Discrete 0.5 s snapshots; cannot rule out collisions between poses',
            'Cylinder shaft proxy omits grip pressure, friction and collars',
            'Distal weights select approximate actual finger-skin triangles',
            'Unresolved near-contact is never interpreted as penetration-free',
            'This only measures v9.22 geometry, no new anatomy or rig changes',
        ],
        'pilots': reports,
    }
    (output / 'finger_contact_bounds_v923.json').write_text(
        json.dumps(result, indent=2) + '\n', encoding='utf8')
    return result


if __name__ == '__main__':
    cli = argparse.ArgumentParser()
    cli.add_argument('--input', required=True, type=Path)
    cli.add_argument('--output', required=True, type=Path)
    args = cli.parse_args()
    print(json.dumps({
        'schema': build(args.input, args.output)['schema'],
        'approved': False, 'enabled': False,
    }, indent=2))
