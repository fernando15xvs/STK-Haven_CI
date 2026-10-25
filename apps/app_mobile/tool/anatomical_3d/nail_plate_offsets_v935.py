#!/usr/bin/env python3
"""STK Haven v9.35: conservative nail-plate offset optimization, QA only.

Search submillimetre translations of each v9.33 rigid nail plate along its
own local dorsal normal. Probe actual morphed/skinned distal skin triangles,
then verify all 241 poses at 60 Hz with v9.34. Export changes ONLY when every
modified nail reduces a measured risk without making any other risk worse.
Otherwise discard ALL proposed edits and retain original v9.33 geometry.

No artist-validated dorsal direction, continuous collision test, complete
cuticles, or production approval. This is NOT anatomical certification.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import struct
from pathlib import Path

from audit_finger_contact_bounds_v923 import _read_refined
from build_rig_nail_plates_v933 import MATERIAL_NAME
from exercise_surface_collision_v911 import _samplers,_sample,_skin_vertex
from retarget_cc0_glb import GLB, EXERCISES, add, sub, mul, dot, norm, cross, unit, qrot
from refine_fingertip_topology_v922 import MAX_MOBILE_BYTES
import nail_plate_skin_proximity_v934 as audit934

OFFSETS_METERS=(-.0005,-.00025,0.,.00025,.0005)
REVIEW_FRAMES=tuple(range(0,241,30))
MIN_RISK_REDUCTION=1
MAX_SEPARATION_REGRESSION_METERS=.00055
FRAMES=241
FPS=60


def _rig_normal(glb,entry):
    """Original nail front normal is a rig-local candidate direction."""
    node=glb.doc['nodes'][entry['nailNode']]
    mesh=glb.doc['meshes'][node['mesh']]['primitives'][0]
    if glb.doc['materials'][mesh['material']]['name']!=MATERIAL_NAME:
        raise ValueError('Invalid experimental nail material')
    normals=glb.accessor(mesh['attributes']['NORMAL'])
    if len(normals)!=70 or not all(math.isfinite(x)
                                   for n in normals for x in n):
        raise ValueError('Unexpected original nail surface normals')
    n=unit(tuple(sum(v[k] for v in normals[:35])
                 for k in range(3)))
    if not .999<norm(n)<1.001:
        raise ValueError('Invalid local dorsal axis')
    return n


def risk_gate(baseline,candidate):
    """Per-digit fail-closed guard against sampled skin-contact regressions."""
    keys=('possibleEmbeddedVertexSamples','possiblyDetachedVertexSamples',
          'largestObservedSeparationMeters')
    if any(k not in before for before in (baseline,candidate) for k in keys):
        raise ValueError('Missing full 60Hz v9.34 nail-skin evidence')
    before_e=baseline[keys[0]]
    after_e=candidate[keys[0]]
    before_d=baseline[keys[1]]
    after_d=candidate[keys[1]]
    if (not all(isinstance(x,int) and x>=0 for x in
                (before_e,after_e,before_d,after_d)) or
        not all(isinstance(item['largestObservedSeparationMeters'],(int,float))
                and math.isfinite(item['largestObservedSeparationMeters'])
                for item in (baseline,candidate))):
        raise ValueError('Nonfinite or invalid evidence')
    if after_e>before_e:
        return False,'more_possible_skin_embeddings'
    if after_d>before_d:
        return False,'more_possible_detachment'
    if (candidate['largestObservedSeparationMeters'] >
        baseline['largestObservedSeparationMeters']+
        MAX_SEPARATION_REGRESSION_METERS):
        return False,'worse_maximum_nail_skin_separation'
    benefit=(before_e-after_e)+(before_d-after_d)
    if benefit<MIN_RISK_REDUCTION:
        return False,'no_measurable_60hz_risk_reduction'
    return True,'sampled_contact_risk_reduced'


def _score(offset,entry,direction,world,rotations,faces):
    """Nine underside probes, nearest *triangle* not only skin vertices."""
    source=entry['underside']
    origin=world[entry['nailNode']]
    rotation=rotations[entry['nailNode']]
    embed,detach=0,0
    for local in source:
        point=add(origin,qrot(rotation,add(local,mul(direction,offset))))
        nearest_distance=float('inf')
        nearest_sign=0.
        for a,b,c,normal in faces:
            near=audit934.closest_triangle(point,a,b,c)
            displacement=sub(point,near)
            dist=norm(displacement)
            if dist<nearest_distance:
                nearest_distance=dist
                nearest_sign=dot(displacement,normal)
        if (nearest_sign<-audit934.POSSIBLE_EMBED_DEPTH and
            nearest_distance<audit934.MAX_SAMPLE_DISTANCE):
            embed+=1
        if nearest_distance>audit934.MAX_SAMPLE_DISTANCE:
            detach+=1
    return embed,detach


def _search(glb,points,joints,weights,morphs,ibm,skin,entries):
    """Search 9 poses; only full 241-pose evidence can retain the edits."""
    channels=_samplers(glb)
    selected=sorted(set().union(*(e['surfaceVertexIndices']
                                  for e in entries.values())))
    rows={
        i:(points[i],[shape[i] for shape in morphs],weights[i],joints[i])
        for i in selected
    }
    normals={name:_rig_normal(glb,e) for name,e in entries.items()}
    scores={name:{delta:[0,0] for delta in OFFSETS_METERS}
            for name in entries}
    for frame in REVIEW_FRAMES:
        world,rotations,activation=_sample(glb,channels,frame/FPS)
        skinned={
            i:_skin_vertex(p,sh,w,j,ibm,world,rotations,skin,activation)
            for i,(p,sh,w,j) in rows.items()
        }
        for name,entry in entries.items():
            faces=[]
            for tri in entry['faces']:
                a,b,c=(skinned[i] for i in tri)
                outward=cross(sub(b,a),sub(c,a))
                if norm(outward)<1e-11:
                    raise ValueError('Collapsed skin triangle in nail search')
                faces.append((a,b,c,unit(outward)))
            for offset in OFFSETS_METERS:
                emb,det=_score(offset,entry,normals[name],world,
                                rotations,faces)
                scores[name][offset][0]+=emb
                scores[name][offset][1]+=det
    chosen={}
    choices={}
    for name,options in scores.items():
        before=options[0.]
        feasible=[
            delta for delta in OFFSETS_METERS if delta and
            options[delta][0]<=before[0] and
            options[delta][1]<=before[1] and
            sum(options[delta])<sum(before)
        ]
        best=min(feasible,key=lambda d:(sum(options[d]),
                  abs(d),d)) if feasible else 0.
        if best:
            chosen[name]=best
        choices[name]={
            'originalEmbeddedProbes':before[0],
            'originalDetachedProbes':before[1],
            'offsetProposedMeters':best,
            'sampledFramesBeforeFinalGate':len(REVIEW_FRAMES),
            'newEmbeddedProbes':options[best][0],
            'newDetachedProbes':options[best][1],
            'localNormal':list(normals[name]),
        }
    return chosen,choices


def _rewrite_positions(glb,entries,offsets,choices):
    """Patch only 70 VEC3 floats per selected rigid nail: no topology edits."""
    if len(offsets)>10:
        raise ValueError('Too many nail adjustments')
    for name,offset in offsets.items():
        if offset not in OFFSETS_METERS or not offset:
            raise ValueError('Outside 0.5 mm candidate-only translation')
        mesh=glb.doc['meshes'][
            glb.doc['nodes'][entries[name]['nailNode']]['mesh']
        ]['primitives'][0]
        accessor=glb.doc['accessors'][mesh['attributes']['POSITION']]
        view=glb.doc['bufferViews'][accessor['bufferView']]
        if (accessor['type']!='VEC3' or
            accessor['componentType']!=5126 or
            accessor['count']!=70 or
            view.get('buffer')!=0 or
            view.get('byteStride') is not None or
            view['byteLength']!=70*12 or
            accessor.get('byteOffset',0)!=0):
            raise ValueError('Unsafe packed nail vertex layout')
        start=view.get('byteOffset',0)
        end=start+70*12
        if start<0 or end>len(glb.binary) or start%4:
            raise ValueError('Out-of-bounds nail offset')
        normal=choices[name]['localNormal']
        existing=glb.accessor(mesh['attributes']['POSITION'])
        corrected=[add(p,mul(normal,offset)) for p in existing]
        if any(not all(math.isfinite(x) for x in p) for p in corrected):
            raise ValueError('Nonfinite nail candidate')
        glb.binary[start:end]=struct.pack(
            '<210f',*(value for p in corrected for value in p))
        accessor['min']=[min(p[i] for p in corrected) for i in range(3)]
        accessor['max']=[max(p[i] for p in corrected) for i in range(3)]


def optimize(raw,exercise):
    if exercise not in EXERCISES:
        raise ValueError('Unexpected exercise ID')
    glb,points,joints,weights,morphs,ibm,skin,groups=_read_refined(
        raw,exercise)
    meta=glb.doc['extras']
    if (meta.get('nailPlatePrototypeVersion')!=933 or
        meta.get('distalNailBedVersion')!=932 or
        meta.get('nailContactOffsetOptimizerVersion') is not None or
        meta.get('approved') is not False or
        meta.get('enabled') is not False):
        raise ValueError('Only original disabled v9.33 nail GLB accepted')
    preserved={k:copy.deepcopy(glb.doc[k]) for k in (
        'skins','nodes','meshes','materials','animations')}
    original_report=audit934.review(raw,exercise)
    entries=audit934._nail_entries(glb,points,joints,weights,skin,groups)
    chosen,choices=_search(
        glb,points,joints,weights,morphs,ibm,skin,entries)
    candidate_report=None
    selected={}
    gate_reasons={}
    if chosen:
        _rewrite_positions(glb,entries,chosen,choices)
        proposed=glb.bytes()
        candidate_report=audit934.review(proposed,exercise)
        all_safe=True
        for name in entries:
            before=original_report['digits'][name]
            after=candidate_report['digits'][name]
            if name in chosen:
                ok,reason=risk_gate(before,after)
                gate_reasons[name]=reason
                all_safe=all_safe and ok
            else:
                # Nail translations do not influence the skin or other
                # parented plates, so untouched digits must remain equal.
                exact=(
                    before['possibleEmbeddedVertexSamples']==
                    after['possibleEmbeddedVertexSamples'] and
                    before['possiblyDetachedVertexSamples']==
                    after['possiblyDetachedVertexSamples']
                )
                if not exact:
                    all_safe=False
                    gate_reasons[name]='unexpected_cross_digit_regression'
        if all_safe:
            selected=chosen
    retained=bool(selected)
    if not retained:
        # A failed collective safety gate discards ALL nail edits,
        # not just the first digit found. Preserve original v9.33 bytes.
        glb=GLB(raw,expected_sha=None)
        candidate_report=None
    meta=glb.doc['extras']
    meta.update({
        'nailContactOffsetOptimizerVersion':935,
        'sourceNailPlatesSha256':hashlib.sha256(raw).hexdigest(),
        'nailContactOffsetsProposed':len(chosen),
        'nailContactOffsetsKept':len(selected),
        'nailContactOffsetWholeClipFallback':bool(chosen) and not retained,
        'maxOffsetMeters':max((abs(x) for x in selected.values()),default=0.),
        'nailAnatomyArtistApproved':False,
        'continuousTriangleCollisionCertified':False,
        'completeNailSkinContactIK':False,
        'physicalDeviceVerified':False,
        'approved':False,'enabled':False,
    })
    if any(glb.doc[k]!=old for k,old in preserved.items()):
        raise ValueError('Nail optimizer changed original rig or skin structure')
    output=glb.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Optimized nail pilot outside mobile budget')
    result=GLB(output,expected_sha=None)
    if (len(result.doc['meshes'])!=len(preserved['meshes']) or
        len(result.doc['animations'][0]['channels'])!=
        len(preserved['animations'][0]['channels'])):
        raise ValueError('Nail optimizer lost existing animation or mesh')
    baseline_glb=GLB(raw,expected_sha=None)
    for name in entries:
        a=baseline_glb.doc['meshes'][
            baseline_glb.doc['nodes'][entries[name]['nailNode']]['mesh']
            ]['primitives'][0]
        c=result.doc['meshes'][
            result.doc['nodes'][entries[name]['nailNode']]['mesh']
            ]['primitives'][0]
        # Same face winding, normals and UV0, even if positions move.
        for attr in ('NORMAL','TEXCOORD_0'):
            if baseline_glb.accessor(a['attributes'][attr])!=(
                    result.accessor(c['attributes'][attr])):
                raise ValueError('Nail normals or UV changed')
        if baseline_glb.accessor(a['indices'])!=result.accessor(c['indices']):
            raise ValueError('Nail triangles mutated')
        if name not in selected and (
            baseline_glb.accessor(a['attributes']['POSITION'])!=
            result.accessor(c['attributes']['POSITION'])):
            raise ValueError('Unselected nail was changed')
    report={
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'rigJoints':55,'morphTargets':8,
        'nailPlatesReviewed':10,
        'searchFrames':len(REVIEW_FRAMES),
        'fullGateFrames':FRAMES,
        'offsetsProposed':len(chosen),
        'offsetsKept':len(selected),
        'wholeClipFallback':bool(chosen) and not retained,
        'selectedMeters':selected,
        'candidateSearch':choices,
        'gateDecisions':gate_reasons,
        'before60Hz':{
            name:{
                'embedded':original_report['digits'][name][
                    'possibleEmbeddedVertexSamples'],
                'detached':original_report['digits'][name][
                    'possiblyDetachedVertexSamples'],
            } for name in entries
        },
        'after60Hz':{
            name:{
                'embedded':candidate_report['digits'][name][
                    'possibleEmbeddedVertexSamples'],
                'detached':candidate_report['digits'][name][
                    'possiblyDetachedVertexSamples'],
            } for name in entries
        } if retained else None,
        'continuousCollisionCertified':False,
        'professionalNailAnatomyComplete':False,
        'physicalDeviceVerified':False,
        'assetBytes':len(output),
        'approved':False,'enabled':False,
    }
    return output,report


def build(source_dir,output_dir):
    source_dir,output_dir=Path(source_dir),Path(output_dir)
    output_dir.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        raw=(source_dir/(exercise+'_v933_rig_nail_plates_mobile_qa.glb')
             ).read_bytes()
        output,report=optimize(raw,exercise)
        (output_dir/(exercise+'_v935_nail_contact_offset_mobile_qa.glb')
         ).write_bytes(output)
        reports.append(report)
    summary={
        'schema':'stk_v935_bounded_nail_plate_60hz_rollback_qa',
        'catalogCount':229,'pilotCount':3,'nailsPerPilot':10,
        'maxNailTranslationMeters':max(abs(x) for x in OFFSETS_METERS),
        'verifiedFramesPerClip':FRAMES,
        'keptNailOffsets':sum(r['offsetsKept'] for r in reports),
        'fallbackPilots':sum(r['wholeClipFallback'] for r in reports),
        'nailPlateIndependentExpertReviewed':False,
        'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,
        'productionReady':False,'approved':False,'enabled':False,
        'pilots':reports,
    }
    (output_dir/'nail_offsets_v935_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    summary=build(args.input,args.output)
    print(json.dumps({
        'schema':summary['schema'],'pilots':summary['pilotCount'],
        'offsetsRetained':summary['keptNailOffsets'],
        'approved':False,'enabled':False,
    },indent=2))
