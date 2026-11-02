#!/usr/bin/env python3
"""STK Haven v9.25: conforming palm/thenar local mesh subdivision. QA ONLY.

Extend the actual v9.24 sculpted shared glTF skin without modifying existing
vertices, rig, morph clips or equipment. Not a complete anatomical retopo,
professional artwork, physical contact IK, or production media.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from animate_hand_grip_v917 import SIDES
from retarget_cc0_glb import EXERCISES, GLB, cross, dot, norm, sub
from build_master_high_res_v914 import blended_joint, normalized
from audit_finger_contact_bounds_v923 import _read_refined
from sculpt_palm_thenar_v924 import (
    _hand_delta, _influence, _reference, _triangles, MIN_EFFECTIVE_MOVE_METERS,
)
from refine_fingertip_topology_v922 import (
    _split, _patch_view, MAX_MOBILE_BYTES,
)

TARGET_EDGES_PER_HAND = 170
MIN_EDGES_PER_HAND = 20
THENAR_RESERVED_EDGES_PER_HAND = 26
MIN_THENAR_EDGES_PER_HAND = 4
MAX_NEW_VERTICES = 450
MAX_TOTAL_TRIANGLES = 20000
MIN_EDGE_METERS = .0004
MAX_EDGE_METERS = .09


def _selected_edges(glb, positions, joints, weights, skin, faces):
    """Choose real hand-skin edges with bilateral thumb-root reservation."""
    reference = {side: _reference(glb, side, skin) for side in SIDES}
    distal = {
        skin.index(glb.by_name[f'{digit}_03_{side}'])
        for side in SIDES
        for digit in ('index','middle','ring','pinky','thumb')
    }
    owner = {}
    for i, point in enumerate(positions):
        if _influence(joints[i], weights[i], distal) >= .20:
            continue
        choices = []
        for side in SIDES:
            delta, thenar = _hand_delta(
                point, joints[i], weights[i], reference[side])
            choices.append((norm(delta), side, thenar))
        strength, side, thenar = max(choices)
        if strength > MIN_EFFECTIVE_MOVE_METERS:
            owner[i] = (strength, side, thenar)

    buckets = {side: {} for side in SIDES}
    for face in faces:
        signals = [owner[i] for i in face if i in owner]
        if not signals:
            continue
        strength, side, _ = max(signals)
        has_thenar = any(owner[i][1] == side and owner[i][2]
                         for i in face if i in owner)
        for a, b in ((face[0],face[1]),(face[1],face[2]),
                     (face[2],face[0])):
            if not MIN_EDGE_METERS < math.dist(
                    positions[a], positions[b]) < MAX_EDGE_METERS:
                continue
            edge = tuple(sorted((a,b)))
            prev = buckets[side].get(edge)
            if prev is None or strength > prev[0]:
                buckets[side][edge] = (strength, has_thenar)
            elif has_thenar:
                buckets[side][edge] = (prev[0], True)
    selected = {}
    summary = {}
    for side in SIDES:
        rank = lambda item: (-item[1][0], item[0])
        thenar = sorted((x for x in buckets[side].items() if x[1][1]),
                        key=rank)
        all_edges = sorted(buckets[side].items(), key=rank)
        chosen = {edge for edge,_ in thenar[:THENAR_RESERVED_EDGES_PER_HAND]}
        for edge,_ in all_edges:
            if len(chosen) >= TARGET_EDGES_PER_HAND:
                break
            chosen.add(edge)
        thumb_edges = len(chosen & {e for e,_ in thenar})
        if len(chosen) < MIN_EDGES_PER_HAND or (
                thumb_edges < MIN_THENAR_EDGES_PER_HAND):
            raise ValueError('Missing palm or thenar geometry for '+side)
        selected[side] = chosen
        summary[side] = {
            'edgeSplits':len(chosen),
            'thenarEdgeSplits':thumb_edges,
            'candidateEdges':len(all_edges),
        }
    all_selected = set().union(*selected.values())
    if not 2*MIN_EDGES_PER_HAND <= len(all_selected) <= MAX_NEW_VERTICES:
        raise ValueError('Unbounded bilateral palm subdivision')
    return all_selected, summary


def _vertex_on_edge(a,b,positions,normals,joints,weights,morphs):
    pa,pb = positions[a],positions[b]
    position = tuple((pa[k]+pb[k])*.5 for k in range(3))
    try:
        normal = normalized(tuple(normals[a][k]+normals[b][k]
                                  for k in range(3)))
    except ValueError:
        normal = normalized(normals[a])
    palette,strengths,dropped = blended_joint(
        joints[a],weights[a],joints[b],weights[b])
    changes = [tuple((shape[a][k]+shape[b][k])*.5 for k in range(3))
               for shape in morphs]
    return position,normal,palette,strengths,changes,dropped


def _winding(old_faces,new_faces,points):
    if len(old_faces)!=len(new_faces):
        raise ValueError('Missing original atlas faces')
    for (a,b,c),children in zip(old_faces,new_faces):
        before=cross(sub(points[b],points[a]),sub(points[c],points[a]))
        if norm(before)<1e-11:
            continue
        for x,y,z in children:
            after=cross(sub(points[y],points[x]),sub(points[z],points[x]))
            if dot(before,after)<=0.:
                return False
    return True


def retopologize(raw,exercise):
    glb,p,j,w,morph,_,skin,_ = _read_refined(raw,exercise)
    doc,meta=glb.doc,glb.doc['extras']
    if (meta.get('palmThumbSculptVersion')!=924 or
            meta.get('palmThumbMeshEdited') is not True or
            meta.get('palmThumbRetopologyVersion') is not None):
        raise ValueError('Require unmodified v9.24 sculpted palm')
    originals = {key:copy.deepcopy(doc[key]) for key in
                 ('nodes','skins','animations','materials')}
    parts=doc['meshes'][0]['primitives']
    attrs=parts[0]['attributes']
    n=glb.accessor(attrs['NORMAL'])
    faces=_triangles(glb,len(p))
    edges,hand_counts=_selected_edges(glb,p,j,w,skin,faces)

    positions=[tuple(row) for row in p]
    normals=[tuple(row) for row in n]
    palettes=[tuple(int(v) for v in row) for row in j]
    strengths=[tuple(row) for row in w]
    shapes=[[tuple(row) for row in shape] for shape in morph]
    midpoints={}
    lost=0.
    for a,b in sorted(edges):
        point,normal,palette,weights,changes,dropped=_vertex_on_edge(
            a,b,p,n,j,w,morph)
        midpoints[(a,b)]=len(positions)
        positions.append(point)
        normals.append(normal)
        palettes.append(palette)
        strengths.append(weights)
        for shape,delta in zip(shapes,changes):
            shape.append(delta)
        lost=max(lost,dropped)
    if len(shapes)!=8 or any(len(rows)!=len(positions) for rows in
                             (normals,palettes,strengths,*shapes)):
        raise ValueError('Incomplete interpolated palm skin streams')
    if any(not .998<=sum(row)<=1.002 for row in strengths):
        raise ValueError('Non-normalized skin weight in v9.25')
    if any(not all(math.isfinite(v) for v in row) for row in positions):
        raise ValueError('Non-finite retopologized vertices')

    index_streams={}
    source=[]
    children=[]
    for part in parts:
        old=[int(row[0]) for row in glb.accessor(part['indices'])]
        new=[]
        for at in range(0,len(old),3):
            tri=tuple(old[at:at+3])
            refined=_split(*tri,midpoints)
            new.extend(v for f in refined for v in f)
            source.append(tri)
            children.append(refined)
        index_streams[part['indices']]=new
    if not _winding(source,children,positions):
        raise ValueError('Inverted palm or thumb-web triangle')
    for (a,b,c),subfaces in zip(source,children):
        for x,y in ((a,b),(b,c),(c,a)):
            if tuple(sorted((x,y))) in midpoints:
                if any({u,v}=={x,y} for face in subfaces
                       for u,v in ((face[0],face[1]),
                                   (face[1],face[2]),
                                   (face[2],face[0]))):
                    raise ValueError('Unsplit selected edge / T-junction')
    count=sum(len(ids)//3 for ids in index_streams.values())
    if not len(faces)<count<=MAX_TOTAL_TRIANGLES or len(index_streams)!=12:
        raise ValueError('Invalid palm triangle budget or atlas')

    patches={attrs['POSITION']:positions,attrs['NORMAL']:normals,
             attrs['JOINTS_0']:palettes,attrs['WEIGHTS_0']:strengths}
    for target,shape in zip(parts[0]['targets'],shapes):
        patches[target['POSITION']]=shape
    for accessor,indices in index_streams.items():
        patches[accessor]=[(v,) for v in indices]
    if len(patches)!=24:
        raise ValueError('Changed shared atlas accessor layout')
    _patch_view(glb,patches)
    meta.update({
        'palmThumbRetopologyVersion':925,
        'palmThumbTopologyCandidateOnly':True,
        'sourcePalmSculptSha256':hashlib.sha256(raw).hexdigest(),
        'fullProfessionalHandRetopologyComplete':False,
        'fingerContactIKComplete':False,
        'continuousCollisionFree':False,
        'independentAnatomyReviewComplete':False,
        'physicalDeviceVerified':False,
        'approved':False,'enabled':False,
    })
    if any(doc[key]!=value for key,value in originals.items()):
        raise ValueError('Retopology changed rig, motion or materials')
    result=glb.bytes()
    if len(result)>MAX_MOBILE_BYTES:
        raise ValueError('Palm mesh exceeds mobile review byte budget')
    check=GLB(result,expected_sha=None)
    revised=check.doc['meshes'][0]['primitives']
    if (len(check.accessor(revised[0]['attributes']['POSITION']))!=len(positions)
        or sum(len(check.accessor(part['indices']))//3 for part in revised)
        !=count):
        raise ValueError('Bad round-trip glTF palm skin/indices')
    return result,{
        'exerciseId':exercise,'sourcePalmVersion':924,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(result).hexdigest(),
        'sourceVertices':len(p),'resultVertices':len(positions),
        'newPalmVertices':len(edges),
        'sourceTriangles':len(faces),'resultTriangles':count,
        'bilateralRegions':hand_counts,'conformingAcrossAtlas':True,
        'originalPositionsPreserved':True,'morphTargetsPreserved':8,
        'rigJointsPreserved':55,
        'maximumDroppedSkinInfluence':round(lost,7),
        'assetBytes':len(result),
        'professionalHandAnatomyCompleted':False,
        'contactIKCompleted':False,'deviceVerified':False,
        'approved':False,'enabled':False,
    }


def build(source,output):
    source,output=Path(source),Path(output)
    output.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        raw=(source/f'{exercise}_v924_palm_thumb_surface_mobile_qa.glb'
             ).read_bytes()
        result,report=retopologize(raw,exercise)
        (output/f'{exercise}_v925_palm_web_topology_mobile_qa.glb'
         ).write_bytes(result)
        reports.append(report)
    summary={
        'schema':'stk_v925_conforming_palm_thumb_web_qa',
        'catalogCount':229,'pilotCount':3,
        'rigJoints':55,'morphTargets':8,'sourcePalmVersion':924,
        'topologyActuallyChanged':True,
        'fullProfessionalHandRetopologyComplete':False,
        'contactIKComplete':False,'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,'productionReady':False,
        'approved':False,'enabled':False,
        'pilots':reports,
    }
    (output/'palm_thumb_topology_v925_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    report=build(args.input,args.output)
    print(json.dumps({'schema':report['schema'],
                      'pilots':report['pilotCount'],
                      'productionReady':False},indent=2))
