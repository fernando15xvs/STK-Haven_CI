#!/usr/bin/env python3
"""STK Haven v9.36: reduced-triangle UV nail plates, review-only mobile LOD.

From v9.35: replace *only* the ten rigid nail mesh primitives, preserving
body, 55-joint rig, animation, skin, eight morphs and all equipment. Decimate
a known 7x5 double-sided nail grid to 5x3, retain sealed side walls,
UV0 and material. Verify exact old-surface vertices against new triangles
with a per-vertex closest-point distance bound. New geometry is not
contact-certified; old v9.35 pilot remains the collision-audit baseline.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from audit_finger_contact_bounds_v923 import _read_refined
from build_rig_nail_plates_v933 import MATERIAL_NAME, append_uv
from nail_plate_skin_proximity_v934 import closest_triangle
from retarget_cc0_glb import GLB,EXERCISES,norm,sub
from refine_fingertip_topology_v922 import MAX_MOBILE_BYTES

ROW_SOURCE=(0,2,4)
COLUMN_SOURCE=(0,1,3,5,6)
ORIGINAL_WIDTH=7
ORIGINAL_HEIGHT=5
LOD_WIDTH=5
LOD_HEIGHT=3
LOD_VERTICES=30
LOD_TRIANGLES=56
HIGH_TRIANGLES=136
MAX_VERTEX_TO_SURFACE_ERROR_METERS=.00055
MATERIAL_ROUGHNESS=.46


def _lod_indices():
    """Sealed two-layer 5x3 nail plate with identical source winding."""
    w,h=LOD_WIDTH,LOD_HEIGHT
    layer=w*h
    out=[]
    for v in range(h-1):
        for u in range(w-1):
            a=v*w+u
            c=a+w
            out.extend((a,a+1,c,a+1,c+1,c))
            out.extend((layer+a,layer+c,layer+a+1,
                        layer+a+1,layer+c,layer+c+1))
    perimeter=list(range(w))
    perimeter.extend(v*w+w-1 for v in range(1,h))
    perimeter.extend((h-1)*w+u for u in range(w-2,-1,-1))
    perimeter.extend(v*w for v in range(h-2,0,-1))
    for i,a in enumerate(perimeter):
        b=perimeter[(i+1)%len(perimeter)]
        out.extend((a,layer+a,b,b,layer+a,layer+b))
    if len(out)//3!=LOD_TRIANGLES or not all(
            0<=v<LOD_VERTICES for v in out):
        raise ValueError('Malformed conforming low-poly nail topology')
    return out


def _subsample(source):
    if len(source)!=70:
        raise ValueError('Expected source 70-vertex two-layer nail grid')
    original_layer=ORIGINAL_WIDTH*ORIGINAL_HEIGHT
    return [
        tuple(source[layer*original_layer+row*ORIGINAL_WIDTH+col])
        for layer in (0,1)
        for row in ROW_SOURCE
        for col in COLUMN_SOURCE
    ]


def _closest_bound(full, reduced, indices):
    """One-sided sampled vertex-to-triangle bound, NOT Hausdorff/CCD."""
    faces=[
        (reduced[indices[k]],reduced[indices[k+1]],
         reduced[indices[k+2]])
        for k in range(0,len(indices),3)
    ]
    worst=0.
    for p in full:
        error=min(norm(sub(p,closest_triangle(p,*tri))) for tri in faces)
        if not math.isfinite(error):
            raise ValueError('Nonfinite nail low-poly surface bound')
        worst=max(worst,error)
    return worst


def reduce_one(raw,exercise):
    glb,body,joints,weights,morph,ibm,skin,_=_read_refined(
        raw,exercise)
    doc=glb.doc
    extras=doc['extras']
    if (extras.get('nailContactOffsetOptimizerVersion')!=935 or
            extras.get('nailPlatePrototypeVersion')!=933 or
            extras.get('nailLodPrototypeVersion') is not None or
            extras.get('approved') is not False or
            extras.get('enabled') is not False or
            len(morph)!=8):
        raise ValueError('Require original disabled v9.35 mobile nail clip')
    preserved={k:copy.deepcopy(doc[k]) for k in
               ('nodes','skins','animations')}
    body_mesh=copy.deepcopy(doc['meshes'][0])
    all_materials=copy.deepcopy(doc['materials'])
    plate_materials=[i for i,mat in enumerate(doc['materials'])
                     if mat.get('name')==MATERIAL_NAME]
    if len(plate_materials)!=1:
        raise ValueError('Exactly one experimental PBR nail material required')
    nail_mat_id=plate_materials[0]
    nail_mat=doc['materials'][nail_mat_id]
    if nail_mat.get('pbrMetallicRoughness',{}).get('metallicFactor')!=0:
        raise ValueError('Unsupported metallic nail test material')
    nail_mat['pbrMetallicRoughness']['roughnessFactor']=MATERIAL_ROUGHNESS
    # Optical approximation for experimental viewer, not a keratin texture.
    nail_mat['pbrMetallicRoughness']['baseColorFactor']=[.81,.66,.61,1.]
    ids=_lod_indices()
    modified=[]
    max_err=0.
    total_before=total_after=0
    for mesh_index,mesh in enumerate(doc['meshes']):
        if not mesh.get('name','').startswith('STK_NAIL_PLATE_'):
            continue
        if len(mesh['primitives'])!=1:
            raise ValueError('Nail LOD only supports isolated mesh primitives')
        primitive=mesh['primitives'][0]
        attrs=primitive['attributes']
        if (set(attrs)!={'POSITION','NORMAL','TEXCOORD_0'} or
                primitive['material']!=nail_mat_id):
            raise ValueError('Unexpected rigid nail primitive')
        old_position=glb.accessor(attrs['POSITION'])
        old_normals=glb.accessor(attrs['NORMAL'])
        old_uv=glb.accessor(attrs['TEXCOORD_0'])
        old_indices=glb.accessor(primitive['indices'])
        if (len(old_indices)//3!=HIGH_TRIANGLES or
                len(old_position)!=70 or
                len(old_normals)!=70 or
                len(old_uv)!=70):
            raise ValueError('Unrecognized source high-resolution nail plate')
        small_position=_subsample(old_position)
        small_normals=_subsample(old_normals)
        small_uv=_subsample(old_uv)
        if not all(all(math.isfinite(x) for x in row)
                   for row in (*small_position,*small_normals,*small_uv)):
            raise ValueError('Nonfinite nail attributes')
        if any(not 0<=k<=1 for row in small_uv for k in row):
            raise ValueError('Invalid reduced nail UV coordinates')
        error=_closest_bound(old_position,small_position,ids)
        if error>MAX_VERTEX_TO_SURFACE_ERROR_METERS:
            raise ValueError('Nail LOD differs >0.55 mm from high-res source')
        pos=glb.append(small_position,3,'POSITION',target=34962)
        normal=glb.append(small_normals,3,'NORMAL',target=34962)
        uv=append_uv(glb,small_uv)
        face=glb.append([(i,) for i in ids],1,'INDICES',
                        component=5123,target=34963)
        doc['accessors'][pos]['min']=[
            min(p[k] for p in small_position) for k in range(3)]
        doc['accessors'][pos]['max']=[
            max(p[k] for p in small_position) for k in range(3)]
        primitive['attributes']={
            'POSITION':pos,'NORMAL':normal,'TEXCOORD_0':uv}
        primitive['indices']=face
        max_err=max(max_err,error)
        total_before+=HIGH_TRIANGLES
        total_after+=LOD_TRIANGLES
        modified.append({
            'name':mesh['name'],'meshIndex':mesh_index,
            'sourceTriangles':HIGH_TRIANGLES,
            'lodTriangles':LOD_TRIANGLES,
            'sourceVertices':70,'lodVertices':LOD_VERTICES,
            'maxOriginalVertexToLodSurfaceMeters':round(error,8),
            'uv0PreservedBySubset':True,
            'sealedTwoSidedWalls':True,
        })
    if len(modified)!=10 or total_before!=1360 or total_after!=560:
        raise ValueError('Failed to convert exactly ten animated nail plates')
    if (doc['nodes']!=preserved['nodes'] or
            doc['skins']!=preserved['skins'] or
            doc['animations']!=preserved['animations'] or
            doc['meshes'][0]!=body_mesh or
            any(mat!=prior for i,(mat,prior) in enumerate(
                zip(doc['materials'],all_materials)) if i!=nail_mat_id)):
        raise ValueError('LOD operation touched body, movement or other materials')
    extras.update({
        'nailLodPrototypeVersion':936,
        'nailLodSourceSha256':hashlib.sha256(raw).hexdigest(),
        'nailLodUvPreserved':True,
        'nailLodApproximateSurfaceBoundMeters':round(max_err,8),
        'nailLodOriginalTriangleCount':1360,
        'nailLodTriangleCount':560,
        'nailLodGpuBenchmarkVerified':False,
        'nailLodPhysicalDeviceVerified':False,
        'nailLodContinuousCollisionCertified':False,
        'nailLodCuticlesComplete':False,
        'approved':False,'enabled':False,
    })
    output=glb.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Prototype LOD exceeds 1400 KiB mobile GLB limit')
    verify=GLB(output,expected_sha=None)
    if verify.doc['nodes']!=preserved['nodes'] or (
        verify.doc['animations']!=preserved['animations']):
        raise ValueError('Exported low-poly nails lost rig motion')
    for entry in modified:
        p=verify.doc['meshes'][entry['meshIndex']]['primitives'][0]
        attr=p['attributes']
        if (len(verify.accessor(attr['POSITION']))!=LOD_VERTICES or
                len(verify.accessor(attr['NORMAL']))!=LOD_VERTICES or
                len(verify.accessor(attr['TEXCOORD_0']))!=LOD_VERTICES or
                len(verify.accessor(p['indices']))!=LOD_TRIANGLES*3):
            raise ValueError('Exported GLB nail LOD round-trip failed')
    return output,{
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'rigJoints':55,'morphTargets':8,
        'originalNailTriangles':total_before,
        'lodNailTriangles':total_after,
        'nailTriangleReductionPercent':round(
            100*(total_before-total_after)/total_before,2),
        'maximumSourceVertexErrorMeters':round(max_err,8),
        'reducedNailMeshCount':len(modified),
        'sampledContactRetestCompleted':False,
        'newGpuBenchmarkCompleted':False,
        'materialExperimentRoughness':MATERIAL_ROUGHNESS,
        'professionalCuticlesComplete':False,
        'physicalDeviceVerified':False,
        'assetBytes':len(output),
        'bodyRigAndAnimationUnchanged':True,
        'approved':False,'enabled':False,
        'plates':modified,
    }


def build(input_dir,output_dir):
    input_dir,output_dir=Path(input_dir),Path(output_dir)
    output_dir.mkdir(parents=True,exist_ok=True)
    items=[]
    for exercise in EXERCISES:
        raw=(input_dir/(exercise+
            '_v935_nail_contact_offset_mobile_qa.glb')).read_bytes()
        data,info=reduce_one(raw,exercise)
        (output_dir/(exercise+'_v936_nail_lod_mobile_qa.glb')
         ).write_bytes(data)
        items.append(info)
    result={
        'schema':'stk_v936_uv_nail_rigid_mesh_medium_lod_qa',
        'catalogCount':229,'pilotCount':3,
        'nailTrianglesBeforePerPilot':1360,
        'nailTrianglesAfterPerPilot':560,
        'mobileHardwareBenchmarkComplete':False,
        'fullCuticleGeometryComplete':False,
        'bodyRigAnimationIntact':True,
        'continuousContactCertified':False,
        'productionReady':False,
        'approved':False,'enabled':False,
        'pilots':items,
    }
    (output_dir/'nail_lod_v936_report.json').write_text(
        json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--input',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    args=cli.parse_args()
    data=build(args.input,args.output)
    print(json.dumps({
        'schema':data['schema'],
        'pilotCount':data['pilotCount'],
        'approved':False},indent=2))
