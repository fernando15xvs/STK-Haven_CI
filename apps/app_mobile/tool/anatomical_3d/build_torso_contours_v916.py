#!/usr/bin/env python3
"""STK Haven v9.16: disabled torso anatomy authoring and mobile normal transfer.

Adds three clearly distinguished *approximate* torso contour fields for
rectus abdominis, external obliques, and serratus anterior, each bilateral.
Works only on hash-pinned CC0 55-joint v9.15 high/low anatomy and 3 pilots.
No new catalog assets, no added mobile triangles/bytes, no claim of anatomical
certification. The first 4,727 high-poly vertices match low-poly vertex IDs.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB
from build_master_surface_v6 import replace_accessor
from build_master_surface_v2 import sub
from build_master_anatomy_v8 import EXERCISE_IDS
from bake_master_detail_v915 import (
    _assert_source, _atlas, _new_normals, _oriented, dot, length, unit,
    LOW_VERTICES, HIGH_VERTICES, MAX_HIGH_BYTES, MAX_MASTER_LOD_BYTES,
    MAX_EXERCISE_LOD_BYTES,
)

# Coordinates are fixed to the verified CC0 rig's meter-scale Y-up neutral
# pose. Anatomical names are ARTISTIC guidance, not anatomist-verified masks.
ARTIST_GROUPS = ('rectus_abdominis', 'obliquus_externus_abdominis',
                 'serratus_anterior')
MAX_TORSO_RELIEF_METERS = .00185
MAX_NORMAL_DEGREES = 10.0
MAX_BAKE_POSITION_MISMATCH = .0032
MIN_HIGH_HITS = {'rectus_abdominis':100,
                 'obliquus_externus_abdominis':150,
                 'serratus_anterior':150}
MIN_LOW_CHANGED = 75


def smooth(value):
    t=max(0.,min(1.,value))
    return t*t*(3-2*t)


def window(value,lo,hi,fade):
    if lo>=hi or fade<=0:
        raise ValueError('Invalid anatomical window')
    return smooth((value-lo)/fade)*smooth((hi-value)/fade)


def contour_fields(point,normal):
    """Three soft bilateral torso fields; no inference about clinical muscle."""
    x,y,z=map(float,point)
    side=abs(x)
    nz=unit(normal)[2]
    front=smooth((z-.016)/.075)*smooth((nz+.02)/.40)
    # Three paired transverse bellies below pectoralis, retaining central
    # linea-alba spacing. Bounding is purposely conservative.
    rectus=(window(side,.012,.098,.025)*
            window(y,.95,1.217,.026)*
            smooth((z-.080)/.065)*
            smooth((nz-.20)/.50))
    segments=sum(math.exp(-.5*((y-c)/.021)**2)
                 for c in (1.003,1.078,1.151))
    rectus*=min(1.,segments)*(.65+.35*smooth((side-.019)/.020))
    # Side abdomen has oblique diagonals instead of a uniform belly ridge.
    oblique=(window(side,.086,.190,.025)*
             window(y,.957,1.184,.030)*front*
             (.74+.26*math.cos((y-.79*side)*80.)**2))
    # Four short angled "digitations" on the anterolateral ribcage.
    serratus=(window(side,.125,.255,.028)*
              window(y,1.135,1.36,.030)*front*
              sum(math.exp(-.5*((y-c-.4*(side-.16))/.012)**2)
                  for c in (1.170,1.217,1.264,1.311)))
    return {'rectus_abdominis':rectus,
            'obliquus_externus_abdominis':oblique,
            'serratus_anterior':serratus}


def sculpt_high(points,normals,faces):
    if len(points)!=HIGH_VERTICES or len(normals)!=HIGH_VERTICES:
        raise ValueError('Expected v9.15 high-poly model')
    weights={k:[] for k in ARTIST_GROUPS}
    amplitudes=[]
    for point,normal in zip(points,normals):
        contour=contour_fields(point,normal)
        for name in ARTIST_GROUPS:
            weights[name].append(contour[name])
        amount=(.00160*contour['rectus_abdominis']+
                .00100*contour['obliquus_externus_abdominis']+
                .00120*contour['serratus_anterior'])
        amplitudes.append(min(MAX_TORSO_RELIEF_METERS,amount))
    affected={name:sum(w>.05 for w in weights[name])
              for name in ARTIST_GROUPS}
    for name,count in affected.items():
        if count<MIN_HIGH_HITS[name]:
            raise ValueError('Missing anatomical group '+name)
    if sum(a>.00002 for a in amplitudes)<450:
        raise ValueError('Too few high-resolution torso vertices affected')
    new_points=None
    factor=0.
    for factor in (1.,.65,.4,.2,.1):
        trial=[tuple(p[k]+n[k]*amplitudes[i]*factor for k in range(3))
               for i,(p,n) in enumerate(zip(points,normals))]
        if _oriented(points,trial,faces)==0:
            new_points=trial
            break
    if new_points is None:
        raise ValueError('Torso contour inverted faces at every safe scale')
    refined=_new_normals(new_points,normals,faces)
    maximum=max(math.dist(a,b) for a,b in zip(points,new_points))
    if maximum>MAX_TORSO_RELIEF_METERS+.000001:
        raise ValueError('Torso sculpt exceeds displacement budget')
    return new_points,refined,weights,{
        'anatomicalGroups':list(ARTIST_GROUPS),
        'highVerticesByContour':affected,
        'modifiedHighVertices':sum(math.dist(a,b)>.00002
                                  for a,b in zip(points,new_points)),
        'maximumReliefMeters':round(maximum,8),
        'foldAvoidanceFactor':factor,
        'triangleFlips':0,
        'artisticContoursNotClinical':True,
    }


def normal_transfer(low_points,low_normals,old_high,high_normals,weights):
    if (len(low_points)!=LOW_VERTICES or len(low_normals)!=LOW_VERTICES or
        len(old_high)!=HIGH_VERTICES or len(high_normals)!=HIGH_VERTICES):
        raise ValueError('Incorrect LOD mapping')
    out=[]
    max_angle=0.
    changed=0
    per_group={name:0 for name in ARTIST_GROUPS}
    for i,(p,n) in enumerate(zip(low_points,low_normals)):
        if math.dist(p,old_high[i])>MAX_BAKE_POSITION_MISMATCH:
            raise ValueError('Mobile vertex is not mapped to original high LOD')
        value=max(weights[g][i] for g in ARTIST_GROUPS)
        old=unit(n)
        high=unit(high_normals[i])
        if dot(old,high)<0:
            high=tuple(-v for v in high)
        rad=math.acos(max(-1.,min(1.,dot(old,high))))
        alpha=.62*smooth(value/.45)*min(1.,math.radians(
                MAX_NORMAL_DEGREES)/max(rad,1e-8))
        new=unit(tuple((1-alpha)*old[k]+alpha*high[k]
                       for k in range(3)))
        angle=math.degrees(math.acos(max(-1.,min(1.,dot(old,new)))))
        if angle>MAX_NORMAL_DEGREES+.015:
            raise ValueError('Mobile normal transfer rotates too far')
        max_angle=max(angle,max_angle)
        if angle>.035:
            changed+=1
            for name in ARTIST_GROUPS:
                if weights[name][i]>.05:
                    per_group[name]+=1
        out.append(new)
    if changed<MIN_LOW_CHANGED or any(n<12 for n in per_group.values()):
        raise ValueError('Insufficient torso shading transferred to mobile')
    return out,{'changedMobileNormals':changed,
                'maxNormalDeviationDegrees':round(max_angle,6),
                'changedNormalsByGroup':per_group,
                'mobileVerticesAdded':0,'mobilePositionChanges':0}


def _validate_input(high,low,exercise=None):
    hparts,hattr,hpos,hnorm=_assert_source(high,True,exercise)
    lparts,lattr,lpos,lnorm=_assert_source(low,False,exercise)
    for doc,is_high in ((high.doc,True),(low.doc,False)):
        extra=doc.get('extras',{})
        if (extra.get('anatomyShadingVersion')!=915 or
            extra.get('highResDetailAuthoring')!=is_high or
            extra.get('approved') is not False or
            extra.get('enabled') is not False):
            raise ValueError('Expected disabled v9.15 anatomy sources')
    if len(hparts)!=len(lparts) or len(hparts)!=12:
        raise ValueError('Region atlas mismatch')
    return hattr,hpos,hnorm,lattr,lpos,lnorm


def build(high_master,low_master,high_exercises,low_exercises,output):
    """Eight new QA GLBs: four high-res torso and four unchanged-topology low."""
    high_path={None:Path(high_master),
        **{ex:Path(high_exercises)/(ex+'_v915_high_detail_authoring.glb')
           for ex in EXERCISE_IDS}}
    low_path={None:Path(low_master),
        **{ex:Path(low_exercises)/(ex+'_v915_mobile_normal_bake_qa.glb')
           for ex in EXERCISE_IDS}}
    master=GLB(high_path[None].read_bytes(),expected_sha=None)
    _validate_input(master,GLB(low_path[None].read_bytes(),
                               expected_sha=None))
    highparts=master.doc['meshes'][0]['primitives']
    _,faces=_atlas(master,highparts,HIGH_VERTICES)
    masterattr=highparts[0]['attributes']
    mp=master.accessor(masterattr['POSITION'])
    mn=master.accessor(masterattr['NORMAL'])
    sculpted,refined,weights,geometry=sculpt_high(mp,mn,faces)
    folder=Path(output);folder.mkdir(parents=True,exist_ok=True)
    assets=[]
    for ex in (None,*EXERCISE_IDS):
        high_raw=high_path[ex].read_bytes()
        low_raw=low_path[ex].read_bytes()
        hi=GLB(high_raw,expected_sha=None)
        lo=GLB(low_raw,expected_sha=None)
        hattr,hpos,hnorm,lattr,lpos,lnorm=_validate_input(hi,lo,ex)
        if any(math.dist(a,b)>2e-6 for a,b in zip(hpos,mp)):
            raise ValueError('Exercise high-res skin differs from master')
        if len(hi.doc['meshes'])!=(1 if ex is None else
                                   (3 if ex=='ex_bench_press' else 2)):
            raise ValueError('Wrong equipment meshes')
        low_baked,transferred=normal_transfer(
            lpos,lnorm,hpos,refined,weights)
        replace_accessor(hi,hattr['POSITION'],sculpted)
        replace_accessor(hi,hattr['NORMAL'],refined)
        hi.doc['accessors'][hattr['POSITION']]['min']=[
            min(p[k] for p in sculpted) for k in range(3)]
        hi.doc['accessors'][hattr['POSITION']]['max']=[
            max(p[k] for p in sculpted) for k in range(3)]
        replace_accessor(lo,lattr['NORMAL'],low_baked)
        for glb,variant in ((hi,'authoring'),(lo,'mobile')):
            glb.doc['extras']=dict(glb.doc.get('extras',{}),
                torsoContourArtVersion=916,
                torsoContourGroups=list(ARTIST_GROUPS),
                torsoContourQAOnly=True,
                torsoContourOutput=variant,
                approved=False,enabled=False,
                expertAnatomyReviewed=False,
                physicalDeviceMeasured=False)
        high_output=hi.bytes()
        low_output=lo.bytes()
        if len(high_output)>MAX_HIGH_BYTES or len(low_output)>(
            MAX_MASTER_LOD_BYTES if ex is None else MAX_EXERCISE_LOD_BYTES):
            raise ValueError('GLB increased past size budget')
        name='stk_master' if ex is None else ex
        (folder/(name+'_v916_torso_high_qa.glb')).write_bytes(high_output)
        (folder/(name+'_v916_torso_mobile_qa.glb')).write_bytes(low_output)
        assets.append({'exerciseId':ex,'name':name,
            'highBytes':len(high_output),'lowBytes':len(low_output),
            'highSha256':hashlib.sha256(high_output).hexdigest(),
            'lowSha256':hashlib.sha256(low_output).hexdigest(),
            'normalTransfer':transferred,
            'approved':False,'enabled':False})
    report={
        'schema':'stk_anatomy_torso_contours_v916',
        'catalogCount':229,'skeletonJoints':55,'morphCount':8,
        'existingMuscleAtlasGroups':11,'newApproximateTorsoContours':3,
        'highVertices':HIGH_VERTICES,'mobileVertices':LOW_VERTICES,
        'highTriangles':39372,
        'trianglesAddedToMobile':0,'motionAndRigChanges':0,
        'geometry':geometry,'assets':assets,
        'clinicalAnatomyCertification':False,
        'physicalDeviceGpuTested':False,
        'approved':False,'enabled':False,
        'notes':['Artist-directed contour fields, not exact muscle origin/insertion',
                 'No additional mesh groups in mobile catalog',
                 'Requires expert review and physical iOS/Android render QA'],
    }
    (folder/'torso_contours_v916_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--high-master',type=Path,required=True)
    ap.add_argument('--low-master',type=Path,required=True)
    ap.add_argument('--high-pilots',type=Path,required=True)
    ap.add_argument('--low-pilots',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args()
    report=build(args.high_master,args.low_master,args.high_pilots,
                 args.low_pilots,args.output)
    print(json.dumps({'version':916,
        'groups':report['newApproximateTorsoContours'],
        'assets':len(report['assets']),
        'approved':False,'enabled':False},indent=2))

if __name__=='__main__':
    main()
