#!/usr/bin/env python3
"""Offline v6 surface junction smoothing for the disabled CC0 55-joint master.

Blend existing eight LEFT/RIGHT corrective morph deltas across short LOD
triangle edges and coincident UV seams. This is NOT anatomical sculpting,
biomechanics validation or production media.
"""
import argparse
import json
import math
import struct
from pathlib import Path
from retarget_cc0_glb import GLB

MAX_EDGE_METERS=.055
MAX_EDIT_METERS=.0015
MAX_MORPH_METERS=.006
BUDGET_BYTES=850*1024
PASSES=2
RELAXATION=.42
MORPH_NAMES=(
    'scapular_elevation_l','scapular_elevation_r',
    'elbow_flexion_l','elbow_flexion_r',
    'hip_flexion_l','hip_flexion_r',
    'knee_flexion_l','knee_flexion_r',
)

def distance(a,b):
    return math.sqrt(sum((u-v)**2 for u,v in zip(a,b)))

def topology(glb,vertices,joints,skin):
    """Merge short triangle edges and exact shared-position seam vertices."""
    graph=[dict() for _ in vertices]
    def link(i,j,seam=False):
        if i==j:return
        length=distance(vertices[i],vertices[j])
        if length>MAX_EDGE_METERS and not seam:return
        wa={int(b):w for b,w in zip(joints[i],skin[i])}
        overlap=sum(min(w,wa.get(int(b),0)) for b,w
                    in zip(joints[j],skin[j]))
        weight=4. if seam else (0.3+0.7*overlap)*math.exp(
            -.5*(length/.032)**2)
        graph[i][j]=max(weight,graph[i].get(j,0.))
        graph[j][i]=max(weight,graph[j].get(i,0.))
    for primitive in glb.doc['meshes'][0]['primitives']:
        ids=[int(v[0]) for v in glb.accessor(primitive['indices'])]
        if len(ids)%3:raise ValueError('Broken triangle buffer')
        for offset in range(0,len(ids),3):
            a,b,c=ids[offset:offset+3]
            if any(x<0 or x>=len(vertices) for x in (a,b,c)):
                raise ValueError('Out-of-range triangle vertex')
            link(a,b);link(b,c);link(c,a)
    welded={}
    for i,point in enumerate(vertices):
        key=tuple(round(v,5) for v in point)
        group=welded.setdefault(key,[])
        if len(group)>16:raise ValueError('Too many coincident vertices')
        for other in group:link(i,other,seam=True)
        group.append(i)
    return graph

def active_mask(points,name):
    if name.endswith('_l'):return [p[0]>.00001 for p in points]
    if name.endswith('_r'):return [p[0]<-.00001 for p in points]
    raise ValueError('Missing left/right morph suffix')

def edge_gradient(graph,values,active):
    weighted=total=0.
    for i,neighbors in enumerate(graph):
        if not active[i]:continue
        for j,w in neighbors.items():
            if j>i and active[j]:
                weighted+=w*distance(values[i],values[j])
                total+=w
    return weighted/total if total else 0.

def smooth_deltas(graph,points,original,name):
    """Small unilateral updates, without changing vertices or skin weights."""
    if len(graph)!=len(points) or len(original)!=len(points):
        raise ValueError('Unexpected morph length')
    active=active_mask(points,name)
    base=[tuple(map(float,v)) if active[i] else (0.,0.,0.)
          for i,v in enumerate(original)]
    if max(distance(v,(0,0,0)) for v in base)>MAX_MORPH_METERS:
        raise ValueError('Source morph exceeds QA envelope')
    values=base
    for _ in range(PASSES):
        revised=[]
        for i,old in enumerate(values):
            if not active[i]:
                revised.append((0.,0.,0.))
                continue
            edges=[(j,w) for j,w in graph[i].items() if active[j]]
            if not edges:
                revised.append(old)
                continue
            total=sum(w for _,w in edges)
            mean=tuple(sum(values[j][k]*w for j,w in edges)/total
                       for k in range(3))
            candidate=tuple((1-RELAXATION)*old[k]+RELAXATION*mean[k]
                            for k in range(3))
            change=distance(candidate,base[i])
            if change>MAX_EDIT_METERS:
                factor=MAX_EDIT_METERS/change
                candidate=tuple(base[i][k]+factor*(candidate[k]-base[i][k])
                                for k in range(3))
            revised.append(candidate)
        values=revised
    if max(distance(v,(0,0,0)) for v in values)>MAX_MORPH_METERS:
        raise ValueError('Continuity morph exceeds QA envelope')
    return values,{
        'edgeGradientBefore':edge_gradient(graph,base,active),
        'edgeGradientAfter':edge_gradient(graph,values,active),
        'maxEditMeters':max(distance(a,b) for a,b in zip(base,values)),
        'editedVertices':sum(distance(a,b)>1e-7
                             for a,b in zip(base,values)),
    }

