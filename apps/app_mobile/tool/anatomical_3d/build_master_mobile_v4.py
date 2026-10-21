#!/usr/bin/env python3
"""Review-only master LOD: 55 bones, 7 clips, 8 skinned morph targets."""
import argparse,copy,hashlib,json,math
from collections import defaultdict
from pathlib import Path
from retarget_cc0_glb import GLB

BUDGET=850*1024
VOXELS=(.016,.019,.022,.026,.030,.034)
def unit(v):
    size=math.sqrt(sum(x*x for x in v))
    return tuple(x/size for x in v) if size>1e-8 else (0.,1.,0.)

def generate(data,voxel):
    glb=GLB(data,expected_sha=None)
    doc=glb.doc
    extra=doc.get('extras',{})
    if (extra.get('masterMotionVersion')!=3 or extra.get('approved') is not False or
        extra.get('enabled') is not False or len(doc.get('animations',[]))!=7 or
        len(doc['skins'][0]['joints'])!=55 or len(doc['meshes'])!=1):
        raise ValueError('Expected unapproved master v3 with 55 joints and 7 clips')
    mesh=doc['meshes'][0]
    parts=mesh['primitives']
    if len(parts)!=12 or len(mesh['extras']['targetNames'])!=8:
        raise ValueError('Missing 11 region groups or 8 shape keys')
    attrs=parts[0]['attributes']
    p=glb.accessor(attrs['POSITION']);n=glb.accessor(attrs['NORMAL'])
    j=glb.accessor(attrs['JOINTS_0']);w=glb.accessor(attrs['WEIGHTS_0'])
    shapes=[glb.accessor(t['POSITION']) for t in parts[0]['targets']]
    if len(p)!=70985 or len(shapes)!=8:
        raise ValueError('Source CC0 vertex or morph count changed')
    if any(x['attributes']!=attrs or x.get('targets')!=parts[0]['targets'] for x in parts):
        raise ValueError('Regions no longer share skin/morph buffers')
    lookup={};clusters=[];mapping=[]
    for index,point in enumerate(p):
        dominant=j[index][max(range(4),key=lambda k:w[index][k])]
        key=(*(round(x/voxel) for x in point),int(dominant))
        ci=lookup.get(key)
        if ci is None:
            ci=len(clusters);lookup[key]=ci
            clusters.append([0,[0.,0.,0.],[0.,0.,0.],defaultdict(float),
                             [[0.,0.,0.] for _ in range(8)]])
        c,pa,na,wa,morph=clusters[ci]
        clusters[ci][0]+=1
        for axis in range(3):
            pa[axis]+=point[axis];na[axis]+=n[index][axis]
        for bone,strength in zip(j[index],w[index]):
            wa[int(bone)]+=strength
        for m in range(8):
            for axis in range(3):morph[m][axis]+=shapes[m][index][axis]
        mapping.append(ci)
    if not 1200<=len(clusters)<=12500:raise ValueError('LOD vertex budget')
    positions=[];normals=[];jointids=[];weights=[];deltas=[[] for _ in range(8)]
    for count,pa,na,wa,morph in clusters:
        positions.append(tuple(v/count for v in pa))
        normals.append(unit(na))
        top=sorted(wa.items(),key=lambda v:(-v[1],v[0]))[:4]
        total=sum(strength for _,strength in top)
        jointids.append(tuple([i for i,_ in top]+[0]*(4-len(top))))
        weights.append(tuple([strength/total for _,strength in top]+
                             [0.]*(4-len(top))))
        for m in range(8):
            deltas[m].append(tuple(value/count for value in morph[m]))
    compact=object.__new__(GLB)
    compact.doc=copy.deepcopy(doc)
    compact.doc['accessors']=[];compact.doc['bufferViews']=[]
    compact.binary=bytearray();compact.nodes=compact.doc['nodes']
    ap=compact.append(positions,3,'VEC3',target=34962)
    an=compact.append(normals,3,'VEC3',target=34962)
    aj=compact.append(jointids,4,'VEC4',component=5123,target=34962)
    aw=compact.append(weights,4,'VEC4',target=34962)
    targets=[{'POSITION':compact.append(m,3,'VEC3',target=34962)} for m in deltas]
    triangles=0
    for part,original in zip(compact.doc['meshes'][0]['primitives'],parts):
        source=[int(v[0]) for v in glb.accessor(original['indices'])]
        selected=[];seen=set()
        for index in range(0,len(source),3):
            triple=tuple(mapping[source[index+k]] for k in range(3))
            if len(set(triple))!=3 or triple in seen:continue
            seen.add(triple);selected.extend(triple)
        if len(selected)<30:
            raise ValueError('Lost anatomical region '+part['extras']['stkMuscleRegion'])
        triangles+=len(selected)//3
        part['attributes']={'POSITION':ap,'NORMAL':an,'JOINTS_0':aj,'WEIGHTS_0':aw}
        part['indices']=compact.append(selected,1,'SCALAR',component=5123,target=34963)
        part['targets']=copy.deepcopy(targets)
    if triangles>25000:raise ValueError('LOD triangle budget')
    compact.doc['skins'][0]['inverseBindMatrices']=compact.append(
         glb.accessor(doc['skins'][0]['inverseBindMatrices']),16,'MAT4')
    copied={}
    for clip in compact.doc['animations']:
        for sampler in clip['samplers']:
            for field in ('input','output'):
                original=sampler[field]
                if original not in copied:
                    kind=doc['accessors'][original]['type']
                    dimension={'SCALAR':1,'VEC3':3,'VEC4':4}[kind]
                    copied[original]=compact.append(glb.accessor(original),dimension,kind)
                sampler[field]=copied[original]
    compact.doc['extras']=dict(extra,masterMobileVersion=4,mobileLod=True,
        sourceMasterMotionSha256=hashlib.sha256(data).hexdigest(),
        voxelSizeMeters=voxel,approved=False,enabled=False)
    out=compact.bytes()
    original_max=[max(math.dist((0,0,0),v) for v in m) for m in shapes]
    lod_max=[max(math.dist((0,0,0),v) for v in m) for m in deltas]
    report={'sourceBytes':len(data),'lodBytes':len(out),
        'ratio':round(len(out)/len(data),4),'vertices':len(clusters),
        'triangles':triangles,'voxelMeters':voxel,
        'maxClusterErrorMeters':round(max(math.dist(point,positions[mapping[i]])
                                         for i,point in enumerate(p)),5),
        'jointCount':55,'clipCount':7,'morphTargetCount':8,'regionCount':12,
        'morphAmplitudeRatios':[round(b/a,4) for a,b in zip(original_max,lod_max)],
        'approved':False,'enabled':False,'catalogCount':229,'reviewOnly':True}
    return out,report

def build(source,destination):
    data=Path(source).read_bytes()
    attempts=[]
    for voxel in VOXELS:
        try:
            raw,report=generate(data,voxel)
            if len(raw)<=BUDGET:break
            attempts.append((voxel,len(raw)))
        except ValueError as e:attempts.append((voxel,str(e)))
    else:raise ValueError('Cannot meet LOD budget: '+repr(attempts))
    out=Path(destination);out.mkdir(parents=True,exist_ok=True)
    (out/'stk_master_v4_mobile_morph_lod_unapproved.glb').write_bytes(raw)
    (out/'mobile_master_v4_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(build(args.input,args.output),indent=2))
