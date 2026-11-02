#!/usr/bin/env python3
"""STK Haven v9.22: REAL local mesh subdivision of finger-tip surface.

Edits the actual indexed GLB skin, adding midpoint vertices and conforming
triangles near all ten distal phalanges. Preserves original mesh vertices,
55-node rig, existing morph/animation clips, body materials and equipment.
No overlays, duplicated skin, or fake contact points are introduced.

This is a constrained *local retopology candidate*, not new anatomical hand
sculpt, full palm topology, nail geometry or solved contact IK. QA ONLY:
approved=false, enabled=false, no Flutter catalog/pubspec integration.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import struct
from pathlib import Path

from retarget_cc0_glb import GLB, EXERCISES, cross, dot, sub, norm
from review_fingertip_mesh_v919 import _verified_mesh
from sculpt_finger_pads_v920 import _faces
from build_master_high_res_v914 import blended_joint, normalized

MAX_NEW_VERTICES = 3000
MAX_TOTAL_TRIANGLES = 20000
MAX_MOBILE_BYTES = 1400 * 1024
MAX_CURVATURE_METERS = .00045
MIN_RETOPOLOGIZED_FACES = 20
VERTEX_COUNT = 4727
TRIANGLE_COUNT = 9843


def _split(a, b, c, midpoints):
    """Conforming triangulation of a triangle with 0-3 selected edges.

    Cyclic permutations preserve input winding; no T-junctions occur, since
    an edge is split in *every* neighbouring body-region primitive.
    """
    edges = ((a, b), (b, c), (c, a))
    mids = [midpoints.get(tuple(sorted(pair))) for pair in edges]
    count = sum(v is not None for v in mids)
    if count == 0:
        return [(a, b, c)]
    if count == 3:
        ab, bc, ca = mids
        return [(a, ab, ca), (ab, b, bc), (ca, bc, c),
                (ab, bc, ca)]
    for x, y, z in ((a, b, c), (b, c, a), (c, a, b)):
        xy = midpoints.get(tuple(sorted((x, y))))
        yz = midpoints.get(tuple(sorted((y, z))))
        zx = midpoints.get(tuple(sorted((z, x))))
        if count == 1 and xy is not None:
            return [(x, xy, z), (xy, y, z)]
        if count == 2 and xy is not None and yz is not None:
            return [(x, xy, z), (xy, y, yz), (xy, yz, z)]
    raise ValueError('Broken conforming mesh edge split')


def _patch_view(glb, patches):
    """Replace existing glTF accessor bytes; no redundant attribute stream.

    All original accessors and buffer views retain their indices. The binary
    is spliced in descending byteOffset order and other views shifted by
    multiples of four, so glTF and Flutter accessor alignment is preserved.
    """
    doc = glb.doc
    views = doc['bufferViews']
    indices = set()
    edits = []
    for accessor_id, rows in patches.items():
        acc = doc['accessors'][accessor_id]
        view_id = acc['bufferView']
        if view_id in indices:
            raise ValueError('Two edited accessors alias one buffer view')
        indices.add(view_id)
        view = views[view_id]
        dtype = {5126: ('f', 4), 5121: ('B', 1), 5123: ('H', 2), 5125: ('I', 4)
                 }.get(acc['componentType'])
        dims = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}.get(acc['type'])
        if dtype is None or dims is None or (
                'byteStride' in view or view.get('buffer') != 0 or
                acc.get('byteOffset', 0) != 0 or
                view['byteLength'] != acc['count']*dims*dtype[1]):
            raise ValueError('Unexpected packed glTF attribute layout')
        if any(len(row) != dims for row in rows):
            raise ValueError('Mismatched accessor vector dimensions')
        oldcount = acc['count']
        old_size = view['byteLength']
        fmt = dtype[0]
        start = view.get('byteOffset', 0)
        if start % 4:
            raise ValueError('Misaligned original attribute')
        packet = struct.pack('<'+str(len(rows)*dims)+fmt,
                             *(v for row in rows for v in row))
        if len(packet) < old_size or oldcount > len(rows):
            raise ValueError('Geometry patch must be additive')
        span = (old_size+3)//4*4
        if start + span > len(glb.binary):
            raise ValueError('Attribute overruns GLB binary')
        padded = packet + bytes((-len(packet)) % 4)
        edits.append((start, start+span, view_id, accessor_id, packet,
                      padded, oldcount, len(rows)))
    edits.sort(reverse=True)
    for start, end, view_id, accessor_id, packet, padded, oldcount, newcount in edits:
        # Catch views actually overlapping the location being changed.
        for i, view in enumerate(views):
            if i == view_id:
                continue
            vstart = view.get('byteOffset', 0)
            vend = vstart + view['byteLength']
            if vstart < end and vend > start:
                raise ValueError('Overlapping packed GLB buffer views')
        delta = len(padded)-(end-start)
        glb.binary[start:end] = padded
        views[view_id]['byteLength'] = len(packet)
        for i, view in enumerate(views):
            if i != view_id and view.get('byteOffset', 0) >= end:
                view['byteOffset'] = view.get('byteOffset', 0)+delta
        acc = doc['accessors'][accessor_id]
        acc['count'] = newcount
        # Updated POSITION/indices bounds are part of glTF validation.
        if 'min' in acc or 'max' in acc:
            dims = len(patches[accessor_id][0])
            data = patches[accessor_id]
            acc['min'] = [min(p[k] for p in data) for k in range(dims)]
            acc['max'] = [max(p[k] for p in data) for k in range(dims)]


def _midpoint(a, b, positions, normals, joints, weights, morph):
    pa, pb = positions[a], positions[b]
    na, nb = normals[a], normals[b]
    midpoint = tuple((x+y)*.5 for x, y in zip(pa, pb))
    try:
        surface_normal = normalized(tuple(na[k]+nb[k] for k in range(3)))
    except ValueError:
        surface_normal = normalized(na)
    direction = sub(pb, pa)
    # Small curvature near distal joints; this does NOT adjust finger length.
    curve = .125*dot(direction, sub(nb, na)) if norm(direction) <= .045 else 0.
    curve = max(-MAX_CURVATURE_METERS, min(MAX_CURVATURE_METERS, curve))
    position = tuple(midpoint[k]+curve*surface_normal[k] for k in range(3))
    skin, strength, discarded = blended_joint(
        joints[a], weights[a], joints[b], weights[b])
    shapes = [tuple((m[a][k]+m[b][k])*.5 for k in range(3))
              for m in morph]
    return position, surface_normal, skin, strength, shapes, abs(curve), discarded


def retopologize(raw, exercise):
    """Replace a v9.20 pilot's indexed hand surface with conforming topology."""
    (glb, p, j, w, morph, _, skin, groups
     ) = _verified_mesh(raw, exercise, True)
    doc = glb.doc
    meta = doc['extras']
    if (meta.get('fingerPadReviewVersion') != 920 or
        meta.get('surfaceCandidateOnly') is not True or
        meta.get('fingerLocalRetopologyVersion') is not None):
        raise ValueError('Require original disabled v9.20 hand-pad candidate')
    old_skins = copy.deepcopy(doc['skins'])
    old_nodes = copy.deepcopy(doc['nodes'])
    old_animations = copy.deepcopy(doc['animations'])
    old_materials = copy.deepcopy(doc['materials'])
    parts = doc['meshes'][0]['primitives']
    normals = glb.accessor(parts[0]['attributes']['NORMAL'])
    faces, attrs = _faces(glb, len(p))
    if len(p) != VERTEX_COUNT or len(faces) != TRIANGLE_COUNT:
        raise ValueError('Unexpected CC0 original mobile topology')
    # Split complete actual faces adjacent to distal vertex skin groups.
    distal = set().union(*(set(v) for v in groups.values()))
    edge_set = set()
    target_faces = 0
    for a, b, c in faces:
        if a in distal or b in distal or c in distal:
            target_faces += 1
            edge_set.update((tuple(sorted((a, b))),
                             tuple(sorted((b, c))),
                             tuple(sorted((c, a)))))
    if not MIN_RETOPOLOGIZED_FACES <= target_faces <= 2500:
        raise ValueError('Distal hand selection too sparse or too broad')
    if not 60 <= len(edge_set) <= MAX_NEW_VERTICES:
        raise ValueError('Unbounded new finger topology')

    vertices = [tuple(row) for row in p]
    out_normals = [tuple(row) for row in normals]
    influences = [tuple(int(x) for x in row) for row in j]
    strengths = [tuple(row) for row in w]
    shapes = [[tuple(row) for row in m] for m in morph]
    midpoints = {}
    lost = 0.
    maximal_curve = 0.
    for a, b in sorted(edge_set):
        position, normal, skin_ids, skin_weights, changes, curve, dropped = (
            _midpoint(a, b, p, normals, j, w, morph))
        midpoints[(a, b)] = len(vertices)
        vertices.append(position)
        out_normals.append(normal)
        influences.append(skin_ids)
        strengths.append(skin_weights)
        for k in range(8):
            shapes[k].append(changes[k])
        maximal_curve = max(maximal_curve, curve)
        lost = max(lost, dropped)
    regions = {}
    splits = []
    source_faces = []
    for part in parts:
        original = [int(x[0]) for x in glb.accessor(part['indices'])]
        if len(original) % 3:
            raise ValueError('Misaligned index triangles')
        triangles = []
        for offset in range(0, len(original), 3):
            a, b, c = original[offset:offset+3]
            refined = _split(a, b, c, midpoints)
            triangles.extend(i for face in refined for i in face)
            splits.append(refined)
            source_faces.append((a, b, c))
        regions[part['indices']] = triangles
    # Tight bending can fold small original faces: fall back to linear
    # midpoints on the offending shared edges, then recheck *every* face.
    suppressed = set()
    for _ in range(3):
        inverted = set()
        for (a, b, c), subfaces in zip(source_faces, splits):
            old = cross(sub(p[b], p[a]), sub(p[c], p[a]))
            if norm(old) < 1e-11:
                continue
            for x, y, z in subfaces:
                refined = cross(sub(vertices[y], vertices[x]),
                                sub(vertices[z], vertices[x]))
                if dot(old, refined) <= 0:
                    inverted.update(i for i in (x, y, z) if i >= len(p))
        if not inverted:
            break
        new = inverted-suppressed
        if not new:
            raise ValueError('Original CC0 topology has invalid finger faces')
        reverse = {index: edge for edge, index in midpoints.items()}
        for index in new:
            a, b = reverse[index]
            vertices[index] = tuple((p[a][i]+p[b][i])*.5 for i in range(3))
        suppressed.update(new)
    if inverted or len(suppressed) > max(55, len(edge_set)//30):
        raise ValueError('Local finger retopology folds too many faces')
    total_triangles = sum(len(ids)//3 for ids in regions.values())
    if not TRIANGLE_COUNT < total_triangles <= MAX_TOTAL_TRIANGLES:
        raise ValueError('No bounded actual triangle refinement')
    if len(shapes) != 8 or any(len(s) != len(vertices) for s in
         (out_normals, influences, strengths, *shapes)):
        raise ValueError('Incomplete new finger skin or corrective shapes')
    if any(abs(sum(row)-1)>0.002 for row in strengths):
        raise ValueError('Bad skinned weight normalization')
    if len(regions) != 12:
        raise ValueError('Atlas regions unexpectedly merged')

    patches = {
        attrs['POSITION']: vertices,
        attrs['NORMAL']: out_normals,
        attrs['JOINTS_0']: influences,
        attrs['WEIGHTS_0']: strengths,
    }
    for shape_meta, rows in zip(parts[0]['targets'], shapes):
        patches[shape_meta['POSITION']] = rows
    for acc, new_indices in regions.items():
        patches[acc] = [(v,) for v in new_indices]
    if len(patches) != 24:
        raise ValueError('Expected 12 geometry plus 12 atlas index streams')
    _patch_view(glb, patches)
    meta.update({
        'fingerLocalRetopologyVersion': 922,
        'localRetopologyCandidate': True,
        'sourceHandPadSha256': hashlib.sha256(raw).hexdigest(),
        'handAnatomyProfessionallyApproved': False,
        'fullHandRetopologyComplete': False,
        'fingerContactIKComplete': False,
        'fingerSurfaceToBarContactValidated': False,
        'continuousCollisionFree': False,
        'approved': False, 'enabled': False,
    })
    if (doc['skins'] != old_skins or doc['nodes'] != old_nodes or
        doc['animations'] != old_animations or
        doc['materials'] != old_materials):
        raise ValueError('Retopology altered existing rig/clips/materials')
    result = glb.bytes()
    if len(result) > MAX_MOBILE_BYTES:
        raise ValueError('Retopologized GLB exceeds mobile QA budget')
    # Read the generated GLB, not just the in-memory structures.
    restored = GLB(result, expected_sha=None)
    newattrs = restored.doc['meshes'][0]['primitives'][0]['attributes']
    if (len(restored.accessor(newattrs['POSITION'])) != len(vertices) or
        sum(len(restored.accessor(part['indices']))//3 for part in
            restored.doc['meshes'][0]['primitives']) != total_triangles):
        raise ValueError('Round-trip glTF index/geometry integrity failure')
    return result, {
        'exerciseId': exercise,
        'sourceSha256': hashlib.sha256(raw).hexdigest(),
        'outputSha256': hashlib.sha256(result).hexdigest(),
        'sourceVertices': len(p), 'newVertices': len(vertices),
        'edgeMidpointVerticesAdded': len(edge_set),
        'originalTriangles': len(faces),
        'retopologizedTriangles': total_triangles,
        'targetDistalFaces': target_faces,
        'topologyConforming': True,
        'maxAddedCurvatureMeters': round(maximal_curve, 7),
        'curvatureSuppressedVertices': len(suppressed),
        'maxDroppedSkinWeight': round(lost, 7),
        'jointCount': 55, 'morphTargets': 8,
        'mobileBytes': len(result), 'budgetBytes': MAX_MOBILE_BYTES,
        'handProportionCorrectionCompleted': False,
        'contactIKCompleted': False, 'professionalAnatomyReviewed': False,
        'physicalDeviceVerified': False, 'approved': False, 'enabled': False,
    }


def build(root, output):
    parent = Path(root)/'contact_v918'/'skin_v919'/'hand_v920'
    target = Path(output)
    target.mkdir(parents=True, exist_ok=True)
    reports = []
    for exercise in EXERCISES:
        source = (parent/f'{exercise}_v920_hand_surface_mobile_qa.glb'
                  ).read_bytes()
        generated, report = retopologize(source, exercise)
        (target/f'{exercise}_v922_fingertip_mesh_mobile_qa.glb'
         ).write_bytes(generated)
        reports.append(report)
    summary = {
        'schema': 'stk_v922_real_local_finger_mesh_subdivision',
        'catalogCount': 229, 'pilotCount': 3, 'jointCount': 55,
        'morphTargets': 8, 'mobileBudgetBytes': MAX_MOBILE_BYTES,
        'topologyActuallyChanged': True,
        'fullAnatomicalHandRetopologyComplete': False,
        'contactIKComplete': False, 'continuousCollisionCertified': False,
        'professionalArtApproved': False, 'physicalDeviceVerified': False,
        'productionReady': False, 'approved': False, 'enabled': False,
        'limitations': [
            'Adaptive conforming finger-pad subdivision, not redesigned hand proportions',
            'Original CC0 hand skin and topology outside selected distal faces remain unchanged',
            'Existing grasp animation preserved, no fingertip-to-bar IK correction',
            'No continuous triangle-cylinder collision certification or hand expert approval',
        ],
        'pilots': reports,
    }
    (target/'fingertip_topology_v922_report.json').write_text(
        json.dumps(summary, indent=2)+'\n', encoding='utf8')
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = build(args.input, args.output)
    print(json.dumps({'schema':result['schema'],
                      'pilotCount':result['pilotCount'],
                      'productionReady':False}, indent=2))
