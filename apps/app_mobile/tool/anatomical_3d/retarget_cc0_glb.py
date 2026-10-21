#!/usr/bin/env python3
"""Retarget three exercise guides onto the original, hash-pinned CC0 53-joint human.

This is an INTERNAL preview generator, not an approved biomechanical animation.
Retains source mesh/skin data and adds glTF animation, highlighted triangles,
and a rigid exercise bar. No Blender/dependencies or network in this step.
"""
from __future__ import annotations
import argparse, copy, hashlib, json, math, struct
from pathlib import Path

EXERCISES = ('ex_bench_press', 'ex_barbell_row', 'ex_squat')
SOURCE_SHA = '7135e03b6259e970458deff3e0458610914d7c35164cae12611101361e4a5749'
FRAMES = 41  # 10 fps keyframes; interpolation by glTF native runtime
EPS = 1e-9


def add(a,b): return tuple(x+y for x,y in zip(a,b))
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def mul(a,k): return tuple(x*k for x in a)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a): return math.sqrt(dot(a,a))
def unit(a):
    v=norm(a)
    if v<EPS: raise ValueError('Degenerate IK or rotation axis')
    return mul(a,1/v)
def qnorm(q): return mul(q,1/norm(q))
def qconj(q): return (-q[0],-q[1],-q[2],q[3])
def qmul(a,b):
    x,y,z,w=a; X,Y,Z,W=b
    return (w*X+x*W+y*Z-z*Y, w*Y-x*Z+y*W+z*X,
            w*Z+x*Y-y*X+z*W, w*W-x*X-y*Y-z*Z)
def qrot(q,v):
    d=mul(cross(q[:3],v),2)
    return add(v,add(mul(d,q[3]),cross(q[:3],d)))
def qx(t): return (math.sin(t*.5),0,0,math.cos(t*.5))
def qbetween(a,b):
    a=unit(a);b=unit(b);v=cross(a,b);t=1+dot(a,b)
    if t<EPS:
        ref=(0,0,1) if abs(a[2])<.8 else (0,1,0)
        return (*unit(cross(a,ref)),0)
    return qnorm((*v,t))
def ease(t):
    t=max(0,min(1,t));return t*t*(3-2*t)
def motion(t):
    if t<=.10 or t>=.96:return 0
    if t<.48:return ease((t-.10)/.38)
    if t<.58:return 1
    return 1-ease((t-.58)/.38)

