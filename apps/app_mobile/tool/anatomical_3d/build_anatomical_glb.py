#!/usr/bin/env python3
"""Generate three OFFLINE experimental animated glTF 2.0 rigs (GLB).

STK Haven anatomical v3 pipeline prototype. Copyright (c) STK Haven.
Procedural stylized muscle geometry, *not* a professionally sculpted human.
No external packages, external 3D assets, textures, network, or GIFs.
Exports proper glTF skin weights, joint transforms, and animation clips.
"""
from __future__ import annotations
import argparse
import json
import math
import struct
from pathlib import Path

IDS = ('ex_bench_press', 'ex_barbell_row', 'ex_squat')
SIDES = ('L', 'R')
PI = math.pi
# Absolute bone origin in bind pose (Y up, metres); anatomy proportions shared.
BONES = [
    ('pelvis', None, (0, 1.00, 0)),
    ('spine', 'pelvis', (0, 1.23, 0)),
    ('chest', 'spine', (0, 1.51, 0)),
    ('neck', 'chest', (0, 1.73, 0)),
    ('head', 'neck', (0, 1.89, 0)),
]
for suffix, sign in (('L', -1), ('R', 1)):
    BONES += [
        (f'clavicle_{suffix}', 'chest', (sign*.20, 1.55, 0)),
        (f'upper_arm_{suffix}', f'clavicle_{suffix}', (sign*.34, 1.49, .01)),
        (f'forearm_{suffix}', f'upper_arm_{suffix}', (sign*.57, 1.18, .02)),
        (f'hand_{suffix}', f'forearm_{suffix}', (sign*.75, .94, .04)),
        (f'thigh_{suffix}', 'pelvis', (sign*.18, .99, 0)),
        (f'shin_{suffix}', f'thigh_{suffix}', (sign*.18, .52, .03)),
        (f'foot_{suffix}', f'shin_{suffix}', (sign*.18, .11, .08)),
    ]
INDEX = {item[0]:i for i,item in enumerate(BONES)}
BIND = {item[0]:item[2] for item in BONES}


def lerp(a,b,t):return a+(b-a)*t

def qx(angle):return (math.sin(angle/2),0,0,math.cos(angle/2))
def qz(angle):return (0,0,math.sin(angle/2),math.cos(angle/2))

def smooth(t):
    t=max(0.,min(1.,t))
    return t*t*(3-2*t)

def phase(t):
    if t<=.10 or t>=.96:return 0.
    if t<.48:return smooth((t-.10)/.38)
    if t<.58:return 1.
    return 1.-smooth((t-.58)/.38)

class Bin:
    def __init__(self):
        self.data=bytearray()
        self.views=[]
        self.accessors=[]
    def pack(self,values,fmt,n,component,ty,target=None):
        start=len(self.data)
        self.data.extend(struct.pack('<'+fmt*len(values),*values))
        while len(self.data)%4:self.data.append(0)
        view={'buffer':0,'byteOffset':start,'byteLength':len(self.data)-start}
        if target:view['target']=target
        view_i=len(self.views)
        self.views.append(view)
        accessor={'bufferView':view_i,'componentType':component,'count':n,'type':ty}
        if values and ty=='VEC3' and component==5126:
            points=list(zip(*(iter(values),)*3))
            accessor['min']=[min(p[i] for p in points) for i in range(3)]
            accessor['max']=[max(p[i] for p in points) for i in range(3)]
        self.accessors.append(accessor)
        return len(self.accessors)-1
    def f32(self,items,dim=1):
        flat=[float(v) for p in items for v in (p if isinstance(p,(list,tuple)) else (p,))]
        return self.pack(flat,'f',len(items),5126,('SCALAR','VEC2','VEC3','VEC4','MAT4')[{1:0,2:1,3:2,4:3,16:4}[dim]],34962)
    def u16(self,items,dim=1,indices=False):
        flat=[int(v) for p in items for v in (p if isinstance(p,(list,tuple)) else (p,))]
        assert all(0<=x<65536 for x in flat)
        return self.pack(flat,'H',len(items),5123,{1:'SCALAR',4:'VEC4'}[dim],34963 if indices else 34962)

