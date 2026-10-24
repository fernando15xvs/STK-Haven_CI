#!/usr/bin/env python3
"""STK Haven v9.24 — anatomical palm and thenar VOLUME sculpt, QA ONLY.

Edits the genuine common skinned glTF POSITION and NORMAL attribute buffers
in three v9.22 GLBs. The thenar/palm geometry moves in THREE DIMENSIONS,
not an overlay, stylized sticker, or a second mesh. Keeps existing triangles,
55 bind matrices, 30 finger tracks, the 8 morphs and rigid gym equipment.
No professional hand anatomy or collision-free grasp is implied.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import EXERCISES, dot, sub, mul, add, cross, norm, unit
from animate_hand_grip_v917 import SIDES
from audit_finger_contact_bounds_v923 import _read_refined
from refine_fingertip_topology_v922 import _patch_view, MAX_MOBILE_BYTES
from bake_master_detail_v915 import _oriented, _new_normals

MAX_DISPLACEMENT_METERS = .0035
MIN_EFFECTIVE_MOVE_METERS = .000008
SCULPT_FACTORS = (1., .65, .40, .25, .15, .09, .05, .025)
MIN_CHANGED_PER_HAND = 8


def _reference(glb, side, skin):
    """Derive hand-local longitudinal, palmar and thumb axes from REAL rig."""
    names = (
        f'hand_{side}', f'index_01_{side}', f'middle_01_{side}',
        f'pinky_01_{side}', f'thumb_01_{side}', f'thumb_02_{side}',
        f'ring_01_{side}',
    )
    if any(name not in glb.by_name or glb.by_name[name] not in skin
           for name in names):
        raise ValueError('Missing skinned palm/thumb bone '+side)
    p = [glb.restpos[glb.by_name[name]] for name in names]
    wrist, index, middle, pinky, thumb, next_thumb, ring = p
    forward = sub(middle, wrist)
    across = sub(index, pinky)
    length, width = norm(forward), norm(across)
    if not .012 < length < .27 or not .009 < width < .19:
        raise ValueError('Implausible palm length or metacarpal width')
    forward = unit(forward)
    across = sub(across, mul(forward, dot(across, forward)))
    if norm(across) < width * .34:
        raise ValueError('Metacarpal and palm axes too parallel')
    across = unit(across)
    plane_normal = unit(cross(forward, across))
    centre = add(wrist, mul(sub(middle, wrist), .54))
    thumb_out = sub(thumb, centre)
    thumb_out = sub(thumb_out, mul(forward, dot(thumb_out, forward)))
    if norm(thumb_out) < .004:
        thumb_out = sub(next_thumb, centre)
        thumb_out = sub(thumb_out, mul(forward, dot(thumb_out, forward)))
    if norm(thumb_out) < .004:
        raise ValueError('Cannot resolve thumb opposition direction from rig')
    palm_ids = [skin.index(glb.by_name[name]) for name in names]
    return dict(side=side, wrist=wrist, centre=centre, thumb=thumb,
                forward=forward, across=across, normal=plane_normal,
                thumb_dir=unit(thumb_out), length=length, width=width,
                palettes=palm_ids)


def _influence(joints, weights, indices):
    wanted = set(indices)
    return min(1., sum(float(w) for j, w in zip(joints, weights)
                       if int(j) in wanted))


def _smooth_weight(radius):
    if not math.isfinite(radius):
        raise ValueError('Invalid sculpt envelope')
    return math.exp(-min(80., radius*radius))


def _hand_delta(point, joints, weights, ref):
    """Return bounded three-axis palm arch, thumb-base and ulnar contour."""
    wrist, centre, thumb = ref['wrist'], ref['centre'], ref['thumb']
    longitudinal = dot(sub(point, wrist), ref['forward']) / ref['length']
    lateral = dot(sub(point, centre), ref['across']) / (
        max(.018, .76 * ref['width']))
    thickness = dot(sub(point, centre), ref['normal']) / (
        max(.012, .50 * ref['width']))
    if not -.7 < longitudinal < 1.7 or abs(lateral) > 2.4 or abs(thickness) > 2.6:
        return (0., 0., 0.), False
    hand, index, middle, pinky, thumb1, thumb2, ring = ref['palettes']
    palm_strength = _influence(
        joints, weights, (hand, index, middle, ring, pinky))
    thumb_strength = _influence(joints, weights, (thumb1, thumb2))
    pinky_strength = _influence(joints, weights, (hand, pinky))
    envelope = _smooth_weight(
        math.sqrt(((longitudinal-.52)/.58)**2 + (lateral/1.3)**2))
    depth_envelope = _smooth_weight(max(0., abs(thickness)-.9)*1.7)
    # Gentle dorsal/volar bulge: no hard discontinuity at palm midplane.
    arch = (.00175 * envelope * depth_envelope * palm_strength *
            math.tanh(thickness*1.8))
    radial = (.00052 * envelope * palm_strength *
              math.tanh(lateral))
    # Thumb eminence at the ACTUAL first metacarpal/phalange joint.
    thumb_radius = max(.022, ref['width']*.68)
    thumb_distance = norm(sub(point, thumb))/thumb_radius
    thumb_envelope = _smooth_weight(thumb_distance*1.3)
    thenar = .00265 * thumb_strength * thumb_envelope
    # Hypothenar volume towards the little-finger side.
    hypothenar = (.00075 * pinky_strength * envelope *
                  max(0., -math.tanh(lateral)))
    result = add(add(mul(ref['normal'], arch),
                     mul(ref['across'], radial-hypothenar)),
                 mul(ref['thumb_dir'], thenar))
    distance = norm(result)
    if distance > MAX_DISPLACEMENT_METERS:
        result = mul(result, MAX_DISPLACEMENT_METERS / distance)
    return result, thenar > .00004


def _triangles(glb, vertex_count):
    faces = []
    for part in glb.doc['meshes'][0]['primitives']:
        ids = [int(x[0]) for x in glb.accessor(part['indices'])]
        if len(ids) % 3 or any(i < 0 or i >= vertex_count for i in ids):
            raise ValueError('Malformed shared atlas indices')
        faces.extend(tuple(ids[k:k+3]) for k in range(0, len(ids), 3))
    if not 9843 < len(faces) <= 20000:
        raise ValueError('Expected v9.22 refined palm surface')
    return faces


def sculpt(raw, exercise):
    """Produce a NEW disabled GLB, never modify the original/source file."""
    glb, points, joints, weights, morph, ibm, skin, _ = (
        _read_refined(raw, exercise))
    doc, extras = glb.doc, glb.doc['extras']
    if (extras.get('palmThumbSculptVersion') is not None or
            extras.get('fingerLocalRetopologyVersion') != 922):
        raise ValueError('Only original v9.22 hand topology accepted')
    old_skin = json.dumps(doc['skins'], sort_keys=True)
    old_nodes = json.dumps(doc['nodes'], sort_keys=True)
    old_motions = json.dumps(doc['animations'], sort_keys=True)
    old_materials = json.dumps(doc['materials'], sort_keys=True)
    parts = doc['meshes'][0]['primitives']
    attrs = parts[0]['attributes']
    normals = glb.accessor(attrs['NORMAL'])
    if len(points) != len(normals):
        raise ValueError('Incomplete palm normals')
    faces = _triangles(glb, len(points))
    reference = {side: _reference(glb, side, skin) for side in SIDES}

    # Keep existing distal finger topology EXACTLY unmoved. The v9.22 hand
    # subdivision remains valid, with its original skin/morphs and grip.
    distal_palettes = {skin.index(glb.by_name[f'{digit}_03_{side}'])
                       for side in SIDES
                       for digit in ('index','middle','ring','pinky','thumb')}
    moved = {}
    owners = {}
    thumb_hits = {side: set() for side in SIDES}
    for i, point in enumerate(points):
        if _influence(joints[i], weights[i], distal_palettes) >= .20:
            continue
        choices = []
        for side in SIDES:
            delta, is_thumb = _hand_delta(
                point, joints[i], weights[i], reference[side])
            choices.append((norm(delta), side, delta, is_thumb))
        value, side, delta, is_thumb = max(choices)
        if value > MIN_EFFECTIVE_MOVE_METERS:
            moved[i] = delta
            owners[i] = side
            if is_thumb:
                thumb_hits[side].add(i)
    rough_count = {side: sum(s == side for s in owners.values())
                   for side in SIDES}
    if any(rough_count[side] < MIN_CHANGED_PER_HAND or
           len(thumb_hits[side]) < 3 for side in SIDES):
        raise ValueError('No measurable bilateral palm or thenar correction')

    # Revert to smaller geometrically safe sculpt factors where CC0's old
    # triangles contain narrow faces; NEVER approve an inverted triangle.
    accepted = None
    for factor in SCULPT_FACTORS:
        candidate = [add(point, mul(moved[i], factor)) if i in moved
                     else tuple(point) for i, point in enumerate(points)]
        if _oriented(points, candidate, faces) == 0:
            accepted = candidate, factor
            break
    if accepted is None:
        raise ValueError('Palm/thenar change cannot preserve face winding')
    candidate, factor = accepted
    actual = max(norm(sub(a, b)) for a, b in zip(candidate, points))
    if not 0 < actual <= MAX_DISPLACEMENT_METERS + 1e-7:
        raise ValueError('Outside hand volume correction bounds')

    # Recompute only changed surface shading and immediate face neighbours;
    # keep every other CC0 normal identical. Do not touch morph offsets.
    affected = set(moved)
    for a, b, c in faces:
        if a in moved or b in moved or c in moved:
            affected.update((a, b, c))
    revised = _new_normals(candidate, normals, faces)
    result_normals = [tuple(revised[i]) if i in affected else tuple(old)
                      for i, old in enumerate(normals)]
    _patch_view(glb, {
        attrs['POSITION']: candidate,
        attrs['NORMAL']: result_normals,
    })
    extras.update({
        'palmThumbSculptVersion': 924,
        'palmThumbMeshEdited': True,
        'sourceFingerMeshSha256': hashlib.sha256(raw).hexdigest(),
        'fullProfessionalHandRetopologyComplete': False,
        'fingerContactIKComplete': False,
        'continuousCollisionFree': False,
        'independentAnatomyReviewComplete': False,
        'physicalDeviceVerified': False,
        'approved': False, 'enabled': False,
    })
    if (json.dumps(doc['skins'],sort_keys=True) != old_skin or
            json.dumps(doc['nodes'],sort_keys=True) != old_nodes or
            json.dumps(doc['animations'],sort_keys=True) != old_motions or
            json.dumps(doc['materials'],sort_keys=True) != old_materials):
        raise ValueError('Palm sculpt changed rig, animation or materials')
    output = glb.bytes()
    if len(output) > MAX_MOBILE_BYTES:
        raise ValueError('Palm sculpt exceeds quarantined GLB byte budget')
    # Validate the result is real GLB geometry with changed, finite surfaces.
    from retarget_cc0_glb import GLB
    decoded = GLB(output, expected_sha=None)
    out_attrs = decoded.doc['meshes'][0]['primitives'][0]['attributes']
    if (len(decoded.accessor(out_attrs['POSITION'])) != len(points) or
            any(not all(math.isfinite(v) for v in row)
                for row in decoded.accessor(out_attrs['NORMAL']))):
        raise ValueError('Invalid exported palm geometry')
    report = {
        'exerciseId': exercise, 'sourceTopologyVersion': 922,
        'sourceSha256': hashlib.sha256(raw).hexdigest(),
        'outputSha256': hashlib.sha256(output).hexdigest(),
        'sourceVertices': len(points), 'resultVertices': len(candidate),
        'trianglesPreserved': len(faces), 'jointsPreserved': 55,
        'morphsPreserved': len(morph),
        'bilateralEditedVertices': rough_count,
        'bilateralThenarVertices': {
            side: len(thumb_hits[side]) for side in SIDES},
        'effectiveFactor': factor,
        'maximumDisplacementMeters': round(actual, 8),
        'normalsRecomputedForVertices': len(affected),
        'rigAndMotionPreserved': True,
        'professionalHandSculptCompleted': False,
        'handContactIKCompleted': False,
        'deviceValidated': False,
        'mobileBytes': len(output),
        'approved': False, 'enabled': False,
    }
    return output, report


def build(folder, output):
    folder, output = Path(folder), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    for exercise in EXERCISES:
        raw = (folder/f'{exercise}_v922_fingertip_mesh_mobile_qa.glb'
               ).read_bytes()
        sculpted, report = sculpt(raw, exercise)
        (output/f'{exercise}_v924_palm_thumb_surface_mobile_qa.glb'
         ).write_bytes(sculpted)
        reports.append(report)
    summary = {
        'schema': 'stk_v924_bilateral_palm_thenar_real_mesh_volume_qa',
        'scope': 'three_disabled_exercise_pilots',
        'catalogCount': 229, 'rigJoints': 55,
        'morphTargets': 8, 'pilots': reports,
        'professionalSculptApproved': False,
        'contactIKComplete': False,
        'physicalDeviceVerified': False,
        'productionReady': False,
        'approved': False, 'enabled': False,
    }
    (output/'palm_thenar_surface_v924_report.json').write_text(
        json.dumps(summary, indent=2)+'\n', encoding='utf8')
    return summary


if __name__ == '__main__':
    arg = argparse.ArgumentParser()
    arg.add_argument('--input', type=Path, required=True)
    arg.add_argument('--output', type=Path, required=True)
    x = arg.parse_args()
    summary = build(x.input, x.output)
    print(json.dumps({'schema': summary['schema'], 'pilots': 3,
                      'productionReady': False}, indent=2))