class GLB:
    def __init__(self,data,expected_sha=SOURCE_SHA):
        if expected_sha is not None and hashlib.sha256(data).hexdigest()!=expected_sha:
            raise ValueError('Source CC0 rig SHA256 does not match verified artifact')
        if data[:4]!=b'glTF' or struct.unpack_from('<II',data,4)!=(2,len(data)):
            raise ValueError('Invalid GLB')
        n,kind=struct.unpack_from('<I4s',data,12)
        if kind!=b'JSON':raise ValueError('Missing JSON')
        self.doc=json.loads(data[20:20+n]);self.binary=bytearray(data[28+n:])
        self.nodes=self.doc['nodes'];self.by_name={node.get('name'):i for i,node in enumerate(self.nodes)}
        self.parents={k:i for i,n in enumerate(self.nodes) for k in n.get('children',[])}
        self.restpos={};self.restrot={}
        for i in range(len(self.nodes)):
            self.fk(i,{},self.restpos,self.restrot)
        self.restpos={i:self.restpos[i][0] for i in range(len(self.nodes))}
        self.restrot={i:self.restrot[i][0] for i in range(len(self.nodes))}
    def fk(self,index,local,pos,rot):
        if index in pos:return pos[index][0],rot[index][0]
        n=self.nodes[index];p=tuple(n.get('translation',(0,0,0)))
        q=tuple(n.get('rotation',(0,0,0,1)))
        t,u=local.get(index,(p,q))
        parent=self.parents.get(index)
        if parent is None:
            out=t;angle=u
        else:
            pt,pq=self.fk(parent,local,pos,rot)
            out=add(pt,qrot(pq,t));angle=qmul(pq,u)
        pos[index]=(out,);rot[index]=(qnorm(angle),)
        return out,rot[index][0]
    def world(self,local):
        pos={};rot={}
        for idx in range(len(self.nodes)):
            self.fk(idx,local,pos,rot)
        return {i:pos[i][0] for i in pos},{i:rot[i][0] for i in rot}
    def accessor(self,index):
        a=self.doc['accessors'][index]
        v=self.doc['bufferViews'][a['bufferView']]
        components={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}
        fmt,byte=components[a['componentType']]
        length={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        start=v.get('byteOffset',0)+a.get('byteOffset',0)
        flat=struct.unpack_from('<'+str(a['count']*length)+fmt,self.binary,start)
        return [tuple(flat[x:x+length]) for x in range(0,len(flat),length)]
    def append(self,items,length,kind,component=5126,target=None):
        if not items: raise ValueError('No output data')
        fmt={5126:'f',5125:'I',5123:'H'}[component]
        flat=[v for value in items for v in (value if isinstance(value,(list,tuple)) else (value,))]
        assert len(flat)==len(items)*length
        while len(self.binary)%4:self.binary.append(0)
        start=len(self.binary)
        self.binary.extend(struct.pack('<'+str(len(flat))+fmt,*flat))
        view={'buffer':0,'byteOffset':start,'byteLength':len(self.binary)-start}
        if target:view['target']=target
        vi=len(self.doc['bufferViews']);self.doc['bufferViews'].append(view)
        a={'bufferView':vi,'componentType':component,'count':len(items),'type':
            {1:'SCALAR',3:'VEC3',4:'VEC4',16:'MAT4'}[length]}
        ai=len(self.doc['accessors']);self.doc['accessors'].append(a)
        return ai
    def bytes(self):
        self.doc['buffers'][0]['byteLength']=len(self.binary)
        raw=json.dumps(self.doc,ensure_ascii=False,separators=(',',':')).encode()
        raw+=b' ' * ((-len(raw))%4)
        self.binary.extend(b'\0'*((-len(self.binary))%4))
        total=12+8+len(raw)+8+len(self.binary)
        return struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(raw),b'JSON')+raw+struct.pack('<I4s',len(self.binary),b'BIN\x00')+bytes(self.binary)


def ik_point(a,target,upper,lower,pole):
    ray=sub(target,a);length=norm(ray)
    if length<abs(upper-lower)+.0001 or length>upper+lower-.0001:
        raise ValueError('Unreachable IK: distance %.4f, combined %.4f'%(length,upper+lower))
    axis=unit(ray)
    projection=sub(pole,mul(axis,dot(pole,axis)))
    f=(upper*upper-lower*lower+length*length)/(2*length)
    h=math.sqrt(max(0,upper*upper-f*f))
    return add(a,add(mul(axis,f),mul(unit(projection),h)))


def adjust_bone(glb,local,bone_name,child_name,target):
    idx=glb.by_name[bone_name]; child=glb.by_name[child_name]
    pos,rot=glb.world(local)
    shift=qbetween(sub(pos[child],pos[idx]),sub(target,pos[idx]))
    new_world=qmul(shift,rot[idx])
    p=glb.parents[idx]
    local_r=qnorm(qmul(qconj(rot[p]),new_world))
    rest_t=tuple(glb.nodes[idx].get('translation',(0,0,0)))
    local[idx]=(rest_t,local_r)


def set_world_rotation(glb,local,name,target_world):
    i=glb.by_name[name]
    _,rot=glb.world(local)
    par=glb.parents[i]
    rest_t=tuple(glb.nodes[i].get('translation',(0,0,0)))
    local[i]=(rest_t,qnorm(qmul(qconj(rot[par]),target_world)))