class Geometry:
    def __init__(self):
        self.primitives=[]
        self.total_vertices=0
        self.triangles=0
    def add(self,name,positions,faces,role,anchor=None,weights=None):
        assert len(positions)<65535 and len(faces)>0
        normal=[[0.0,0.0,0.0] for _ in positions]
        for a,b,c in faces:
            pa,pb,pc=positions[a],positions[b],positions[c]
            ab=[pb[i]-pa[i] for i in range(3)]
            ac=[pc[i]-pa[i] for i in range(3)]
            v=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
            for k in (a,b,c):
                for i in range(3):normal[k][i]+=v[i]
        normals=[]
        for n in normal:
            mag=math.sqrt(sum(x*x for x in n)) or 1
            normals.append(tuple(x/mag for x in n))
        if weights is None:
            weights=[[(anchor or 'pelvis',1.)] for _ in positions]
        blend=[]
        for row in weights:
            total=sum(w for _,w in row)
            assert total>0
            row=[(INDEX[j],w/total) for j,w in row]
            row=row[:4]
            blend.append((tuple(x for x,_ in row)+(0,)*(4-len(row)),
                         tuple(w for _,w in row)+(0.,)*(4-len(row))))
        self.primitives.append((name,positions,normals,faces,role,blend))
        self.total_vertices+=len(positions)
        self.triangles+=len(faces)


def ellipsoid(g,name,center,radii,role,anchor,segments=20,rings=10,rotate_x=0):
    positions=[]
    for row in range(rings+1):
        polar=PI*row/rings
        for col in range(segments):
            az=2*PI*col/segments
            x=radii[0]*math.sin(polar)*math.cos(az)
            y=radii[1]*math.cos(polar)
            z=radii[2]*math.sin(polar)*math.sin(az)
            positions.append((center[0]+x,center[1]+y*math.cos(rotate_x)-z*math.sin(rotate_x),
                              center[2]+y*math.sin(rotate_x)+z*math.cos(rotate_x)))
    faces=[]
    for row in range(rings):
        for col in range(segments):
            a=row*segments+col;b=row*segments+(col+1)%segments
            c=(row+1)*segments+col;d=(row+1)*segments+(col+1)%segments
            if row>0:faces.append((a,b,c))
            if row<rings-1:faces.append((b,d,c))
    g.add(name,positions,faces,role,anchor)


def loft(g,name,rings,role,anchors,segments=20):
    """Skin loft: (Y, X-center, Z-center, radius-X, radius-Z), blended bones."""
    verts=[];skin=[]
    for ri,(y,cx,cz,rx,rz) in enumerate(rings):
        for col in range(segments):
            angle=2*PI*col/segments
            # Muscle volume asymmetry, continuous circumference; no planar cutouts.
            bulge=1.+.025*math.sin(6*angle)*math.sin(PI*ri/max(1,len(rings)-1))
            verts.append((cx+rx*math.cos(angle)*bulge,y,cz+rz*math.sin(angle)*bulge))
            skin.append(anchors[ri])
    faces=[]
    for ri in range(len(rings)-1):
        for col in range(segments):
            a=ri*segments+col;b=ri*segments+(col+1)%segments
            c=(ri+1)*segments+col;d=(ri+1)*segments+(col+1)%segments
            faces.extend([(a,b,c),(b,d,c)])
    # Thin closures keep the mesh connected but avoid zero-radius degenerate poles.
    g.add(name,verts,faces,role,weights=skin)


