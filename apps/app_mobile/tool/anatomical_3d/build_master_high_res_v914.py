#!/usr/bin/env python3
"""v9.14: CC0 master55 high-density authoring mesh, OFFLINE/UNAPPROVED.

Weld four-way triangle subdivisions across the 11 anatomical regions, blend
skin/morph weights, and apply at most 1.4mm mid-edge curvature. The 4.7k-vertex
mobile LOD, all clips and historical data remain untouched. A subdivision
is not a professional muscle, tendon or fascia sculpt.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, SOURCE_SHA
from build_master_surface_v6 import MORPH_NAMES
from build_master_anatomy_v8 import REGION_ORDER, EXERCISE_IDS
from build_master_surface_v2 import cross, sub

MAX_VERTICES=25000
MAX_TRIANGLES=50000
MAX_BYTES=6*1024*1024
MAX_CURVE=.0014


def length(v):
    return math.sqrt(sum(x*x for x in v))


def dot(a,b):
    return sum(x*y for x,y in zip(a,b))


def normalized(a):
    l=length(a)
    if l<1e-10 or not math.isfinite(l):
        raise ValueError('Degenerate anatomical surface normal')
    return tuple(x/l for x in a)


def blended_joint(a,wa,b,wb):
    result={}
    for js,ws in ((a,wa),(b,wb)):
        if len(js)!=4 or len(ws)!=4:
            raise ValueError('Require glTF four-influence skin weights')
        for joint,weight in zip(js,ws):
            j=int(joint)
            if j!=joint or not 0<=j<55 or not 0<=weight<=1.025:
                raise ValueError('Invalid joint influence')
            result[j]=result.get(j,0.)+.5*weight
    if not .98<=sum(result.values())<=1.02:
        raise ValueError('Source skin weights not normalized')
    order=sorted(result,key=lambda j:(-result[j],j))
    chosen=order[:4]
    discarded=sum(result[j] for j in order[4:])
    if discarded>.26:raise ValueError('Seam loses excessive joint influence')
    divisor=sum(result[j] for j in chosen)
    ids=tuple(chosen+[0]*(4-len(chosen)))
    weights=tuple([result[j]/divisor for j in chosen]+[0.]*(4-len(chosen)))
    return ids,weights,discarded


def edge_point(a,b,na,nb):
    mid=tuple((x+y)*.5 for x,y in zip(a,b))
    direction=sub(b,a)
    normal=normalized(tuple(na[k]+nb[k] for k in range(3)))
    edge=length(direction)
    curve=.125*dot(direction,sub(nb,na)) if edge<=.10 else 0.
    cap=min(MAX_CURVE,.055*edge)
    curve=max(-cap,min(cap,curve))
    return tuple(mid[k]+curve*normal[k] for k in range(3)),normal,abs(curve)


def check_source(glb,exercise=None):
    doc=glb.doc;meta=doc.get('extras',{})
    if (meta.get('masterSculptDetailVersion')!=8 or
        meta.get('anatomyArtVersion')!=913 or
        meta.get('sourceSha256')!=SOURCE_SHA or
        meta.get('approved') is not False or
        meta.get('enabled') is not False or
        len(doc.get('skins',[]))!=1 or
        len(doc['skins'][0]['joints'])!=55 or
        len(doc.get('animations',[]))!=(7 if exercise is None else 1) or
        len(doc.get('meshes',[]))!=(1 if exercise is None else
            (3 if exercise=='ex_bench_press' else 2)) or
        len(doc['meshes'][0]['primitives'])!=12 or
        tuple(doc['meshes'][0]['extras'].get('targetNames',()))!=MORPH_NAMES):
        raise ValueError('Expected disabled and trusted v9.13 anatomical master')
    if exercise is not None and (exercise not in EXERCISE_IDS or
        meta.get('exerciseId')!=exercise or
        meta.get('masterExercisePilotVersion')!=910):
        raise ValueError('Wrong exercise source version or ID')
    parts=doc['meshes'][0]['primitives']
    if {p['extras']['stkMuscleRegion'] for p in parts}!=set(REGION_ORDER)|{'body'}:
        raise ValueError('Expected 11 muscle groups and body atlas')
    attr=parts[0]['attributes'];targets=parts[0]['targets']
    if len(targets)!=8 or any(p['attributes']!=attr or
        p['targets']!=targets for p in parts):
        raise ValueError('Source GLB does not share eight morph streams')
    position=glb.accessor(attr['POSITION'])
    normal=glb.accessor(attr['NORMAL'])
    joints=glb.accessor(attr['JOINTS_0'])
    weights=glb.accessor(attr['WEIGHTS_0'])
    morph=[glb.accessor(t['POSITION']) for t in targets]
    if not 1000<len(position)<10000 or any(len(x)!=len(position)
        for x in (normal,joints,weights,*morph)):
        raise ValueError('Unexpected anatomical source mesh')
    return parts,position,normal,joints,weights,morph


def subdivide(raw,exercise=None):
    if len(raw)>MAX_BYTES:raise ValueError('Oversized source authoring GLB')
    glb=GLB(raw,expected_sha=None)
    old_skins=copy.deepcopy(glb.doc['skins'])
    old_nodes=copy.deepcopy(glb.doc['nodes'])
    old_clips=copy.deepcopy(glb.doc['animations'])
    parts,p,n,j,w,m=check_source(glb,exercise)
    vertices=[tuple(x) for x in p]
    normals=[tuple(x) for x in n]
    influences=[tuple(int(v) for v in row) for row in j]
    weights=[tuple(v for v in row) for row in w]
    morphs=[[tuple(x) for x in shape] for shape in m]
    edges={}
    triangles=[]
    regions={}
    max_curve=max_lost=0.
    def midpoint(a,b):
        nonlocal max_curve,max_lost
        key=(min(a,b),max(a,b))
        if key in edges:return edges[key]
        aa,bb=key
        point,normal,curve=edge_point(p[aa],p[bb],n[aa],n[bb])
        js,ws,discarded=blended_joint(j[aa],w[aa],j[bb],w[bb])
        max_curve=max(max_curve,curve)
        max_lost=max(max_lost,discarded)
        index=len(vertices)
        edges[key]=index
        vertices.append(point);normals.append(normal)
        influences.append(js);weights.append(ws)
        for k in range(8):
            morphs[k].append(tuple((m[k][aa][c]+m[k][bb][c])*.5
                                   for c in range(3)))
        return index
    for part in parts:
        indices=[int(v[0]) for v in glb.accessor(part['indices'])]
        if len(indices)%3:raise ValueError('Broken region triangles')
        subdivided=[]
        for offset in range(0,len(indices),3):
            a,b,c=indices[offset:offset+3]
            if len({a,b,c})<3 or not all(0<=k<len(p) for k in (a,b,c)):
                raise ValueError('Source degenerate or out-of-range face')
            ab=midpoint(a,b);bc=midpoint(b,c);ca=midpoint(c,a)
            triangles.append((a,b,c,ab,bc,ca))
            for x,y,z in ((a,ab,ca),(ab,b,bc),(ca,bc,c),(ab,bc,ca)):
                subdivided.extend((x,y,z))
        regions[part['extras']['stkMuscleRegion']]=subdivided
    # Check orientation and automatically flatten unsafe midpoints instead of
    # letting micro-curvature flip tiny faces around wrist/ankle UV seams.
    inverse_edges={index:key for key,index in edges.items()}
    suppressed=set()
    for _ in range(5):
        invalid=set();flip_count=0
        for a,b,c,ab,bc,ca in triangles:
            old=cross(sub(p[b],p[a]),sub(p[c],p[a]))
            if length(old)<=1e-10:continue
            for x,y,z in ((a,ab,ca),(ab,b,bc),(ca,bc,c),(ab,bc,ca)):
                new=cross(sub(vertices[y],vertices[x]),
                          sub(vertices[z],vertices[x]))
                if dot(old,new)<=0:
                    flip_count+=1
                    invalid.update((ab,bc,ca))
        if not flip_count:break
        unseen=invalid-suppressed
        if not unseen:raise ValueError('Cannot repair inverted subdivided face')
        for i in unseen:
            a,b=inverse_edges[i]
            vertices[i]=tuple((x+y)*.5 for x,y in zip(p[a],p[b]))
        suppressed.update(unseen)
    if len(suppressed)>max(80,len(edges)//75):
        raise ValueError('Too many unsafe curvature regions')
    faces=sum(len(v)//3 for v in regions.values())
    if (flip_count or faces!=len(triangles)*4 or faces>MAX_TRIANGLES or
        len(vertices)>MAX_VERTICES or len(edges)<6000):
        raise ValueError('Subdivision complexity or winding gate failed')
    if any(len(x)!=len(vertices) for x in
           (normals,influences,weights,*morphs)):
        raise ValueError('Incomplete subdivided morph or skin stream')
    attr={
      'POSITION':glb.append(vertices,3,'VEC3',target=34962),
      'NORMAL':glb.append(normals,3,'VEC3',target=34962),
      'JOINTS_0':glb.append(influences,4,'VEC4',component=5123,target=34962),
      'WEIGHTS_0':glb.append(weights,4,'VEC4',target=34962),
    }
    ai=attr['POSITION']
    glb.doc['accessors'][ai]['min']=[min(v[k] for v in vertices) for k in range(3)]
    glb.doc['accessors'][ai]['max']=[max(v[k] for v in vertices) for k in range(3)]
    targets=[{'POSITION':glb.append(s,3,'VEC3',target=34962)}
             for s in morphs]
    for part in parts:
        name=part['extras']['stkMuscleRegion']
        part['attributes']=dict(attr)
        part['targets']=copy.deepcopy(targets)
        part['indices']=glb.append(regions[name],1,'SCALAR',component=5123,
                                   target=34963)
    glb.doc['extras']=dict(glb.doc['extras'],
        anatomyAuthoringVersion=914,authoringHighResolution=True,
        sourceAuthoringSha256=hashlib.sha256(raw).hexdigest(),
        authoringLODs=['v8_mobile_unchanged','v914_subdivided_offline'],
        approved=False,enabled=False,expertAnatomyReviewed=False,
        physicalDeviceMeasured=False)
    if (glb.doc['skins']!=old_skins or glb.doc['nodes']!=old_nodes or
        glb.doc['animations']!=old_clips):
        raise ValueError('Skeleton, rig hierarchy or clips changed')
    result=glb.bytes()
    if len(result)>MAX_BYTES:raise ValueError('Authoring GLB over 6 MiB')
    report={'version':914,'exerciseId':exercise,'sourceVertices':len(p),
        'newVertices':len(vertices),'newMidpoints':len(edges),
        'originalTriangles':len(triangles),'highResolutionTriangles':faces,
        'regions':{name:len(indices)//3 for name,indices in regions.items()},
        'maxMidpointCurvatureMeters':round(max_curve,7),
        'curvatureSuppressedEdges':len(suppressed),
        'maxDroppedInfluence':round(max_lost,6),
        'sourceBytes':len(raw),'authoringBytes':len(result),
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(result).hexdigest(),
        'jointCount':55,'morphTargetCount':8,'triangleFlips':flip_count,
        'approved':False,'enabled':False,'deviceValidated':False,
        'professionalAnatomy':False,'productionAsset':False}
    return result,report


def build(master,pilots,output):
    root=Path(output);root.mkdir(parents=True,exist_ok=True)
    inputs=[(None,Path(master),'stk_master_v914_high_res_authoring.glb')]
    inputs +=[(ex,Path(pilots)/(ex+'_master55_v8_sculpt_qa.glb'),
              ex+'_master55_v914_high_res_qa.glb') for ex in EXERCISE_IDS]
    reports=[]
    for exercise,path,name in inputs:
        data,report=subdivide(path.read_bytes(),exercise)
        (root/name).write_bytes(data)
        reports.append(report)
    summary={'schema':'stk_anatomy_v914_high_res_unapproved',
        'catalogCount':229,'approved':False,'enabled':False,
        'physicalDeviceValidated':False,'expertAnatomyReviewed':False,
        'source':'CC0-master55-v8','assets':reports,
        'limitations':['Subdivision does not invent missing muscle insertions',
            'Equipment contact and human motion still preliminary',
            'Authoring GLBs exceed mobile size/triangle budgets',
            'Need artist retopology, anatomical QA and measured device review']}
    (root/'high_res_authoring_v914_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('--master',type=Path,required=True)
    ap.add_argument('--pilots',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args()
    print(json.dumps(build(args.master,args.pilots,args.output),indent=2))
