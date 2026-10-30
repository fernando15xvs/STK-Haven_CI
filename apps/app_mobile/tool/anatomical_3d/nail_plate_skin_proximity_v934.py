#!/usr/bin/env python3
"""STK Haven v9.34: read-only 60 Hz nail-plate/animated-skin proximity QA.

Measure real rigid nail undersides against real morphed, skinned distal skin
TRIANGLES (not proxy spheres) on 241 sampled poses. Flag possible mesh
intersections / float-off. The sign of a triangle's normal is not a guaranteed
inside/outside test on a non-watertight anatomical mesh; therefore this audit
NEVER certifies zero collisions or approves assets, even with zero warnings.

Reads exactly the disabled v9.33 pilot GLBs. No asset or catalog mutation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from animate_hand_grip_v917 import SIDES,DIGITS
from audit_finger_contact_bounds_v923 import _read_refined
from build_rig_nail_plates_v933 import (
    PREFIX,MATERIAL_NAME,GRID_U,GRID_V,
)
from exercise_surface_collision_v911 import _samplers,_sample,_skin_vertex
from retarget_cc0_glb import (
    EXERCISES,add,sub,mul,dot,norm,cross,qrot
)
from refine_fingertip_topology_v922 import MAX_MOBILE_BYTES

FRAMES=241
FPS=60
MAX_FACES_PER_FINGER=48
MAX_SAMPLE_DISTANCE=.006
POSSIBLE_EMBED_DEPTH=.0005
CANDIDATE_DISTANCE=.060
UV_EPS=.000001
PLATE_SAMPLES=tuple(
    GRID_U*GRID_V + row*GRID_U + col
    for row in (1,2,3) for col in (1,3,5)
)


def closest_triangle(point,a,b,c):
    """Ericson closest point; face interior or boundary, 3D units metres."""
    ab=sub(b,a)
    ac=sub(c,a)
    ap=sub(point,a)
    d1,d2=dot(ab,ap),dot(ac,ap)
    if d1<=0 and d2<=0:
        return a
    bp=sub(point,b)
    d3,d4=dot(ab,bp),dot(ac,bp)
    if d3>=0 and d4<=d3:
        return b
    vc=d1*d4-d3*d2
    if vc<=0 and d1>=0 and d3<=0:
        v=d1/(d1-d3)
        return add(a,mul(ab,v))
    cp=sub(point,c)
    d5,d6=dot(ab,cp),dot(ac,cp)
    if d6>=0 and d5<=d6:
        return c
    vb=d5*d2-d1*d6
    if vb<=0 and d2>=0 and d6<=0:
        w=d2/(d2-d6)
        return add(a,mul(ac,w))
    va=d3*d6-d5*d4
    if va<=0 and d4-d3>=0 and d5-d6>=0:
        bc=sub(c,b)
        w=(d4-d3)/((d4-d3)+(d5-d6))
        return add(b,mul(bc,w))
    denom=va+vb+vc
    if abs(denom)<1e-14:
        raise ValueError('Degenerate triangle has no unique planar interior')
    v=vb/denom
    w=vc/denom
    return add(a,add(mul(ab,v),mul(ac,w)))


def _nail_entries(glb,points,joints,weights,skin,groups):
    doc=glb.doc
    extras=doc['extras']
    if (extras.get('nailPlatePrototypeVersion')!=933 or
        extras.get('distalNailBedVersion')!=932 or
        extras.get('approved') is not False or
        extras.get('enabled') is not False or
        len(doc['materials'])<2 or
        sum(m.get('name')==MATERIAL_NAME for m in doc['materials'])!=1):
        raise ValueError('Only quarantined v9.33 nail prototype is auditable')
    result={}
    for side in SIDES:
        for digit in DIGITS:
            label=f'{digit}_{side}'
            node=glb.by_name.get(PREFIX+label)
            distal=glb.by_name.get(f'{digit}_03_{side}')
            if node is None or distal is None or glb.parents.get(node)!=distal:
                raise ValueError('Invalid original distal nail ancestry: '+label)
            mesh_index=glb.nodes[node].get('mesh')
            if mesh_index is None or mesh_index<0 or mesh_index>=len(doc['meshes']):
                raise ValueError('Missing real nail mesh: '+label)
            plate=doc['meshes'][mesh_index]['primitives']
            if len(plate)!=1 or doc['materials'][plate[0]['material']]['name']!=MATERIAL_NAME:
                raise ValueError('Missing real nail material')
            attrs=plate[0]['attributes']
            if set(attrs)!={'POSITION','NORMAL','TEXCOORD_0'}:
                raise ValueError('Wrong nail vertex channels')
            positions=glb.accessor(attrs['POSITION'])
            uvs=glb.accessor(attrs['TEXCOORD_0'])
            ids=[int(v[0]) for v in glb.accessor(plate[0]['indices'])]
            if (len(positions)!=GRID_U*GRID_V*2 or
                len(uvs)!=len(positions) or
                len(ids)!=136*3 or
                any(i<0 or i>=len(positions) for i in ids) or
                any(len(uv)!=2 or not all(
                    -UV_EPS<=k<=1+UV_EPS and math.isfinite(k)
                    for k in uv) for uv in uvs)):
                raise ValueError('Unsafe nail plate geometry or UV0')
            underside=[positions[index] for index in PLATE_SAMPLES]
            if len(underside)!=9:
                raise ValueError('Incomplete rigid plate underside')
            # Restrict skin triangles to their REAL distal influence and then
            # to the geometrically nearest face centroids in the neutral pose.
            world_origin=glb.restpos[node]
            world_quat=glb.restrot[node]
            neutral=add(world_origin,qrot(world_quat,underside[4]))
            candidates=[]
            for face in groups[label]:
                centroid=mul(add(add(points[face[0]],points[face[1]]),
                                 points[face[2]]),1/3)
                distance=norm(sub(centroid,neutral))
                if distance<CANDIDATE_DISTANCE:
                    candidates.append((distance,face))
            candidates.sort(key=lambda r:r[0])
            chosen=[face for _,face in candidates[:MAX_FACES_PER_FINGER]]
            if len(chosen)<3:
                raise ValueError('Insufficient real skinned distal triangles')
            result[label]={
                'nailNode':node,'distalNode':distal,
                'underside':underside,'faces':chosen,
                'surfaceVertexIndices':{
                    v for face in chosen for v in face
                },
            }
    if len(result)!=10:
        raise ValueError('Expected exactly ten real nail attachments')
    return result


def review(raw,exercise):
    if exercise not in EXERCISES or len(raw)>MAX_MOBILE_BYTES:
        raise ValueError('Unsafe exercise or nail asset size')
    glb,p,j,w,morph,ibm,skin,groups=_read_refined(raw,exercise)
    selected=_nail_entries(glb,p,j,w,skin,groups)
    channels=_samplers(glb)
    needed=sorted(set().union(*[
        entry['surfaceVertexIndices'] for entry in selected.values()
    ]))
    vertex_data={
        i:(p[i],[shape[i] for shape in morph],w[i],j[i])
        for i in needed
    }
    originals={}
    for label,entry in selected.items():
        originals[label]={
            'selectedSkinnedTriangles':len(entry['faces']),
            'selectedSkinnedVertices':len(entry['surfaceVertexIndices']),
            'sampledNailVerticesPerPose':len(entry['underside']),
            'sampledPoses':FRAMES,'closestDistancesEvaluated':0,
            'possibleEmbeddedVertexSamples':0,
            'possiblyDetachedVertexSamples':0,
            'minimumUnsignedDistanceMeters':float('inf'),
            'largestObservedSeparationMeters':0.,
            'mostNegativeOrientedDistanceMeters':float('inf'),
            'firstPossibleEmbedding':None,
            'firstPossibleDetachment':None,
        }
    # Cache each morphed/skinned vertex only once per animation pose, across
    # both hands. The plate itself is rigid and inherits distal bone motion.
    for frame in range(FRAMES):
        t=frame/FPS
        world,rotations,activation=_sample(glb,channels,t)
        posed={}
        for i,(pos,deltas,ww,jj) in vertex_data.items():
            posed[i]=_skin_vertex(pos,deltas,ww,jj,ibm,
                                   world,rotations,skin,activation)
        for label,entry in selected.items():
            item=originals[label]
            nail_origin=world[entry['nailNode']]
            nail_rotation=rotations[entry['nailNode']]
            bodyfaces=[]
            for indices in entry['faces']:
                a,b,c=(posed[i] for i in indices)
                face_normal=cross(sub(b,a),sub(c,a))
                face_length=norm(face_normal)
                if face_length<1e-11:
                    # Degenerate deformed triangles do not supply a normal;
                    # they are unsafe to classify as separated.
                    raise ValueError('Collapsed animated distal triangle '+label)
                bodyfaces.append((a,b,c,mul(face_normal,1/face_length)))
            for local in entry['underside']:
                point=add(nail_origin,qrot(nail_rotation,local))
                best_distance=float('inf')
                best_oriented=float('inf')
                for a,b,c,normal in bodyfaces:
                    nearest=closest_triangle(point,a,b,c)
                    vector=sub(point,nearest)
                    distance=norm(vector)
                    if distance<best_distance:
                        best_distance=distance
                        best_oriented=dot(vector,normal)
                if not math.isfinite(best_distance):
                    raise ValueError('Invalid animated nail-skin distance')
                item['closestDistancesEvaluated']+=1
                item['minimumUnsignedDistanceMeters']=min(
                    best_distance,item['minimumUnsignedDistanceMeters'])
                item['largestObservedSeparationMeters']=max(
                    best_distance,item['largestObservedSeparationMeters'])
                item['mostNegativeOrientedDistanceMeters']=min(
                    best_oriented,item['mostNegativeOrientedDistanceMeters'])
                if (best_oriented<-POSSIBLE_EMBED_DEPTH and
                        best_distance<MAX_SAMPLE_DISTANCE):
                    item['possibleEmbeddedVertexSamples']+=1
                    if item['firstPossibleEmbedding'] is None:
                        item['firstPossibleEmbedding']={
                            'frame':frame,'nailToSkinDistanceMeters':
                            round(best_distance,8),
                            'orientedMeters':round(best_oriented,8),
                        }
                if best_distance>MAX_SAMPLE_DISTANCE:
                    item['possiblyDetachedVertexSamples']+=1
                    if item['firstPossibleDetachment'] is None:
                        item['firstPossibleDetachment']={
                            'frame':frame,'nailToSkinDistanceMeters':
                            round(best_distance,8),
                        }
    for item in originals.values():
        if item['closestDistancesEvaluated']!=FRAMES*9:
            raise ValueError('Incomplete 60Hz nail proximity review')
        for field in (
            'minimumUnsignedDistanceMeters',
            'largestObservedSeparationMeters',
            'mostNegativeOrientedDistanceMeters',
        ):
            item[field]=round(item[field],8)
        item['hasUnresolvedGeometryRisk']=bool(
            item['possibleEmbeddedVertexSamples'] or
            item['possiblyDetachedVertexSamples'])
    return {
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'pilotNailPlates':len(selected),
        'sampleRateHz':FPS,'sampledFrames':FRAMES,
        'nailSurfaceSamples':FRAMES*9*len(selected),
        'selectedBodyVertices':len(needed),
        'selectedTriangleSamplesPerFrame':sum(
            len(x['faces']) for x in selected.values()),
        'possibleEmbeddedVertexSamples':sum(
            x['possibleEmbeddedVertexSamples'] for x in originals.values()),
        'possiblyDetachedVertexSamples':sum(
            x['possiblyDetachedVertexSamples'] for x in originals.values()),
        'allSampledSurfacesPerfect':False,
        'expertNailAnatomyReviewComplete':False,
        'signReliableForWatertightSolid':False,
        'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,
        'reviewRequired':True,
        'approved':False,'enabled':False,
        'digits':originals,
    }


def build(source_dir,output_dir):
    source_dir,output_dir=Path(source_dir),Path(output_dir)
    output_dir.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        raw=(source_dir/(exercise+'_v933_rig_nail_plates_mobile_qa.glb')
             ).read_bytes()
        reports.append(review(raw,exercise))
    result={
        'schema':'stk_v934_nail_plate_to_skinned_body_triangle_proximity_qa',
        'catalogCount':229,'pilotCount':3,
        'nailsAudited':sum(x['pilotNailPlates'] for x in reports),
        'totalSurfaceProbeSamples':sum(
            x['nailSurfaceSamples'] for x in reports),
        'allObservationsRequireExpertReview':True,
        'noContinuousTriangleCCD':True,'noSelfCollisionCertification':True,
        'productionReady':False,'approved':False,'enabled':False,
        'pilots':reports,
    }
    (output_dir/'nail_plate_skin_proximity_v934_report.json').write_text(
        json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--input',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    args=cli.parse_args()
    data=build(args.input,args.output)
    print(json.dumps({
        'schema':data['schema'],'pilots':data['pilotCount'],
        'reviewRequired':True,'approved':False},indent=2))
