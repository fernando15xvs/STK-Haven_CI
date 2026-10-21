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
        orientation=qx(-1.50);target_hip=(0,.74,0)
    elif exercise==EXERCISES[1]:
        orientation=qx(1.15);target_hip=(0,.81,-.02)
    else:
        orientation=qx(.08*p);target_hip=(0,.89-.34*p,-.12*p)
    container=glb.by_name['Avery | anatomical body.rig'];pelvis=glb.by_name['pelvis']
    rest=glb.restpos[pelvis]
    translation=sub(target_hip,qrot(orientation,rest))
    loc={container:(translation,orientation)}
    if exercise==EXERCISES[0]:
        bar=(0,1.13-.27*p,-.37)
    elif exercise==EXERCISES[1]:
        bar=(0,.64+.18*p,.54-.09*p)
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
        grip=(sign*(.50 if exercise!=EXERCISES[2] else .51),bar[1],bar[2])
        elbow=ik_point(shoulder,grip,
                 norm(sub(glb.restpos[glb.by_name[lower]],glb.restpos[glb.by_name[upper]])),
                 norm(sub(glb.restpos[glb.by_name[hand]],glb.restpos[glb.by_name[lower]])),
                 (sign*.25,-.4,.7 if exercise==EXERCISES[0] else -.5))
        adjust_bone(glb,loc,upper,lower,elbow)
        adjust_bone(glb,loc,lower,hand,grip)
    pos,_=glb.world(loc)
    diagnostics={'gripErrorMeters':max(norm(sub(pos[glb.by_name['hand_'+s]],
                         ((1 if s=='l' else -1)*(.50 if exercise!=EXERCISES[2] else .51),bar[1],bar[2]))) for s in ('l','r')),
                 'footErrorMeters':max(norm(sub(pos[glb.by_name['foot_'+s]],
                         (glb.restpos[glb.by_name['foot_'+s]][0],foot_y,
                          (.20 if exercise==EXERCISES[0] else .10 if exercise==EXERCISES[1] else glb.restpos[glb.by_name['foot_'+s]][2])))) for s in ('l','r'))}
    return loc,bar,diagnostics


def highlight_regions(glb,exercise):
    """Keep the original 53-joint skinned vertices and assign REGION groups.

    Each named region has its own primitive/index buffer, with a primary or
    secondary material. Region boundaries remain approximate, not certified.
    """
    from muscle_region_atlas import classify_mesh,EXERCISE_ROLES
    mesh=glb.doc['meshes'][0]
    original=copy.deepcopy(mesh['primitives'][0])
    glb.doc['materials'][0]['name']='STK_BODY'
    glb.doc['materials'][0]['extras']={'stkMuscleRole':'body'}
    palette={'body':0}
    for label,color in [('primary',[.16,.39,1.,1]),
                        ('secondary',[.47,.65,1.,1])]:
        palette[label]=len(glb.doc['materials'])
        glb.doc['materials'].append({'name':'STK_'+label.upper(),
            'extras':{'stkMuscleRole':label},
            'pbrMetallicRoughness':{'baseColorFactor':color,
                'metallicFactor':0,'roughnessFactor':.78},'doubleSided':True})
    groups=classify_mesh(glb,exercise)
    mesh['primitives']=[]
    total={'body':0,'primary':0,'secondary':0}
    census={}
    for (region,role),faces in sorted(groups.items(),
        key=lambda item:(item[0][1]!='body',item[0][0])):
        if not faces:continue
        out=copy.deepcopy(original)
        out['indices']=glb.append(faces,1,'SCALAR',component=5125,target=34963)
        out['material']=palette[role]
        out['extras']={'stkMuscleRegion':region,'stkMuscleRole':role,
            'anatomicalAccuracy':'joint_weight_normal_approximation_not_reviewed'}
        mesh['primitives'].append(out)
        total[role]+=len(faces)//3
        census[region]={'role':role,'triangles':len(faces)//3,
                         'expertApproved':False}
    mesh['extras']={'regionAtlas':'rest_pose_skin_weight_approximation',
                    'reviewedByAnatomist':False,'regions':census}
    return total



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


