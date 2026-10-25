#!/usr/bin/env python3
"""STK Haven v9.39: ten UV-mapped curved proximal nail folds (cuticle), QA only.

Build a thin *closed* 3D eponychium-like fold for each original 5x3
nail plate mesh. The child mesh inherits that plate's bone-local pose,
including the accepted v9.37/v9.38 3D thumb offsets. Use original
top-row nail geometry/normals to produce a bounded tapered skin fold.
This is real triangulated geometry, not a transparent decal or texture.
It DOES NOT create watertight continuous contact with skinned hand skin,
clinically accurate nail anatomy, final materials, or certified motion.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, EXERCISES, add, sub, mul, unit, norm
from build_rig_nail_plates_v933 import PREFIX, MATERIAL_NAME, append_uv
from audit_finger_contact_bounds_v923 import _read_refined
from animate_hand_grip_v917 import DIGITS, SIDES
from exercise_surface_collision_v911 import _sample,_samplers
from refine_fingertip_topology_v922 import MAX_MOBILE_BYTES

FOLD_MATERIAL='STK_CUTICLE_SKIN_QA'
FOLD_PREFIX='STK_CUTICLE_FOLD_'
COLUMNS=5
ROWS=4
VERTICES=40
TRIANGLES=76
MAX_FOLD_PROJECTION_METERS=.004
MAX_FOLD_VERTEX_GAP_METERS=.0028


def _fold_geometry(plate,normal_rows):
    if (len(plate)!=30 or len(normal_rows)!=30 or
            any(len(v)!=3 or not all(math.isfinite(k) for k in v)
                for v in (*plate,*normal_rows))):
        raise ValueError('Invalid 5x3 source nail top and dorsal normals')
    original_base=plate[:5]
    original_inside=plate[5:10]
    vertices=[]
    normals=[]
    uv=[]
    for below in (False,True):
        for j in range(ROWS):
            v=j/(ROWS-1)
            # Visible proximal fold overlaps the keratin plate by 0.75 mm,
            # and gently curves towards the original skin surface.
            axial=-.13+.28*v
            for i in range(COLUMNS):
                u=i/(COLUMNS-1)
                p=original_base[i]
                into=sub(original_inside[i],p)
                if norm(into)<.0002:
                    raise ValueError('Collapsed original nail longitudinal axis')
                n=unit(normal_rows[i])
                # Raised lunula-side margin, thinner on lateral nail folds.
                arch=.00032*math.sin(math.pi*u)*math.sin(math.pi*v)
                edge=.00009*(1.-abs(2*u-1.))
                thickness=-.00015 if below else 0.
                point=add(p,add(mul(into,axial),
                              mul(n,arch+edge+thickness)))
                if norm(sub(point,p))>MAX_FOLD_PROJECTION_METERS:
                    raise ValueError('Cuticle extends beyond plausible nail base')
                vertices.append(point)
                normals.append(mul(n,-1. if below else 1.))
                uv.append((u,v))
    face=[]
    face_offset=COLUMNS*ROWS
    for j in range(ROWS-1):
        for i in range(COLUMNS-1):
            a=j*COLUMNS+i
            c=a+COLUMNS
            face.extend((a,a+1,c,a+1,c+1,c))
            face.extend((face_offset+a,face_offset+c,face_offset+a+1,
                         face_offset+a+1,face_offset+c,face_offset+c+1))
    perimeter=list(range(COLUMNS))
    perimeter.extend(j*COLUMNS+COLUMNS-1 for j in range(1,ROWS))
    perimeter.extend((ROWS-1)*COLUMNS+i
                     for i in range(COLUMNS-2,-1,-1))
    perimeter.extend(j*COLUMNS for j in range(ROWS-2,0,-1))
    for k,a in enumerate(perimeter):
        b=perimeter[(k+1)%len(perimeter)]
        face.extend((a,face_offset+a,b,b,face_offset+a,face_offset+b))
    if (len(vertices)!=VERTICES or len(face)//3!=TRIANGLES or
            len(uv)!=VERTICES or
            any(i<0 or i>=VERTICES for i in face)):
        raise ValueError('Invalid sealed eponychial fold geometry')
    # Conservative candidate bound against the nearest source nail top
    # vertex. This is NOT a full surface-to-skin collision test.
    largest=max(min(norm(sub(x,q)) for q in original_base) for x in vertices)
    if largest>MAX_FOLD_VERTEX_GAP_METERS:
        raise ValueError('Fold detached from its source plate')
    return vertices,normals,uv,face,round(largest,8)


def attach(raw,exercise):
    if exercise not in EXERCISES or len(raw)>MAX_MOBILE_BYTES:
        raise ValueError('Unsupported or oversized experimental GLB')
    glb,p,j,w,morphs,ibm,skin,_=_read_refined(raw,exercise)
    doc=glb.doc
    extras=doc['extras']
    if (extras.get('leftThumbPlateContourFitVersion')!=938 or
            extras.get('thumbNail3dFitVersion')!=937 or
            extras.get('nailLodPrototypeVersion')!=936 or
            extras.get('cuticleFoldGeometryVersion') is not None or
            extras.get('approved') is not False or
            extras.get('enabled') is not False or
            len(morphs)!=8 or len(doc['skins'][0]['joints'])!=55):
        raise ValueError('Require inactive v9.38 55-joint master pilot')
    baseline={k:copy.deepcopy(doc[k]) for k in
              ('skins','animations','nodes','meshes','materials')}
    keratin=[i for i,m in enumerate(doc['materials'])
             if m.get('name')==MATERIAL_NAME]
    if len(keratin)!=1:
        raise ValueError('Missing approved QA nail-plate prototype identity')
    doc['materials'].append({
        'name':FOLD_MATERIAL,
        'pbrMetallicRoughness':{
            'baseColorFactor':[.70,.51,.47,1.],
            'metallicFactor':0.,
            'roughnessFactor':.74,
        },
        'doubleSided':True,
        'extras':{
            'candidateOnly':True,'artistReviewed':False,
            'continuousSkinAttachmentCertified':False
        },
    })
    material_index=len(doc['materials'])-1
    original_mesh_count=len(doc['meshes'])
    original_nodes=len(doc['nodes'])
    rows=[]
    seen=set()
    for side in SIDES:
        for digit in DIGITS:
            suffix=digit+'_'+side
            parent=glb.by_name.get(PREFIX+suffix)
            if parent is None or parent in seen:
                raise ValueError('Missing ten original bone-attached nail nodes')
            seen.add(parent)
            base_mesh=doc['meshes'][doc['nodes'][parent]['mesh']]
            if len(base_mesh['primitives'])!=1:
                raise ValueError('Nail plate must have one rigid primitive')
            primitive=base_mesh['primitives'][0]
            if doc['materials'][primitive['material']]['name']!=MATERIAL_NAME:
                raise ValueError('Nail plate material changed')
            attrs=primitive['attributes']
            if set(attrs)!={'POSITION','NORMAL','TEXCOORD_0'}:
                raise ValueError('No original real UV nail mesh')
            positions=glb.accessor(attrs['POSITION'])
            normals=glb.accessor(attrs['NORMAL'])
            vertices,fold_normals,uv,indices,gap=(
                _fold_geometry(positions,normals))
            pos=glb.append(vertices,3,'POSITION',target=34962)
            normal=glb.append(fold_normals,3,'NORMAL',target=34962)
            tex=append_uv(glb,uv)
            idx=glb.append([(i,) for i in indices],1,'INDICES',
                           component=5123,target=34963)
            doc['accessors'][pos]['min']=[
                min(x[k] for x in vertices) for k in range(3)]
            doc['accessors'][pos]['max']=[
                max(x[k] for x in vertices) for k in range(3)]
            mesh_index=len(doc['meshes'])
            name=FOLD_PREFIX+suffix
            doc['meshes'].append({
                'name':name,
                'primitives':[{
                    'attributes':{'POSITION':pos,'NORMAL':normal,
                                  'TEXCOORD_0':tex},
                    'indices':idx,'material':material_index,'mode':4,
                }],
                'extras':{
                    'candidateOnly':True,
                    'derivesFromRealNailPlate':base_mesh.get('name'),
                },
            })
            node_index=len(doc['nodes'])
            doc['nodes'].append({
                'name':name,'mesh':mesh_index,
                'translation':[0.,0.,0.],'rotation':[0.,0.,0.,1.],
                'extras':{'approved':False,'enabled':False},
            })
            doc['nodes'][parent].setdefault('children',[]).append(node_index)
            rows.append({
                'digit':digit,'side':side,'parentNailNode':parent,
                'cuticleNode':node_index,'mesh':mesh_index,
                'material':FOLD_MATERIAL,'vertices':VERTICES,
                'triangles':TRIANGLES,
                'maxFoldToNailVertexDistanceMeters':gap,
                'UV0Complete':True,'sealedMesh':True,
            })
    if len(rows)!=10 or len(doc['nodes'])!=original_nodes+10 or (
            len(doc['meshes'])!=original_mesh_count+10) or (
            len(doc['nodes'])>128):
        raise ValueError('Excess or missing ten eponychial folds')
    for key in ('skins','animations'):
        if doc[key]!=baseline[key]:
            raise ValueError('Cuticle overlay changed original skin or motion')
    if doc['meshes'][:original_mesh_count]!=baseline['meshes'] or (
            doc['materials'][:-1]!=baseline['materials']):
        raise ValueError('Cuticle overlay changed original plate/equipment')
    parents={row['parentNailNode']:row['cuticleNode'] for row in rows}
    if len(parents)!=10:
        raise ValueError('Cuticle parent cannot be shared across nails')
    for k,n in enumerate(baseline['nodes']):
        current=copy.deepcopy(doc['nodes'][k])
        if k in parents:
            assert current['children'][-1]==parents[k]
            current['children'].pop()
            if not current['children']:
                del current['children']
        if current!=n:
            raise ValueError('Base skeleton or nail pose unexpectedly changed')
    extras.update({
        'cuticleFoldGeometryVersion':939,
        'sourceAngledThumbSha256':hashlib.sha256(raw).hexdigest(),
        'cuticleFoldMeshCount':10,
        'cuticleFoldTriangleCount':760,
        'cuticleFoldUV0Sets':10,
        'eponychiumArtistVerified':False,
        'cuticleSkinDynamicContactCertified':False,
        'nailAndCuticleSelfCollisionCertified':False,
        'continuousCollisionCertified':False,
        'physicalDeviceBenchmarked':False,
        'approved':False,'enabled':False,
    })
    output=glb.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Ten-cuticle QA GLB exceeds 1400 KiB')
    again=GLB(output,expected_sha=None)
    channels=_samplers(again)
    for seconds in (0.,1.,2.,3.,4.):
        world,_,_=_sample(again,channels,seconds)
        for row in rows:
            if math.dist(world[row['parentNailNode']],
                         world[row['cuticleNode']])>1e-8:
                raise ValueError('Eponychium failed real animation inheritance')
    return output,{
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'cuticleFoldMeshes':len(rows),
        'cuticleTrianglesAdded':sum(r['triangles'] for r in rows),
        'cuticleVerticesAdded':sum(r['vertices'] for r in rows),
        'UVSetsAdded':len(rows),'rigJoints':55,'morphTargets':8,
        'maxSeparationToOriginalNailMeters':max(
            r['maxFoldToNailVertexDistanceMeters'] for r in rows),
        'animationInheritedFromNailNodes':True,
        'continuousSkinContactCertified':False,
        'professionalCuticlesComplete':False,
        'physicalDeviceBenchmarked':False,
        'bytes':len(output),'approved':False,'enabled':False,
        'folds':rows,
    }


def build(source,output):
    source,output=Path(source),Path(output)
    output.mkdir(parents=True,exist_ok=True)
    records=[]
    for exercise in EXERCISES:
        raw=(source/(exercise+'_v938_left_thumb_angle_mobile_qa.glb')
             ).read_bytes()
        out,review=attach(raw,exercise)
        (output/(exercise+'_v939_cuticle_fold_mobile_qa.glb')
         ).write_bytes(out)
        records.append(review)
    overall={
        'schema':'stk_v939_real_sealed_nail_cuticle_uv_qa',
        'catalogCount':229,'pilotCount':3,
        'cuticlesPerPilot':10,
        'totalExperimentalCuticleMeshes':30,
        'oldAnimationPreserved':True,
        'physicalDeviceBenchmarked':False,
        'continuousSkinAttachmentCertified':False,
        'professionalAnatomyReady':False,
        'productionReady':False,'approved':False,'enabled':False,
        'pilots':records,
    }
    (output/'cuticle_folds_v939_report.json').write_text(
        json.dumps(overall,indent=2)+'\n',encoding='utf8')
    return overall


if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('--input',required=True,type=Path)
    ap.add_argument('--output',required=True,type=Path)
    args=ap.parse_args()
    report=build(args.input,args.output)
    print(json.dumps({'schema':report['schema'],'pilots':3,'enabled':False}))