def tube(g,name,a,b,radii,role,joint_a,joint_b,sections=10,segments=16):
    """Cylinder-like elliptical skinned limb, 2-bone weighted through joint."""
    dx=[b[i]-a[i] for i in range(3)]
    mag=math.sqrt(sum(t*t for t in dx))
    direction=[v/mag for v in dx]
    # Stable cross section basis avoiding parallel vectors.
    guide=(0,0,1) if abs(direction[2])<.85 else (0,1,0)
    ex=[direction[1]*guide[2]-direction[2]*guide[1],
        direction[2]*guide[0]-direction[0]*guide[2],
        direction[0]*guide[1]-direction[1]*guide[0]]
    norm=math.sqrt(sum(x*x for x in ex))
    ex=[v/norm for v in ex]
    ey=[direction[1]*ex[2]-direction[2]*ex[1],
        direction[2]*ex[0]-direction[0]*ex[2],
        direction[0]*ex[1]-direction[1]*ex[0]]
    verts=[];skins=[]
    for r in range(sections+1):
        t=r/sections
        center=[lerp(a[i],b[i],t) for i in range(3)]
        width=lerp(radii[0],radii[1],t)*(1.+.10*math.sin(2*PI*t))
        for c in range(segments):
            ang=2*PI*c/segments
            verts.append(tuple(center[k]+width*(math.cos(ang)*ex[k]+.8*math.sin(ang)*ey[k]) for k in range(3)))
            skins.append([(joint_a,1-smooth(t)),(joint_b,smooth(t))])
    faces=[]
    for r in range(sections):
        for c in range(segments):
            a0=r*segments+c;b0=r*segments+(c+1)%segments
            c0=(r+1)*segments+c;d0=(r+1)*segments+(c+1)%segments
            faces.extend([(a0,b0,c0),(b0,d0,c0)])
    g.add(name,verts,faces,role,weights=skins)


def humanoid(which):
    g=Geometry()
    # Torso shape continuous from iliac crest through ribs / trapezius to neck.
    rings=[(.95,0,0,.165,.105),(1.06,0,0,.18,.127),
           (1.17,0,0,.152,.106),(1.30,0,0,.16,.117),
           (1.41,0,0,.22,.139),(1.52,0,0,.258,.156),
           (1.62,0,0,.232,.149),(1.68,0,0,.119,.092)]
    weights=[[('pelvis',1.)],[('pelvis',.8),('spine',.2)],
         [('pelvis',.23),('spine',.77)],[('spine',.8),('chest',.2)],
         [('spine',.37),('chest',.63)],[('chest',1.)],[('chest',.94),('neck',.06)],
         [('neck',1.)]]
    loft(g,'continuous_torso_surface',rings,'body',weights,segments=32)
    ellipsoid(g,'skull_and_face',(0,1.86,.015),(.112,.157,.111),'body','head',24,14)
    ellipsoid(g,'hair_volume',(0,1.965,-.021),(.122,.078,.116),'hair','head')
    ellipsoid(g,'cervical_volume',(0,1.715,.0),(.083,.09,.082),'body','neck')
    for sign,side in [(-1,'L'),(1,'R')]:
        shoulder=BIND['upper_arm_'+side];elbow=BIND['forearm_'+side];
        wrist=BIND['hand_'+side]
        thigh=BIND['thigh_'+side];knee=BIND['shin_'+side];
        ankle=BIND['foot_'+side]
        ellipsoid(g,'deltoid_'+side,(sign*.314,1.53,.013),(.119,.119,.125),
           'secondary' if which!='ex_squat' else 'body','upper_arm_'+side)
        tube(g,'biceps_triceps_'+side,shoulder,elbow,(.092,.081),
             'secondary' if which=='ex_bench_press' else 'body',
             'upper_arm_'+side,'forearm_'+side)
        tube(g,'forearm_'+side,elbow,wrist,(.086,.054),'body','forearm_'+side,'hand_'+side)
        ellipsoid(g,'hand_'+side,wrist,(.060,.080,.054),'body','hand_'+side)
        ellipsoid(g,'gluteus_maximus_'+side,(sign*.153,.99,-.072),(.165,.180,.124),
                  'primary' if which=='ex_squat' else 'body','thigh_'+side)
        tube(g,'upper_leg_'+side,thigh,knee,(.168,.112),'body','thigh_'+side,'shin_'+side)
        tube(g,'lower_leg_'+side,knee,ankle,(.108,.064),'body','shin_'+side,'foot_'+side)
        ellipsoid(g,'rectus_femoris_'+side,(sign*.18,.77,.116),(.109,.218,.049),
                  'primary' if which=='ex_squat' else 'muscle','thigh_'+side)
        ellipsoid(g,'vastus_medialis_'+side,(sign*.112,.63,.10),(.074,.126,.055),
                  'primary' if which=='ex_squat' else 'muscle','thigh_'+side)
        ellipsoid(g,'adductor_'+side,(sign*.104,.83,.023),(.086,.181,.053),
                  'secondary' if which=='ex_squat' else 'muscle','thigh_'+side)
        ellipsoid(g,'calf_'+side,(sign*.18,.36,-.055),(.103,.170,.082),
                  'body','shin_'+side)
        ellipsoid(g,'foot_'+side,(sign*.18,.095,.166),(.113,.067,.242),
                  'shoe','foot_'+side)
        if which=='ex_bench_press':
            ellipsoid(g,'pectoralis_major_'+side,(sign*.116,1.488,.144),
                (.133,.108,.076),'primary','chest')
            ellipsoid(g,'serratus_anterior_'+side,(sign*.197,1.325,.12),
                (.053,.099,.039),'secondary','chest')
        elif which=='ex_barbell_row':
            ellipsoid(g,'latissimus_dorsi_'+side,(sign*.158,1.32,-.144),
                (.114,.23,.062),'primary','spine')
            ellipsoid(g,'rhomboids_'+side,(sign*.083,1.516,-.174),
                (.070,.137,.046),'secondary','chest')
            ellipsoid(g,'trapezius_middle_'+side,(sign*.169,1.603,-.095),
                (.110,.081,.051),'primary','chest')
        else:
            # Abdominal definition in unhighlighted grey.
            for n in range(3):
                ellipsoid(g,'rectus_'+side+'_'+str(n),(sign*.058,1.15+n*.11,.10),
                      (.057,.051,.032),'muscle','spine',16,8)
    return g


