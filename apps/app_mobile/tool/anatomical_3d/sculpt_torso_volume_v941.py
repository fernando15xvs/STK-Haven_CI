#!/usr/bin/env python3
"""STK Haven v9.41: bounded real skinned torso contours, QA ONLY.

Apply the v9.16 artistic rectus/oblique/serratus fields to POSITION and
NORMAL accessors of three disabled v9.40 CC0 55-joint master-exercise GLBs.
Existing v9.16 mobile assets had normal shading but no torso displacement.
This is NOT manual retopology, clinical anatomy or finished mobile art.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from audit_finger_contact_bounds_v923 import _read_refined
from bake_master_detail_v915 import _new_normals, _oriented
from build_torso_contours_v916 import ARTIST_GROUPS, contour_fields
from refine_fingertip_topology_v922 import _patch_view, MAX_MOBILE_BYTES
from retarget_cc0_glb import GLB, EXERCISES, add, mul, norm, sub
from sculpt_lower_leg_anatomy_v940 import _cap_normals, FOLD_SCALE
from sculpt_palm_thenar_v924 import _triangles

MAX_TORSO_DISPLACEMENT_METERS = .00120
MIN_SPINE_SKIN_INFLUENCE = .30
AMPLITUDE = {
    'rectus_abdominis': .00120,
    'obliquus_externus_abdominis': .00095,
    'serratus_anterior': .00090,
}
SPINE_BONES = ('spine_01', 'spine_02', 'spine_03')


def _propose(points, normals, joints, weights, spine_indices):
    """Use actual spine-weighted skin, never equipment or detached nail meshes."""
    if len({len(points), len(normals), len(joints), len(weights)}) != 1:
        raise ValueError('Torso arrays have inconsistent vertex counts')
    counts = {side: {group: 0 for group in ARTIST_GROUPS}
              for side in ('left', 'right')}
    offsets = []
    for p, n, j, w in zip(points, normals, joints, weights):
        spine_weight = sum(float(weight) for bone, weight in zip(j, w)
                           if int(bone) in spine_indices)
        if spine_weight < MIN_SPINE_SKIN_INFLUENCE:
            offsets.append(0.)
            continue
        fields = contour_fields(p, n)
        side = 'left' if p[0] >= 0. else 'right'
        for label, strength in fields.items():
            if strength > .05:
                counts[side][label] += 1
        delta = sum(AMPLITUDE[k] * max(0., min(1., fields[k]))
                    for k in ARTIST_GROUPS)
        # Hard cap, independent of coincident artistic contour peaks.
        offsets.append(min(MAX_TORSO_DISPLACEMENT_METERS,
                           delta * min(1., spine_weight)))
    if any(counts[side][group] < 3
           for side in counts for group in ARTIST_GROUPS):
        raise ValueError('A bilateral torso contour has insufficient real skin')
    if max(offsets, default=0.) < 1e-7:
        raise ValueError('No real torso surface modified')
    return offsets, counts


def sculpt(raw: bytes, exercise: str):
    if exercise not in EXERCISES or len(raw) > MAX_MOBILE_BYTES:
        raise ValueError('Invalid or oversized exercise QA source')
    glb, points, joints, weights, morphs, _ibm, skin, _ = (
        _read_refined(raw, exercise))
    meta = glb.doc['extras']
    if (meta.get('lowerLegContourVersion') != 940
        or meta.get('torsoVolumeVersion') is not None
        or meta.get('approved') is not False
        or meta.get('enabled') is not False
        or len(skin) != 55 or len(morphs) != 8):
        raise ValueError('Expected unapproved v9.40 master anatomy')
    palette = set()
    for name in SPINE_BONES:
        node = glb.by_name.get(name)
        if node is None or node not in skin:
            raise ValueError('Missing original skin-weighted bone: ' + name)
        palette.add(skin.index(node))
    doc = glb.doc
    preserved = {key: copy.deepcopy(doc[key]) for key in
                 ('nodes', 'skins', 'animations', 'meshes', 'materials')}
    primitives = doc['meshes'][0]['primitives']
    attrs = primitives[0]['attributes']
    if any(p['attributes'] != attrs for p in primitives):
        raise ValueError('The twelve body regions must share skin accessors')
    normals = glb.accessor(attrs['NORMAL'])
    offsets, coverage = _propose(
        points, normals, joints, weights, palette)
    faces = _triangles(glb, len(points))
    chosen = None
    for scale in FOLD_SCALE:
        proposal = [add(p, mul(n, d * scale))
                    for p, n, d in zip(points, normals, offsets)]
        if _oriented(points, proposal, faces) == 0:
            chosen = (proposal, scale)
            break
    if chosen is None:
        raise ValueError('Torso surface produced triangle foldovers')
    revised, factor = chosen
    mask = [d > 1e-8 for d in offsets]
    new_normals = _new_normals(revised, normals, faces)
    smoothed, max_angle = _cap_normals(normals, new_normals, mask)
    displacement = max(norm(sub(a,b)) for a,b in zip(points,revised))
    if displacement > MAX_TORSO_DISPLACEMENT_METERS + 1e-8:
        raise ValueError('Torso vertex displaced outside QA safety limit')
    _patch_view(glb, {
        attrs['POSITION']: revised,
        attrs['NORMAL']: smoothed,
    })
    doc['accessors'][attrs['POSITION']]['min'] = [
        min(p[k] for p in revised) for k in range(3)]
    doc['accessors'][attrs['POSITION']]['max'] = [
        max(p[k] for p in revised) for k in range(3)]
    for key, value in preserved.items():
        if doc[key] != value:
            raise ValueError('Unexpected rig, motion or equipment mutation')
    meta.update({
        'torsoVolumeVersion': 941,
        'sourceLowerLegSha256': hashlib.sha256(raw).hexdigest(),
        'torsoApproximateArtisticGroups': list(ARTIST_GROUPS),
        'torsoRetopologyProfessionallyApproved': False,
        'professionalAnatomyComplete': False,
        'biomechanicsCertified': False,
        'continuousCollisionCertified': False,
        'physicalDeviceBenchmarked': False,
        'approved': False, 'enabled': False,
    })
    output = glb.bytes()
    if len(output) > MAX_MOBILE_BYTES:
        raise ValueError('Torso QA asset exceeds 1400KiB budget')
    verified = GLB(output, expected_sha=None)
    if any(verified.doc[k] != preserved[k]
           for k in ('nodes', 'skins', 'animations', 'meshes', 'materials')):
        raise ValueError('Roundtrip lost rig, morphs or equipment')
    vertices = verified.accessor(
        verified.doc['meshes'][0]['primitives'][0]['attributes']['POSITION'])
    if max(norm(sub(a,b)) for a,b in zip(revised,vertices)) > .00001:
        raise ValueError('Roundtrip displaced torso vertices unexpectedly')
    return output, {
        'exerciseId':exercise,
        'inputSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'jointCount':55,
        'morphTargets':8,
        'editedSkinnedBodyVertices':sum(mask),
        'bilateralContourSamples':coverage,
        'maximumTorsoDisplacementMeters':round(displacement,8),
        'maximumNormalChangeDegrees':round(max_angle,5),
        'safeNormalScale':factor,
        'flippedTriangles':0,
        'equipmentAndAnimationPreserved':True,
        'realSkinnedGeometry':True,
        'professionallyReviewed':False,
        'physicalDeviceValidated':False,
        'approved':False,'enabled':False,
        'bytes':len(output),
    }


def build(source_dir, output_dir):
    source_dir, output_dir = Path(source_dir), Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for exercise in EXERCISES:
        raw = (source_dir /
               (exercise+'_v940_lower_leg_anatomy_mobile_qa.glb')).read_bytes()
        payload, row = sculpt(raw, exercise)
        (output_dir /
         (exercise+'_v941_torso_volume_mobile_qa.glb')).write_bytes(payload)
        rows.append(row)
    report = {
        'schema':'stk_v941_real_skinned_bilateral_torso_volume_qa',
        'catalogCount':229,
        'pilotCount':3,
        'torsoApproximateGroups':list(ARTIST_GROUPS),
        'sourceVersion':940,
        'rigJoints':55,
        'morphTargets':8,
        'approved':False,'enabled':False,
        'anatomyProfessionallyApproved':False,
        'physicalDeviceValidated':False,
        'productionReady':False,
        'pilots':rows,
    }
    (output_dir/'torso_volume_v941_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    result = build(args.input,args.output)
    print(json.dumps({'schema':result['schema'],
                      'pilots':result['pilotCount'],
                      'approved':result['approved']},indent=2))