def body_pose(glb,exercise,t):
    p=motion(t/4.)
    if exercise==EXERCISES[0]:
        orientation=qx(-1.27);target_hip=(0,.79,0)
    elif exercise==EXERCISES[1]:
        orientation=qx(.85);target_hip=(0,.82,0)
    else:
        orientation=qx(.08*p);target_hip=(0,.89-.34*p,-.12*p)
    container=glb.by_name['Avery | anatomical body.rig'];pelvis=glb.by_name['pelvis']
    rest=glb.restpos[pelvis]
    translation=sub(target_hip,qrot(orientation,rest))
    loc={container:(translation,orientation)}
    if exercise==EXERCISES[0]:
        bar=(0,1.22-.27*p,-.46)
    elif exercise==EXERCISES[1]:
        bar=(0,.77+.25*p,.48-.12*p)
    else:
        bar=(0,1.32-.33*p,-.08-.11*p)
    foot_y=.069
    for side,sign in [('l',1),('r',-1)]:
        thigh,calf,foot,ball=('thigh_'+side,'calf_'+side,'foot_'+side,'ball_'+side)
        pos,_=glb.world(loc)
        hip=pos[glb.by_name[thigh]]
        restfoot=glb.restpos[glb.by_name[foot]]
        foot_target=(restfoot[0],foot_y,
                     (.20 if exercise==EXERCISES[0] else .10 if exercise==EXERCISES[1] else restfoot[2]))
        knee_target=ik_point(hip,foot_target,
                  norm(sub(glb.restpos[glb.by_name[calf]],glb.restpos[glb.by_name[thigh]])),
                  norm(sub(glb.restpos[glb.by_name[foot]],glb.restpos[glb.by_name[calf]])),
                  (0,0,1))
        adjust_bone(glb,loc,thigh,calf,knee_target)
        adjust_bone(glb,loc,calf,foot,foot_target)
        # Keep soles parallel to floor, preserve orientation of all 10 toe nodes.
        set_world_rotation(glb,loc,foot,glb.restrot[glb.by_name[foot]])
    for side,sign in [('l',1),('r',-1)]:
        upper,lower,hand=('upperarm_'+side,'lowerarm_'+side,'hand_'+side)
        pos,_=glb.world(loc)
        shoulder=pos[glb.by_name[upper]]
        grip=(sign*(.52 if exercise!=EXERCISES[2] else .51),bar[1],bar[2])
        elbow=ik_point(shoulder,grip,
                 norm(sub(glb.restpos[glb.by_name[lower]],glb.restpos[glb.by_name[upper]])),
                 norm(sub(glb.restpos[glb.by_name[hand]],glb.restpos[glb.by_name[lower]])),
                 (sign*.25,-.4,.7 if exercise==EXERCISES[0] else -.5))
        adjust_bone(glb,loc,upper,lower,elbow)
        adjust_bone(glb,loc,lower,hand,grip)
    pos,_=glb.world(loc)
    diagnostics={'gripErrorMeters':max(norm(sub(pos[glb.by_name['hand_'+s]],
                         ((1 if s=='l' else -1)*(.52 if exercise!=EXERCISES[2] else .51),bar[1],bar[2]))) for s in ('l','r')),
                 'footErrorMeters':max(norm(sub(pos[glb.by_name['foot_'+s]],
                         (glb.restpos[glb.by_name['foot_'+s]][0],foot_y,
                          (.20 if exercise==EXERCISES[0] else .10 if exercise==EXERCISES[1] else glb.restpos[glb.by_name['foot_'+s]][2])))) for s in ('l','r'))}
    return loc,bar,diagnostics