def materials():
    colors={
      'body':(.73,.76,.80,1), 'muscle':(.85,.87,.89,1),
      'primary':(.16,.39,1.,1), 'secondary':(.47,.65,1.,1),
      'hair':(.19,.22,.26,1),'shoe':(.26,.29,.33,1),
      'equipment':(.36,.40,.45,1),'plate':(.12,.14,.18,1),
      'cushion':(.19,.20,.23,1)
    }
    return [{'name':'STK_'+key.upper(), 'extras':{'stkMuscleRole':key},
       'pbrMetallicRoughness':{'baseColorFactor':rgba,
           'metallicFactor':.45 if key=='equipment' else 0.,'roughnessFactor':.69}}
       for key,rgba in colors.items()]


def quat_sequence(name,t,exercise):
    q=phase(t/4)
    if name=='pelvis':
        return qx(-PI/2 if exercise==IDS[0] else .94 + .03*q if exercise==IDS[1] else .18*q)
    if name.startswith('upper_arm_'):
        sign=-1 if name.endswith('L') else 1
        return qz(sign*(.75-.12*q) if exercise==IDS[0] else
                  sign*(.16+.39*q) if exercise==IDS[1] else sign*1.02)
    if name.startswith('forearm_'):
        sign=-1 if name.endswith('L') else 1
        return qz(sign*(.10+.93*q) if exercise==IDS[0] else
                  sign*(.18+.94*q) if exercise==IDS[1] else sign*(-.25))
    if name.startswith('thigh_'):
        return qx(1.15 if exercise==IDS[0] else .12 if exercise==IDS[1] else -.84*q)
    if name.startswith('shin_'):
        return qx(-.73 if exercise==IDS[0] else .04 if exercise==IDS[1] else 1.45*q)
    if name.startswith('foot_'):
        return qx(0. if exercise==IDS[0] else -.09 if exercise==IDS[1] else -.62*q)
    return (0,0,0,1)


def bar_translation(exercise,t):
    q=phase(t/4)
    if exercise==IDS[0]:return (0,1.50-.33*q,-.43+.06*q)
    if exercise==IDS[1]:return (0,.63+.42*q,.54-.09*q)
    return (0,1.60-.42*q,-.19-.11*q)


def root_translation(exercise,t):
    q=phase(t/4)
    if exercise==IDS[0]:return (0,.94,0)
    if exercise==IDS[1]:return (0,1.00,0)
    return (0,1.00-.42*q,-.18*q)


