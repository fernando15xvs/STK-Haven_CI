#!/usr/bin/env python3
"""STK Haven v9.19 - geometry-level skinned fingertip/bar audit, QA ONLY.

v9.18 measured distal joint origins; this measures vertices actually skinned by
the third phalanx of each finger. The skin and all eight existing morph shapes
are interpolated from real 55-bone GLB data at 121 poses. No bar collision or
human finger contact is *certified* by sparse skinned-vertex samples.

No new mobile assets, runtime flags, textures, production catalog, or web changes.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, EXERCISES, SOURCE_SHA
from exercise_surface_collision_v911 import (
    _samplers, _sample, _skin_vertex, capped_cylinder_sdf,
)
from animate_hand_grip_v917 import DIGITS, SIDES

FPS=30
FRAMES=121
SHAFT_RADIUS=.019
SHAFT_MIN_X=-1.10
SHAFT_MAX_X=1.10
MIN_SKIN_WEIGHT=.20
MIN_DISTAL_SKIN_VERTICES=6
MAX_SKIN_VERTICES_PER_FINGER=36
MAX_MOBILE_GLB_BYTES=1400*1024
MAX_ALLOWED_CONTACT_GAP=.010  # QA classification threshold, not physical certification


def _verified_mesh(raw,exercise,required_version):
    if len(raw)>MAX_MOBILE_GLB_BYTES:
        raise ValueError('Unpublished mobile GLB exceeds QA budget')
    glb=GLB(raw,expected_sha=None)
    doc=glb.doc
    meta=doc.get('extras',{})
    if (exercise not in EXERCISES or
        meta.get('exerciseId')!=exercise or
        meta.get('sourceSha256')!=SOURCE_SHA or
        meta.get('masterExercisePilotVersion')!=910 or
        meta.get('torsoContourArtVersion')!=916 or
        meta.get('handGripArtVersion')!=917 or
        meta.get('approved') is not False or
        meta.get('enabled') is not False or
        (meta.get('gripContactCalibrationVersion')==918)!=required_version or
        len(doc['skins'])!=1 or len(doc['skins'][0]['joints'])!=55 or
        len(doc['animations'])!=1 or
        len(doc['meshes'][0]['primitives'])!=12 or
        len(doc['meshes'])!=(3 if exercise=='ex_bench_press' else 2)):
        raise ValueError('Require disabled master55 v9.17/v9.18 pilot, not catalog GLB')
    if 'STK_EXERCISE_BAR' not in glb.by_name:
        raise ValueError('Original equipment joint missing')
    a=doc['meshes'][0]['primitives'][0]['attributes']
    original=glb.accessor(a['POSITION'])
    joints=glb.accessor(a['JOINTS_0'])
    weights=glb.accessor(a['WEIGHTS_0'])
    deltas=[glb.accessor(t['POSITION'])
            for t in doc['meshes'][0]['primitives'][0]['targets']]
    if len(deltas)!=8 or len(original)!=4727 or any(
            len(x)!=len(original) for x in (joints,weights,*deltas)):
        raise ValueError('Expected complete eight-morph 4,727-vertex mobile skin')
    skin=doc['skins'][0]['joints']
    im=glb.accessor(doc['skins'][0]['inverseBindMatrices'])
    if len(im)!=55:
        raise ValueError('Expected 55 inverse bind matrices')
    selections={}
    for side in SIDES:
        for digit in DIGITS:
            name=f'{digit}_03_{side}'
            if name not in glb.by_name or glb.by_name[name] not in skin:
                raise ValueError('Missing distal phalanx '+name)
            palette=skin.index(glb.by_name[name])
            found=[]
            for i,(palette_row,weight_row) in enumerate(zip(joints,weights)):
                amount=sum(weight for joint,weight in zip(palette_row,weight_row)
                           if int(joint)==palette)
                if amount>=MIN_SKIN_WEIGHT:
                    found.append((i,amount))
            if len(found)<MIN_DISTAL_SKIN_VERTICES:
                raise ValueError('Low-poly fingertip surface has no real vertices: '+name)
            # Sort deterministically, preserving a range of skinned polygon
            # vertices around the last phalanx; not fabricated fingertip points.
            found.sort(key=lambda x:(-x[1],x[0]))
            selections[(side,digit)]=[i for i,_ in found[
                :MAX_SKIN_VERTICES_PER_FINGER]]
    return glb,original,joints,weights,deltas,im,skin,selections


def measure(raw,exercise,calibrated):
    (glb,positions,joints,weights,deltas,ibm,skin,groups
        )=_verified_mesh(raw,exercise,calibrated)
    keys=_samplers(glb)
    if len(groups)!=10:
        raise ValueError('Missing finger skin groups')
    # Flatten unique vertices so shared or blended fingertips are skinned once
    # per frame. glTF morph weights remain animated as in the supplied GLB.
    vertices=sorted({i for selection in groups.values() for i in selection})
    if len(vertices)<60:
        raise ValueError('Insufficient distinct sampled fingertip skin vertices')
    channel={i:(positions[i],[d[i] for d in deltas],weights[i],joints[i])
             for i in vertices}
    stats={(side,digit):{'count':0,'sumNearestPositive':0.,
        'maxNearestPositive':0.,'deepSkinIntersections':0,
        'within10mmFrames':0,'minSignedGap':float('inf')}
        for side in SIDES for digit in DIGITS}
    for frame in range(FRAMES):
        world,rotation,morph=_sample(glb,keys,frame/FPS)
        bar=world[glb.by_name['STK_EXERCISE_BAR']]
        skinned={}
        for i,(position,delta,weight,joint) in channel.items():
            skinned[i]=_skin_vertex(position,delta,weight,joint,ibm,
                                    world,rotation,skin,morph)
        for group,indices in groups.items():
            signed=[]
            for idx in indices:
                p=skinned[idx]
                rel=(p[0]-bar[0],p[1]-bar[1],p[2]-bar[2])
                signed.append(capped_cylinder_sdf(
                    rel,SHAFT_MIN_X,SHAFT_MAX_X,SHAFT_RADIUS))
            nearest=min(signed)
            if not math.isfinite(nearest):
                raise ValueError('Nonfinite skinned finger geometry')
            nearest_positive=max(0.,nearest)
            entry=stats[group]
            entry['count']+=1
            entry['sumNearestPositive']+=nearest_positive
            entry['maxNearestPositive']=max(
                entry['maxNearestPositive'],nearest_positive)
            entry['minSignedGap']=min(entry['minSignedGap'],nearest)
            if nearest<=MAX_ALLOWED_CONTACT_GAP:
                entry['within10mmFrames']+=1
            if nearest<-.002:
                entry['deepSkinIntersections']+=1
    measured={}
    for (side,digit),entry in stats.items():
        if entry['count']!=FRAMES:
            raise ValueError('Incomplete 121-frame skinned finger sample')
        mean=entry['sumNearestPositive']/entry['count']
        measured[f'{digit}_{side}']={
          'sampledMeshVertexCount':len(groups[(side,digit)]),
          'frames':FRAMES,
          'meanNearestPositiveGapMeters':round(mean,7),
          'worstNearestPositiveGapMeters':round(
              entry['maxNearestPositive'],7),
          'minimumSignedSurfaceGapMeters':round(
              entry['minSignedGap'],7),
          'framesWithin10mmOfShaft':entry['within10mmFrames'],
          'framesPossibleSkinPenetrationOver2mm':entry[
              'deepSkinIntersections'],
          'notContinuousCollisionDetection':True,
        }
    return {'exerciseId':exercise,'calibrated':calibrated,
       'uniqueSkinnedSurfaceVertices':len(vertices),
       'totalVertexSkinEvaluations':len(vertices)*FRAMES,
       'distalSurfaceGroups':10,
       'samplesPerGroup':FRAMES,
       'fingerSurfaceMetrics':measured,
       'surfaceContactCertified':False,
       'physicalDeviceVerified':False,
       'approved':False,'enabled':False,
       'sourceSha256':hashlib.sha256(raw).hexdigest()}


def build(folder,out_dir):
    origin=Path(folder)
    output=Path(out_dir)
    output.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        original=(origin/(exercise+'_v917_finger_mobile_qa.glb')
                    ).read_bytes()
        calibrated=(origin/'contact_v918'/(
                     exercise+'_v918_contact_mobile_qa.glb')
                    ).read_bytes()
        before=measure(original,exercise,False)
        after=measure(calibrated,exercise,True)
        if (before['uniqueSkinnedSurfaceVertices']!=
              after['uniqueSkinnedSurfaceVertices'] or
            before['distalSurfaceGroups']!=after['distalSurfaceGroups']):
            raise ValueError('Mobile finger skin vertex mapping changed')
        compared={}
        for name,a in after['fingerSurfaceMetrics'].items():
            b=before['fingerSurfaceMetrics'][name]
            compared[name]={
              'baselineMeanPositiveGapMeters':b[
                  'meanNearestPositiveGapMeters'],
              'calibratedMeanPositiveGapMeters':a[
                  'meanNearestPositiveGapMeters'],
              'changeInMeanGapMeters':round(
                  a['meanNearestPositiveGapMeters']-
                  b['meanNearestPositiveGapMeters'],7),
              'remainingPossibleSkinPenetrations':a[
                  'framesPossibleSkinPenetrationOver2mm'],
              'needsExpertVisualReview':True,
            }
        reports.append({'exerciseId':exercise,
           'v917':before,'v918':after,
           'fingerComparisons':compared,
           'skinContactCorrectlyCertified':False})
    report={'schema':'stk_v919_real_skinned_fingertip_geometry_audit',
        'catalogCount':229,'pilotCount':3,'rigJoints':55,
        'skinnedMorphTargets':8,'framesPerExercise':FRAMES,
        'fingerGroupsPerExercise':10,'maxAllowedRadiusGapMeters':.010,
        'description':'Discrete skinned distal-region vertices vs ideal bar shaft',
        'expertAnatomyReviewed':False,'physicalDeviceTested':False,
        'certifiesFingertipContact':False,'collisionFreeCertified':False,
        'productionReady':False,'approved':False,'enabled':False,
        'limitations':[
            'Distal joint weighted vertices are only a skin proxy, not an exact fingertip surface segmentation',
            'Discrete samples are not continuous collision detection',
            'The cylinder excludes wider grip reference rings and hand-object friction',
            'Finger-to-bar contact and skeletal ergonomics still need professional review',
            'No changes made to current Flutter production assets',
        ],
        'pilots':reports}
    (output/'fingertip_skin_contact_v919_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report


if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('--input',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args()
    report=build(args.input,args.output)
    print(json.dumps({
        'schema':report['schema'],'pilotCount':report['pilotCount'],
        'skinnedMorphTargets':report['skinnedMorphTargets'],
        'certifiesFingertipContact':False,
    },indent=2))
