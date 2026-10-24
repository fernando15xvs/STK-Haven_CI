#!/usr/bin/env python3
"""v9.20: bounded fingertip-pad surface candidate on 3 DISABLED mobile GLBs.

Not retopology, an anatomical reconstruction, contact IK, or approval. The
existing mesh topology, 55 bones, 8 morph targets and animation are unchanged.
The affected *rest-pose* vertices are identified by real distal-phalanx skin
weights, never by fabricated 3-D fingertip points. Actual deformed mesh is
sampled again at 121 frames by the v9.19 auditor after the edit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import EXERCISES, add, sub, mul, dot, norm
from review_fingertip_mesh_v919 import _verified_mesh, measure, FRAMES
from bake_master_detail_v915 import _oriented, _new_normals
from build_master_surface_v6 import replace_accessor
from animate_hand_grip_v917 import DIGITS, SIDES

MAX_PAD_METERS = .00075
MIN_CANDIDATE_MOVEMENT = .000001
MAX_GAP_REGRESSION_METERS = .002
SCALES = (1., .5, .25, .125, .0625, .03125)


def _faces(glb, n):
    faces = []
    primitives = glb.doc['meshes'][0]['primitives']
    attrs = primitives[0]['attributes']
    targets = primitives[0]['targets']
    for primitive in primitives:
        if primitive['attributes'] != attrs or primitive['targets'] != targets:
            raise ValueError('Region streams do not share one original skin')
        ids = [int(v[0]) for v in glb.accessor(primitive['indices'])]
        if len(ids) % 3 or any(i < 0 or i >= n for i in ids):
            raise ValueError('Bad indexed triangle mesh')
        faces.extend(tuple(ids[k:k+3]) for k in range(0, len(ids), 3))
    if len(faces) != 9843:
        raise ValueError('Expected original 9843 mobile skin triangles')
    return faces, attrs


def sculpt(raw, exercise):
    """Create ONE optional QA-only surface candidate; do not publish."""
    glb, points, joints, weights, deltas, ibm, skin, groups = (
        _verified_mesh(raw, exercise, True))
    meta = glb.doc['extras']
    if meta.get('fingerPadReviewVersion') is not None:
        raise ValueError('Refuse repeated fingertip sculpt')
    faces, attrs = _faces(glb, len(points))
    normals = glb.accessor(attrs['NORMAL'])
    if len(normals) != len(points):
        raise ValueError('Missing original normals')

    # Vectors in the neutral CC0 mesh coordinates; v9.20 changes no joint or
    # wrist pose. The last two phalanx joint origins establish each tip axis.
    # A small local radial pad avoids stretching fingertips arbitrarily toward
    # the moving bar, which would merely conceal real grip errors.
    displacement = {}
    weight_sums = {}
    masks = {}
    for side in SIDES:
        for digit in DIGITS:
            key = (side, digit)
            before = glb.restpos[glb.by_name[f'{digit}_02_{side}']]
            tip = glb.restpos[glb.by_name[f'{digit}_03_{side}']]
            axis = sub(tip, before)
            axis_length = norm(axis)
            if not .003 < axis_length < .15:
                raise ValueError('Distal phalanx reference is degenerate')
            axis = mul(axis, 1 / axis_length)
            palette = skin.index(glb.by_name[f'{digit}_03_{side}'])
            active = 0
            for i in groups[key]:
                p = points[i]
                rel = sub(p, tip)
                longitudinal = dot(rel, axis)
                radial = sub(rel, mul(axis, longitudinal))
                r = norm(radial)
                strength = sum(float(w) for j, w in zip(joints[i], weights[i])
                               if int(j) == palette)
                taper = math.exp(-.5 * (longitudinal / .015) ** 2)
                radial_taper = min(1., r / .004)
                s = max(0., (strength - .20) / .8) * taper * radial_taper
                if r < 1e-9 or s < .01:
                    continue
                vector = mul(radial, s * MAX_PAD_METERS / r)
                displacement[i] = add(displacement.get(i, (0., 0., 0.)),
                                      vector)
                weight_sums[i] = weight_sums.get(i, 0) + 1
                active += 1
            masks[f'{digit}_{side}'] = active

    # Multiple distal influences may share vertices. Average contributions
    # rather than doubling a movement at overlapping palm/finger seams.
    vectors = {i: mul(value, 1 / weight_sums[i])
               for i, value in displacement.items()}
    if any(norm(v) > MAX_PAD_METERS + 1e-8 for v in vectors.values()):
        raise ValueError('Exceeded bounded surface correction')
    if len(vectors) < 10:
        raise ValueError('No adequate real distal-pad mesh to sculpt')

    accepted = None
    for scale in SCALES:
        candidate = [add(point, mul(vectors[i], scale)) if i in vectors
                     else point for i, point in enumerate(points)]
        if _oriented(points, candidate, faces) == 0:
            accepted = candidate, scale
            break
    if accepted is None:
        raise ValueError('No safe surface displacement without face inversion')
    candidate, scale = accepted
    edited = {i for i in vectors if norm(sub(candidate[i], points[i])) >
              MIN_CANDIDATE_MOVEMENT}
    if len(edited) < 10:
        raise ValueError('Candidate has insufficient measurable surface edits')

    # Keep legacy normals on unaffected vertices and retain the established
    # anatomical normal-bake appearance everywhere outside edited fingers.
    suggested = _new_normals(candidate, normals, faces)
    revised_normals = list(normals)
    for i in edited:
        revised_normals[i] = suggested[i]
    replace_accessor(glb, attrs['POSITION'], candidate)
    replace_accessor(glb, attrs['NORMAL'], revised_normals)
    meta.update({
        'fingerPadReviewVersion': 920,
        'surfaceCandidateOnly': True,
        'expertHandAnatomyReviewed': False,
        'fingerSurfaceToBarContactValidated': False,
        'continuousCollisionFree': False,
        'approved': False,
        'enabled': False,
    })
    generated = glb.bytes()
    if len(generated) > 1400 * 1024:
        raise ValueError('Sculpt exceeds unpublished GLB mobile size cap')

    # A local surface change cannot certify grip. Detect regressions using
    # *actual skinned/morphed* fingertip vertices over the entire four seconds.
    original_metrics = measure(raw, exercise, True)
    candidate_metrics = measure(generated, exercise, True)
    changes = {}
    for name, previous in original_metrics['fingerSurfaceMetrics'].items():
        after = candidate_metrics['fingerSurfaceMetrics'][name]
        regression = (after['meanNearestPositiveGapMeters'] -
                      previous['meanNearestPositiveGapMeters'])
        if regression > MAX_GAP_REGRESSION_METERS:
            raise ValueError('Candidate worsens mean real-skin finger clearance')
        changes[name] = {
            'meanGapBeforeMeters': previous['meanNearestPositiveGapMeters'],
            'meanGapAfterMeters': after['meanNearestPositiveGapMeters'],
            'changeMeters': round(regression, 7),
            'sampledVertices': after['sampledMeshVertexCount'],
            'expertReviewPending': True,
        }

    return generated, {
        'exerciseId': exercise,
        'inputSha256': hashlib.sha256(raw).hexdigest(),
        'outputSha256': hashlib.sha256(generated).hexdigest(),
        'mobileBytes': len(generated),
        'changedPositionVertices': len(edited),
        'maxActualDisplacementMeters': round(max(
            norm(sub(a, b)) for a, b in zip(points, candidate)), 9),
        'scaleWithoutInvertedTriangles': scale,
        'invertedTriangles': 0,
        'changedJointCount': 0,
        'changedMorphCount': 0,
        'changedAnimationChannelCount': 0,
        'changedSkinWeightCount': 0,
        'distalGroups': masks,
        'frameCount': FRAMES,
        'skinnedGapComparison': changes,
        'contactCertified': False,
        'professionalAnatomyApproved': False,
        'physicalDeviceVerified': False,
        'approved': False,
        'enabled': False,
    }


def build(origin, out_dir):
    inputs = Path(origin) / 'contact_v918'
    output = Path(out_dir)
    output.mkdir(parents=True, exist_ok=True)
    pilots = []
    for exercise in EXERCISES:
        raw = (inputs / (exercise + '_v918_contact_mobile_qa.glb')).read_bytes()
        result, details = sculpt(raw, exercise)
        (output / (exercise + '_v920_hand_surface_mobile_qa.glb')).write_bytes(
            result)
        pilots.append(details)
    report = {
        'schema': 'stk_v920_bounded_hand_surface_review',
        'scope': 'unpublished_qa_only',
        'pilotCount': 3, 'catalogCount': 229, 'rigJoints': 55,
        'preservedMorphTargets': 8, 'framesPerExercise': FRAMES,
        'maxPadDisplacementMeters': MAX_PAD_METERS,
        'zeroTopologyChanges': True,
        'continuousCollisionCertified': False,
        'actualFingertipRetopologyCompleted': False,
        'independentProfessionalReviewComplete': False,
        'physicalDeviceVerified': False,
        'approved': False, 'enabled': False,
        'limitations': [
            'Bounded rest-pose pad relief, NOT new hand topology or anatomical sculpt',
            'No finger IK, self-collision, pressure, friction or grip certification',
            'Nearest sampled skin vertices can conceal surface-to-cylinder clipping',
            'Professional hand retopology and full-surface collision remain required',
        ],
        'pilots': pilots,
    }
    (output / 'hand_surface_v920_report.json').write_text(
        json.dumps(report, indent=2) + '\n', encoding='utf8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.input, args.output), indent=2))