def make_glb(exercise):
    if exercise not in IDS:raise ValueError('Unknown stable exercise id')
    geom=humanoid(exercise)
    doc={'asset':{'version':'2.0','generator':'STK Haven anatomical-v3-alpha (unapproved)'},
         'scene':0,'scenes':[{'nodes':[]}],'nodes':[], 'meshes':[], 'skins':[],
         'animations':[], 'materials':materials(), 'accessors':[],
         'bufferViews':[], 'buffers':[],
         'extras':{'approved':False,'enabled':False,'exerciseId':exercise,
                   'source':'procedural mesh prototype, not professionally sculpted',
                   'accentMaterial':'STK_PRIMARY','secondaryMaterial':'STK_SECONDARY'}}
    blob=Bin()
    node_ids={}
    for name,parent,position in BONES:
        origin=BIND[parent] if parent else (0,0,0)
        node_ids[name]=len(doc['nodes'])
        doc['nodes'].append({'name':'SKEL_'+name,
          'translation':[round(position[k]-origin[k],6) for k in range(3)],
          'rotation':[0,0,0,1], 'children':[]})
    for name,parent,_ in BONES:
        if parent:doc['nodes'][node_ids[parent]]['children'].append(node_ids[name])
        else:doc['scenes'][0]['nodes'].append(node_ids[name])
    # A shared skinned mesh with per-muscle materials and 4-influence weights.
    primitives=[]
    palette={m['name'][4:].lower():i for i,m in enumerate(doc['materials'])}
    for name,positions,normals,faces,role,blend in geom.primitives:
        joint_idx=[j for j,_ in blend]
        joint_weight=[w for _,w in blend]
        attrs={'POSITION':blob.f32(positions,3),'NORMAL':blob.f32(normals,3),
               'JOINTS_0':blob.u16(joint_idx,4),'WEIGHTS_0':blob.f32(joint_weight,4)}
        flat=[index for triangle in faces for index in triangle]
        primitives.append({'attributes':attrs,'indices':blob.u16(flat,1,True),
            'material':palette[role],'mode':4,'extras':{'anatomicalRegion':name}})
    doc['meshes'].append({'name':'STK_ANATOMICAL_CONTINUOUS_TORSO_AND_WEIGHTED_LIMBS',
                          'primitives':primitives})
    rootMesh=len(doc['nodes']);doc['nodes'].append({'name':'STK_SKINNED_BODY','mesh':0,'skin':0})
    doc['scenes'][0]['nodes'].append(rootMesh)
    matrices=[]
    for _,_,p in BONES:
        matrices.append((1,0,0,0,0,1,0,0,0,0,1,0,-p[0],-p[1],-p[2],1))
    binds=blob.f32(matrices,16)
    doc['skins'].append({'name':'STK_HUMAN_19_JOINT_SKIN',
             'joints':[node_ids[name] for name,_,_ in BONES],
             'skeleton':node_ids['pelvis'],'inverseBindMatrices':binds})
    # Equipment: geometry is intentionally separate from the skin.
    equipment=Geometry()
    tube(equipment,'bar',( -1.04,0,0),(1.04,0,0),(.017,.017),'equipment','pelvis','pelvis',segments=12)
    for sign in [-1,1]:
        ellipsoid(equipment,'plate_'+str(sign),(sign*.91,0,0),(.049,.165,.165),
                  'plate','pelvis',segments=22)
    # Separate mesh NODE without skin. Strip skin attributes before writing.
    equipPrims=[]
    for name,positions,normals,faces,role,_ in equipment.primitives:
        attrs={'POSITION':blob.f32(positions,3),'NORMAL':blob.f32(normals,3)}
        flat=[n for face in faces for n in face]
        equipPrims.append({'attributes':attrs,'indices':blob.u16(flat,1,True),
                   'material':palette[role],'extras':{'object':name}})
    equipmentIndex=len(doc['meshes'])
    doc['meshes'].append({'name':'STK_BAR_AND_PLATES','primitives':equipPrims})
    barNode=len(doc['nodes']);doc['nodes'].append({'name':'BARBELL_ANIMATED','mesh':equipmentIndex})
    doc['scenes'][0]['nodes'].append(barNode)
    if exercise==IDS[0]:
        bench=Geometry()
        loft(bench,'bench_cushion',[(.83,0,-.7,.23,.17),(.84,0,-.7,.23,.17),
             (.85,0,.36,.23,.17),(.86,0,.36,.23,.17)],'cushion',
             [[('pelvis',1.)] for _ in range(4)])
        # Rest-pose placeholder bench support geometry is rigid, not skinned.
        p0=[]
        for name,pos,norm,faces,role,_ in bench.primitives:
            p0.append({'attributes':{'POSITION':blob.f32(pos,3),'NORMAL':blob.f32(norm,3)},
              'indices':blob.u16([k for f in faces for k in f],1,True),
              'material':palette[role]})
        mesh_index=len(doc['meshes']);doc['meshes'].append({'name':'STK_BENCH','primitives':p0})
        node_index=len(doc['nodes']);doc['nodes'].append({'name':'BENCH_RIGID','mesh':mesh_index})
        doc['scenes'][0]['nodes'].append(node_index)
    times=(0.,.4,.8,1.2,1.6,2.,2.4,2.8,3.2,3.6,4.)
    time_access=blob.f32(times)
    channels=[];samplers=[]
    def add_channel(node,path,frames,dim):
        output=blob.f32(frames,dim)
        si=len(samplers)
        samplers.append({'input':time_access,'output':output,'interpolation':'LINEAR'})
        channels.append({'sampler':si,'target':{'node':node,'path':path}})
    for name,_,_ in BONES:
        if name=='pelvis':
            add_channel(node_ids[name],'translation',[root_translation(exercise,t) for t in times],3)
        if name=='pelvis' or any(name.startswith(prefix) for prefix in
            ('upper_arm_','forearm_','thigh_','shin_','foot_')):
            add_channel(node_ids[name],'rotation',[quat_sequence(name,t,exercise) for t in times],4)
    add_channel(barNode,'translation',[bar_translation(exercise,t) for t in times],3)
    doc['animations']=[{'name':'STK_'+exercise,'channels':channels,'samplers':samplers}]
    doc['accessors']=blob.accessors
    doc['bufferViews']=blob.views
    doc['buffers']=[{'byteLength':len(blob.data)}]
    json_chunk=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode('utf8')
    while len(json_chunk)%4:json_chunk+=b' '
    binary=bytes(blob.data)
    while len(binary)%4:binary+=b'\x00'
    total=12+8+len(json_chunk)+8+len(binary)
    header=struct.pack('<4sII',b'glTF',2,total)
    raw=header+struct.pack('<I4s',len(json_chunk),b'JSON')+json_chunk+struct.pack('<I4s',len(binary),b'BIN\x00')+binary
    return raw,{'id':exercise,'bytes':len(raw),'meshParts':len(primitives),'vertices':geom.total_vertices,
                'triangles':geom.triangles,'bones':len(BONES),'animations':len(doc['animations']),
                'channels':len(channels),'approved':False,'enabled':False}


def extract_glb(raw):
    assert raw[:4]==b'glTF'
    magic,version,size=struct.unpack_from('<4sII',raw,0)
    if version!=2 or size!=len(raw):raise ValueError('invalid GLB header')
    n,kind=struct.unpack_from('<I4s',raw,12)
    if kind!=b'JSON':raise ValueError('missing GLB JSON chunk')
    return json.loads(raw[20:20+n])


def build(output):
    output=Path(output)
    output.mkdir(parents=True,exist_ok=True)
    items=[]
    for name in IDS:
        data,item=make_glb(name)
        (output/(name+'.glb')).write_bytes(data)
        items.append(item)
    manifest={'version':3,'style':'unapproved procedural skinned glTF 2.0 experiment',
       'approved':False,'enabled':False,'catalogCount':229,
       'visualTargetApproved':True,'artApproved':False,
       'qualityGate':'requires professional sculpt, review and mobile renderer',
       'items':items}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
    return manifest

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    print(json.dumps(build(parser.parse_args().output),indent=2))