def highlight_regions(glb,exercise):
    """Partition original surface triangles by approximate resting anatomical area."""
    mesh=glb.doc['meshes'][0];primitive=mesh['primitives'][0]
    original_material=glb.doc['materials'][0]
    original_material['name']='STK_BODY'
    original_material['extras']={'stkMuscleRole':'body'}
    points=glb.accessor(primitive['attributes']['POSITION'])
    indices=glb.accessor(primitive['indices']);roles={'body':[],'primary':[],'secondary':[]}
    for aa,bb,cc in (indices[x:x+3] for x in range(0,len(indices),3)):
        a,b,c=(int(aa[0]),int(bb[0]),int(cc[0]))
        x,y,z=(sum(points[j][axis] for j in (a,b,c))/3 for axis in range(3))
        xx=abs(x)
        if exercise==EXERCISES[0]:
            active=.04<xx<.31 and 1.09<y<1.41 and z>.08
            secondary=.26<xx<.45 and 1.15<y<1.51 and z>.06
        elif exercise==EXERCISES[1]:
            active=.09<xx<.38 and .98<y<1.38 and z<.045
            secondary=xx<.15 and 1.19<y<1.52 and z<.06
        else:
            active=.10<xx<.32 and .50<y<.88 and z>.04
            secondary=.09<xx<.32 and .75<y<1.03 and z<0
        roles['primary' if active else 'secondary' if secondary else 'body'].extend((a,b,c))
    original=copy.deepcopy(primitive)
    # Keep vertex attributes and original rig weights; split only index buffers.
    mesh['primitives']=[]
    palette={'body':0}
    for label,col in [('primary',[.16,.39,1.,1]),('secondary',[.47,.65,1.,1])]:
        palette[label]=len(glb.doc['materials'])
        glb.doc['materials'].append({'name':'STK_'+label.upper(),
            'extras':{'stkMuscleRole':label},
            'pbrMetallicRoughness':{'baseColorFactor':col,'metallicFactor':0,'roughnessFactor':.78},
            'doubleSided':True})
    for label,values in roles.items():
        if not values:raise ValueError('No '+label+' surface triangles')
        accessor=glb.append(values,1,'SCALAR',component=5125,target=34963)
        out=copy.deepcopy(original);out['indices']=accessor;out['material']=palette[label]
        out['extras']={'stkMuscleRole':label,'anatomicalAccuracy':'approximate_bbox_not_professional_segmentation'}
        mesh['primitives'].append(out)
    return {role:len(values)//3 for role,values in roles.items()}


def equipment(glb):
    """Single rigid bar and weight plates, represented by a low-poly cylinder mesh."""
    positions=[];normals=[];indices=[]
    def cylinder(x0,x1,radius,role):
        first=len(positions);sides=14
        for x in (x0,x1):
            for k in range(sides):
                a=2*math.pi*k/sides
                positions.append((x,math.cos(a)*radius,math.sin(a)*radius))
                normals.append((0,math.cos(a),math.sin(a)))
        for k in range(sides):
            j=(k+1)%sides
            indices.extend([first+k,first+sides+k,first+j,
                            first+j,first+sides+k,first+sides+j])
    cylinder(-1.1,1.1,.019,'bar')
    cylinder(-.93,-.87,.17,'plates')
    cylinder(.87,.93,.17,'plates')
    pos=glb.append(positions,3,'VEC3',target=34962)
    norm=glb.append(normals,3,'VEC3',target=34962)
    idx=glb.append(indices,1,'SCALAR',component=5125,target=34963)
    mat=len(glb.doc['materials'])
    glb.doc['materials'].append({'name':'STK_EQUIPMENT',
        'extras':{'stkMuscleRole':'equipment'},'pbrMetallicRoughness':{
        'baseColorFactor':[.20,.25,.31,1.], 'metallicFactor':.6,'roughnessFactor':.48}})
    mi=len(glb.doc['meshes']);glb.doc['meshes'].append({'name':'STK_BAR_AND_PLATES',
        'primitives':[{'attributes':{'POSITION':pos,'NORMAL':norm},
                       'indices':idx,'material':mat,'mode':4}]})
    ni=len(glb.nodes);glb.nodes.append({'name':'STK_EXERCISE_BAR','mesh':mi})
    glb.doc['scenes'][glb.doc.get('scene',0)]['nodes'].append(ni)
    return ni


def optimized_lod(glb,voxel_size=.017):
    """Create a separate <850 KiB preview GLB using skin-aware voxel clustering.

    Never overwrite the archival full-resolution CC0 surface. This deliberate
    approximation is for mobile renderer benchmarking only; review visual seams.
    """
    from collections import defaultdict
    source=glb.doc
    body=source['meshes'][0]
    attrs=body['primitives'][0]['attributes']
    pos=glb.accessor(attrs['POSITION'])
    nor=glb.accessor(attrs['NORMAL'])
    joints=glb.accessor(attrs['JOINTS_0'])
    weights=glb.accessor(attrs['WEIGHTS_0'])
    remap={};clusters={};mapping=[]
    for i,point in enumerate(pos):
        key=tuple(round(x/voxel_size) for x in point)
        ci=remap.get(key)
        if ci is None:
            ci=len(clusters); remap[key]=ci
            clusters[ci]=[0,[0.,0.,0.],[0.,0.,0.],defaultdict(float)]
        count,pacc,nacc,jacc=clusters[ci]
        clusters[ci][0]+=1
        for axis in range(3):
            pacc[axis]+=point[axis]
            nacc[axis]+=nor[i][axis]
        for joint,weight in zip(joints[i],weights[i]):
            if weight>1e-8:jacc[int(joint)]+=weight
        mapping.append(ci)
    positions=[];normals=[];skinidx=[];skinweights=[]
    for ci,(count,pacc,nacc,jacc) in clusters.items():
        positions.append(tuple(v/count for v in pacc))
        direction=unit(nacc) if norm(nacc)>EPS else (0.,1.,0.)
        normals.append(direction)
        strongest=sorted(jacc.items(),key=lambda x:-x[1])[:4]
        weight_total=sum(w for _,w in strongest)
        if weight_total<=EPS:raise ValueError('Skin vertex has no weights')
        skinidx.append(tuple(k for k,_ in strongest)+(0,)*(4-len(strongest)))
        skinweights.append(tuple(w/weight_total for _,w in strongest)+
                           (0.,)*(4-len(strongest)))
    if len(positions)>12500:raise ValueError('Mobile LOD too many vertices')
    small=object.__new__(GLB)
    small.doc=copy.deepcopy(source)
    small.doc['accessors']=[];small.doc['bufferViews']=[]
    small.binary=bytearray();small.nodes=small.doc['nodes']
    p=small.append(positions,3,'VEC3',target=34962)
    n=small.append(normals,3,'VEC3',target=34962)
    ji=small.append(skinidx,4,'VEC4',component=5123,target=34962)
    ws=small.append(skinweights,4,'VEC4',target=34962)
    frame_data=[]
    triangles=0
    for prim in body['primitives']:
        raw_indices=[int(v[0]) for v in glb.accessor(prim['indices'])]
        reduced=[]
        seen=set()
        for i in range(0,len(raw_indices),3):
            ids=tuple(mapping[raw_indices[k]] for k in range(i,i+3))
            if len(set(ids))!=3 or ids in seen:continue
            seen.add(ids);reduced.extend(ids)
        triangles+=len(reduced)//3
        index=small.append(reduced,1,'SCALAR',component=5123,target=34963)
        frame_data.append({'attributes':{'POSITION':p,'NORMAL':n,
           'JOINTS_0':ji,'WEIGHTS_0':ws},'indices':index,
           'material':prim['material'],'mode':4,
           'extras':copy.deepcopy(prim.get('extras',{}))})
    small.doc['meshes'][0]['primitives']=frame_data
    # Carry over the same rigid bar, plates, and animation channels.
    old_rigid=source['meshes'][1]
    slim_rigid=[]
    for prim in old_rigid['primitives']:
        coord=glb.accessor(prim['attributes']['POSITION'])
        normal=glb.accessor(prim['attributes']['NORMAL'])
        indices=[int(v[0]) for v in glb.accessor(prim['indices'])]
        ap=small.append(coord,3,'VEC3',target=34962)
        an=small.append(normal,3,'VEC3',target=34962)
        ai=small.append(indices,1,'SCALAR',component=5123,target=34963)
        slim_rigid.append({'attributes':{'POSITION':ap,'NORMAL':an},
                 'indices':ai,'material':prim['material'],'mode':4})
    small.doc['meshes'][1]['primitives']=slim_rigid
    old_skin=source['skins'][0]
    ibm=glb.accessor(old_skin['inverseBindMatrices'])
    small.doc['skins'][0]['inverseBindMatrices']=small.append(ibm,16,'MAT4')
    clip=source['animations'][0]
    for sampler in small.doc['animations'][0]['samplers']:
        in_a=source['accessors'][sampler['input']]
        out_a=source['accessors'][sampler['output']]
        def copied(ai,kind):
            inp=glb.accessor(ai)
            return small.append(inp,kind,'VEC4' if kind==4 else 'VEC3' if kind==3 else 'SCALAR')
        sampler['input']=copied(sampler['input'],1)
        sampler['output']=copied(sampler['output'],4 if out_a['type']=='VEC4' else 3)
    small.doc['extras']['mobileLod']=True
    small.doc['extras']['lodVoxelSizeMeters']=voxel_size
    small.doc['extras']['anatomicalAccuracy']='unapproved_clustering'
    raw=small.bytes()
    if len(raw)>850*1024:raise ValueError('LOD too large for current Flutter staging guard')
    return raw,{'bytes':len(raw),'vertices':len(positions),
                'triangles':triangles,'voxelMeters':voxel_size,
                'sha256':hashlib.sha256(raw).hexdigest()}


def retarget(data,exercise):
    if exercise not in EXERCISES:raise ValueError('Unknown stable exercise ID')
    glb=GLB(data)
    # Blender exporter stores tiny float32 scale noise (0.9999998..1.0000001)
    # on most bones; remove it on the REVIEW derivative, not the licensed input.
    # Current Flutter TRS runtime only supports rigid unit-scale joints.
    for node in glb.nodes:
        scale=node.get('scale')
        if scale is not None:
            if len(scale)!=3 or any(abs(float(x)-1.)>.0001 for x in scale):
                raise ValueError('Non-unit CC0 bone scaling needs another runtime')
            del node['scale']
    tris=highlight_regions(glb,exercise)
    bar_node=equipment(glb)
    times=[i*.1 for i in range(FRAMES)]
    tracks={}
    for frame,t in enumerate(times):
        local,bar,errors=body_pose(glb,exercise,t)
        for idx,(pos,rot) in local.items():
            name=glb.nodes[idx]['name'];tracks.setdefault((idx,'rotation'),[]).append(rot)
            if name=='Avery | anatomical body.rig':
                tracks.setdefault((idx,'translation'),[]).append(pos)
        tracks.setdefault((bar_node,'translation'),[]).append(bar)
    time_access=glb.append(times,1,'SCALAR')
    samplers=[];channels=[]
    for (node,path),values in tracks.items():
        # Ensure quaternion hemisphere consistency from frame to frame.
        if path=='rotation':
            for i in range(1,len(values)):
                if dot(values[i-1],values[i])<0:values[i]=mul(values[i],-1)
        values[0]=tuple(values[0]);values[-1]=tuple(values[0])
        ai=glb.append(values,4 if path=='rotation' else 3,'VEC4' if path=='rotation' else 'VEC3')
        samplers.append({'input':time_access,'output':ai,'interpolation':'LINEAR'})
        channels.append({'sampler':len(samplers)-1,'target':{'node':node,'path':path}})
    glb.doc['animations']=[{'name':'STK_'+exercise+'_CC0_REVIEW',
       'channels':channels,'samplers':samplers}]
    glb.doc['extras']={'exerciseId':exercise,'approved':False,'enabled':False,
       'license':'CC0-1.0','sourceSha256':SOURCE_SHA,
       'retarget':'analytic_ik_preliminary_not_biomechanics_approved',
       'anatomicalColors':'approximate_surface_segmentation_not_medically_verified'}
    lod_raw,lod_meta=optimized_lod(glb)
    raw=glb.bytes()
    return raw,lod_raw,{'id':exercise,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),
       'joints':len(glb.doc['skins'][0]['joints']),'frames':FRAMES,
       'durationSeconds':4,'trianglesByRegion':tris,'animations':1,
       'maxGripErrorMetersAtKeyframes':max(body_pose(GLB(data),exercise,t)[2]['gripErrorMeters'] for t in times),
       'maxFootErrorMetersAtKeyframes':max(body_pose(GLB(data),exercise,t)[2]['footErrorMeters'] for t in times),
       'sourceSha256':SOURCE_SHA,'mobileLod':lod_meta,'approved':False,'enabled':False}


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--input',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    data=args.input.read_bytes()
    args.output.mkdir(parents=True,exist_ok=True)
    report=[]
    for exercise in EXERCISES:
        raw,lod,meta=retarget(data,exercise)
        (args.output/(exercise+'.glb')).write_bytes(raw)
        (args.output/(exercise+'_mobile_lod.glb')).write_bytes(lod)
        report.append(meta)
    manifest={'version':4,'sourceModel':'innerscene_cc0_rig53',
         'description':'true 53-joint CC0 mesh with experimental IK and provisional anatomical color segmentation',
         'approved':False,'enabled':False,'catalogCount':229,'pilots':report}
    (args.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