def replace_accessor(glb,index,rows):
    accessor=glb.doc['accessors'][index]
    view=glb.doc['bufferViews'][accessor['bufferView']]
    if (accessor['type']!='VEC3' or accessor['componentType']!=5126
        or accessor['count']!=len(rows) or view['buffer']!=0
        or 'byteStride' in view or view['byteLength']<12*len(rows)):
        raise ValueError('Unexpected morph buffer layout')
    offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
    if offset<0 or offset+len(rows)*12>len(glb.binary):
        raise ValueError('Morph writes outside GLB buffer')
    struct.pack_into('<'+str(3*len(rows))+'f',glb.binary,offset,
                     *(item for row in rows for item in row))

def refine(raw):
    glb=GLB(raw,expected_sha=None)
    doc=glb.doc
    extras=doc.get('extras',{})
    meshes=doc.get('meshes',[])
    if (extras.get('masterContactVersion')!=5
        or extras.get('masterCorrectiveDriverVersion')!=2
        or extras.get('approved') is not False
        or extras.get('enabled') is not False
        or len(doc.get('skins',[]))!=1
        or len(doc['skins'][0]['joints'])!=55
        or len(doc.get('animations',[]))!=7
        or len(meshes)!=1 or len(meshes[0]['primitives'])!=12
        or tuple(meshes[0].get('extras',{}).get('targetNames',()))!=MORPH_NAMES):
        raise ValueError('Expected disabled 55-joint CC0 v5.2 contact rig')
    primitives=meshes[0]['primitives']
    attrs=primitives[0]['attributes']
    targets=primitives[0]['targets']
    if len(targets)!=8 or any(p['attributes']!=attrs or p['targets']!=targets
                              for p in primitives):
        raise ValueError('Muscle regions must reuse eight skinned buffers')
    points=glb.accessor(attrs['POSITION'])
    joints=glb.accessor(attrs['JOINTS_0'])
    skin=glb.accessor(attrs['WEIGHTS_0'])
    if not 1000<len(points)<10000 or len(joints)!=len(points) or len(skin)!=len(points):
        raise ValueError('Unexpected CC0 master mobile mesh')
    graph=topology(glb,points,joints,skin)
    metrics={}
    used=set()
    for name,target in zip(MORPH_NAMES,targets):
        index=target['POSITION']
        if index in used:raise ValueError('Shared morph output accessor')
        used.add(index)
        original=glb.accessor(index)
        updated,measure=smooth_deltas(graph,points,original,name)
        replace_accessor(glb,index,updated)
        metrics[name]=measure
    before=sum(m['edgeGradientBefore'] for m in metrics.values())
    after=sum(m['edgeGradientAfter'] for m in metrics.values())
    if before<=0 or after>before*1.02:
        raise ValueError('Junction continuity did not meet QA gate')
    doc['extras']=dict(extras,masterSurfaceContinuityVersion=6,
                       approved=False,enabled=False)
    output=glb.bytes()
    if len(output)>BUDGET_BYTES:raise ValueError('GLB over 850 KiB QA budget')
    report={'version':6,'catalogCount':229,'joints':55,'clips':7,
            'morphTargets':8,'regions':12,'sourceBytes':len(raw),
            'bytes':len(output),'graphEdges':sum(map(len,graph))//2,
            'gradientsBefore':before,'gradientsAfter':after,'morphs':metrics,
            'approved':False,'enabled':False,'reviewOnly':True,
            'anatomyCertified':False}
    return output,report

def build(source,destination):
    raw,report=refine(Path(source).read_bytes())
    output=Path(destination)
    output.mkdir(parents=True,exist_ok=True)
    (output/'stk_master_v6_joint_surface_review.glb').write_bytes(raw)
    (output/'joint_surface_v6_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(build(args.input,args.output),indent=2))