def add_bench(glb):
    """Stationary flat bench with cushion and supports; never parented to bar."""
    positions=[];normals=[];indices=[];parts=[]
    def box(x0,x1,y0,y1,z0,z1,role):
        corners=[(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
                 (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
        faces=[((3,2,6,7),(0,1,0)),((0,4,5,1),(0,-1,0)),
               ((1,5,6,2),(1,0,0)),((0,3,7,4),(-1,0,0)),
               ((4,7,6,5),(0,0,1)),((0,1,2,3),(0,0,-1))]
        start=len(indices)
        for corners_index,normal in faces:
            n=len(positions)
            positions.extend(corners[i] for i in corners_index)
            normals.extend([normal]*4)
            indices.extend([n,n+1,n+2,n,n+2,n+3])
        parts.append((role,start,len(indices)-start))
    box(-.225,.225,.555,.622,-.89,.40,'cushion')
    box(-.105,.105,.49,.556,-.78,.29,'frame')
    for z in (-.63,.25):
        box(-.13,.13,.07,.50,z-.035,z+.035,'frame')
        box(-.26,.26,.055,.088,z-.08,z+.08,'frame')
    materials={'cushion':len(glb.doc['materials']),
      'frame':next(i for i,v in enumerate(glb.doc['materials'])
                   if v['name']=='STK_EQUIPMENT')}
    glb.doc['materials'].append({'name':'STK_CUSHION',
      'extras':{'stkMuscleRole':'cushion'},'doubleSided':True,
      'pbrMetallicRoughness':{'baseColorFactor':[.16,.18,.23,1],
          'metallicFactor':0.,'roughnessFactor':.86}})
    ap=glb.append(positions,3,'VEC3',target=34962)
    an=glb.append(normals,3,'VEC3',target=34962)
    primitives=[]
    for role,offset,count in parts:
        ai=glb.append(indices[offset:offset+count],1,'SCALAR',component=5125,target=34963)
        primitives.append({'attributes':{'POSITION':ap,'NORMAL':an},
                           'indices':ai,'material':materials[role],'mode':4})
    mesh=len(glb.doc['meshes'])
    glb.doc['meshes'].append({'name':'STK_BENCH_STATIC','primitives':primitives})
    node=len(glb.nodes)
    glb.nodes.append({'name':'STK_BENCH_STATIONARY','mesh':mesh})
    glb.doc['scenes'][glb.doc.get('scene',0)]['nodes'].append(node)
    return node


def curl_grip_fingers(glb):
    """Pose original finger joints to a partial bar grip (not physics-verified).

    Hand position stays driven by the arm IK; this corrects splayed open
    fingers from the otherwise-neutral source mesh.
    """
    for side in ('l','r'):
        for digit in ('index','middle','ring','pinky'):
            for segment,angle in ((1,.73),(2,1.08),(3,1.05)):
                idx=glb.by_name[f'{digit}_0{segment}_{side}']
                node=glb.nodes[idx]
                rest=tuple(node.get('rotation',(0,0,0,1)))
                node['rotation']=list(qnorm(qmul(rest,qx(angle))))
        for segment,angle in ((1,.43),(2,.73),(3,.66)):
            idx=glb.by_name[f'thumb_0{segment}_{side}']
            node=glb.nodes[idx]
            rest=tuple(node.get('rotation',(0,0,0,1)))
            node['rotation']=list(qnorm(qmul(rest,qx(angle))))


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
    # Re-encode ALL unskinned meshes, including barbell and stationary bench.
    for mesh_idx,old_rigid in enumerate(source['meshes'][1:],start=1):
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
        small.doc['meshes'][mesh_idx]['primitives']=slim_rigid
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
    curl_grip_fingers(glb)
    if exercise==EXERCISES[0]: add_bench(glb)
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
