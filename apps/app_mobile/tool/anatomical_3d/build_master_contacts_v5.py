#!/usr/bin/env python3
"""Master 55-bone contact-lab v5: reusable IK end-effector constraints.

Rebuilds seven draft clips on the SAME compact v4 body and morph surfaces.
Both feet are solved to their support targets in leg patterns; hands follow
explicit wrist targets in upper-body patterns. A separate moving bar proxy
illustrates bilateral overhead grip; not bundled with the body in production.
No biomechanical certification, motor control model, collisions or release.
"""
import argparse,copy,hashlib,json,math
from pathlib import Path
from retarget_cc0_glb import (GLB,add,sub,mul,dot,norm,unit,
                              qrot,qconj,qmul,qbetween,qnorm,qx)

FRAMES=41
SIDES=('l','r')
PATTERNS=('overhead_reach_bilateral','unilateral_reach_left',
    'unilateral_reach_right','bilateral_elbow_curl','hip_hinge',
    'squat_articulation','split_lunge_left')
SOURCE_SHA='7135e03b6259e970458deff3e0458610914d7c35164cae12611101361e4a5749'

def smooth(t):
    t=max(0.,min(1.,t))
    return t*t*(3-2*t)

def phase(seconds):
    if seconds<=0 or seconds>=4:return 0.
    if seconds<1.6:return smooth(seconds/1.6)
    if seconds<=2.4:return 1.
    return smooth((4-seconds)/1.6)

def rest(glb,node):
    return (tuple(glb.nodes[node].get('translation',(0,0,0))),
            tuple(glb.nodes[node].get('rotation',(0,0,0,1))))

def shift_world(glb,local,name,delta):
    joint=glb.by_name[name]
    _,rot=glb.world(local)
    parent=glb.parents[joint]
    local_shift=qrot(qconj(rot[parent]),delta)
    origin,rotation=rest(glb,joint)
    local[joint]=(add(origin,local_shift),rotation)

def rotate_local_x(glb,local,name,angle):
    joint=glb.by_name[name]
    origin,rotation=rest(glb,joint)
    local[joint]=(origin,qnorm(qmul(rotation,qx(angle))))

def two_link(glb,local,upper,middle,tip,target,pole):
    """Analytic 3D IK, minimal quaternion swing, exact fingertip/foot target."""
    a,b,c=(glb.by_name[v] for v in (upper,middle,tip))
    positions,_=glb.world(local)
    start=positions[a]
    upper_size=norm(glb.nodes[b]['translation'])
    lower_size=norm(glb.nodes[c]['translation'])
    ray=sub(target,start)
    distance=norm(ray)
    if not abs(upper_size-lower_size)+1e-5<distance<upper_size+lower_size-1e-5:
        raise ValueError('IK out of reach: '+upper+': '+str(round(distance,5)))
    axis=unit(ray)
    along=(distance**2+upper_size**2-lower_size**2)/(2*distance)
    height=math.sqrt(max(0.,upper_size**2-along**2))
    tangent=sub(pole,mul(axis,dot(pole,axis)))
    if norm(tangent)<1e-6:raise ValueError('Ambiguous elbow/knee bend plane')
    midpoint=add(add(start,mul(axis,along)),mul(unit(tangent),height))
    for joint,child,destination in ((a,b,midpoint),(b,c,target)):
        places,quats=glb.world(local)
        original,rotation=rest(glb,joint)
        parent=glb.parents[joint]
        before=qrot(quats[joint],glb.nodes[child]['translation'])
        delta=qbetween(before,sub(destination,places[joint]))
        world_target=qnorm(qmul(delta,quats[joint]))
        local[joint]=(original,qnorm(qmul(qconj(quats[parent]),world_target)))
    # If the endpoint is a planted foot, keep its orientation stable.
    if tip.startswith('foot_'):
        _,quats=glb.world(local)
        origin,_=rest(glb,c)
        local[c]=(origin,qnorm(qmul(qconj(quats[glb.parents[c]]),
                                    glb.restrot[c])))
    result,_=glb.world(local)
    error=norm(sub(result[c],target))
    if error>.0001:raise ValueError('IK contact error '+str(error))
    return error

def targets(glb,kind,side,strength):
    foot=glb.restpos[glb.by_name['foot_'+side]]
    hand=glb.restpos[glb.by_name['hand_'+side]]
    if kind=='split_lunge_left':
        foot=add(foot,(0.,0.,(.35 if side=='l' else -.27)*strength))
    if kind.startswith('overhead') or kind.startswith('unilateral_reach'):
        goal=((.36 if side=='l' else -.36),1.73,.13)
    else:
        goal=((.30 if side=='l' else -.30),1.26,.30)
    return foot,add(mul(hand,1-strength),mul(goal,strength))

def pose(glb,kind,seconds):
    p=phase(seconds)
    local={}
    contact={'feet':{},'hands':{},'targets':{},'strength':round(p,7)}
    if kind=='squat_articulation':
        shift_world(glb,local,'pelvis',(0.,-.24*p,.055*p))
        rotate_local_x(glb,local,'spine_01',.15*p)
    elif kind=='hip_hinge':
        shift_world(glb,local,'pelvis',(0.,-.08*p,-.07*p))
        rotate_local_x(glb,local,'spine_01',.52*p)
    elif kind=='split_lunge_left':
        shift_world(glb,local,'pelvis',(0.,-.20*p,0.))
        rotate_local_x(glb,local,'spine_01',.10*p)
    if kind in ('hip_hinge','squat_articulation','split_lunge_left'):
        for side in SIDES:
            foot,_=targets(glb,kind,side,p)
            root=glb.restpos[glb.by_name['thigh_'+side]]
            mid=glb.restpos[glb.by_name['calf_'+side]]
            pole=sub(mid,root)
            error=two_link(glb,local,'thigh_'+side,'calf_'+side,
                           'foot_'+side,foot,pole)
            contact['feet'][side]=round(error,8)
            contact['targets']['foot_'+side]=foot
    else:
        active=SIDES
        if kind=='unilateral_reach_left':active=('l',)
        if kind=='unilateral_reach_right':active=('r',)
        for side in active:
            _,hand=targets(glb,kind,side,p)
            root=glb.restpos[glb.by_name['upperarm_'+side]]
            mid=glb.restpos[glb.by_name['lowerarm_'+side]]
            pole=sub(mid,root)
            error=two_link(glb,local,'upperarm_'+side,'lowerarm_'+side,
                           'hand_'+side,hand,pole)
            contact['hands'][side]=round(error,8)
            contact['targets']['hand_'+side]=hand
    return local,contact

def pack_motion(raw):
    glb=GLB(raw,expected_sha=None)
    doc=glb.doc;extra=doc.get('extras',{})
    if (extra.get('masterMobileVersion')!=4 or
        extra.get('sourceSha256')!=SOURCE_SHA or
        extra.get('approved') is not False or extra.get('enabled') is not False or
        len(doc['skins'][0]['joints'])!=55 or len(doc['animations'])!=7):
        raise ValueError('Must derive from audited, disabled master v4')
    clips={clip['extras']['pattern']:clip for clip in doc['animations']}
    if set(clips)!=set(PATTERNS):raise ValueError('Unexpected movement templates')
    times=[i/10 for i in range(FRAMES)]
    time_accessor=glb.append(times,1,'SCALAR')
    newclips=[];reports={}
    for kind in PATTERNS:
        samples=[pose(glb,kind,t) for t in times]
        bone_set=set().union(*(set(local) for local,contact in samples))
        samplers=[];channels=[]
        for node in sorted(bone_set):
            fields=[rest(glb,node)[1],rest(glb,node)[0]]
            for path,component,default in (('rotation',4,fields[0]),
                                            ('translation',3,fields[1])):
                values=[local.get(node,rest(glb,node))[0 if path=='translation' else 1]
                        for local,contact in samples]
                if all(max(abs(x-y) for x,y in zip(default,item))<1e-7
                       for item in values):continue
                if path=='rotation':
                    values=list(values)
                    for i in range(1,len(values)):
                        if dot(values[i-1],values[i])<0:
                            values[i]=tuple(-v for v in values[i])
                ai=glb.append(values,component,
                              'VEC4' if component==4 else 'VEC3')
                sample=len(samplers)
                samplers.append({'input':time_accessor,'output':ai,
                                 'interpolation':'LINEAR'})
                channels.append({'sampler':sample,
                                 'target':{'node':node,'path':path}})
        source=clips[kind]
        weights=next(c for c in source['channels'] if c['target']['path']=='weights')
        old=source['samplers'][weights['sampler']]
        si=len(samplers)
        samplers.append(copy.deepcopy(old))
        channels.append({'sampler':si,'target':copy.deepcopy(weights['target'])})
        report={'keyframes':FRAMES,'feet':{},'hands':{},
                'footPlants':kind in ('hip_hinge','squat_articulation','split_lunge_left'),
                'equipmentGrip':kind=='overhead_reach_bilateral',
                'contactIsAnalyticAtKeys':True,
                'certifiedBiomechanics':False,'approved':False,'enabled':False}
        for _,sample in samples:
            for group in ('feet','hands'):
                for side,error in sample[group].items():
                    report[group][side]=max(report[group].get(side,0),error)
        reports[kind]=report
        newclips.append({'name':'STK_MASTER_'+kind+'_UNAPPROVED',
            'channels':channels,'samplers':samplers,
            'extras':dict(source.get('extras',{}),ikConstraintVersion=5,
               exactContactAtKeyframes=True,equipmentGripProxyOnly=
                   kind=='overhead_reach_bilateral',
               biomechanicsReviewed=False,approved=False)})
    doc['animations']=newclips
    doc['extras']=dict(extra,masterContactVersion=5,
        approved=False,enabled=False,contactReviewOnly=True,
        status='geometric_end_effector_constraints_not_coach_certified')
    profile={'version':5,'sourceV4Sha256':hashlib.sha256(raw).hexdigest(),
       'jointCount':55,'clipCount':7,'morphTargetCount':8,
       'catalogCount':229,'approved':False,'enabled':False,
       'patterns':reports,
       'limits':['Contacts exact at sampled keys, interpolate and verify between',
          'Lunge feet reposition before hold; no gait physics',
          'Bar contact uses wrist joints, not exact finger-surface contact',
          'Coach review, equipment collision and anatomy validation pending']}
    return glb.bytes(),profile,glb

def export_proxy(glb):
    """Single separately-rendered overhead bar with animated world translation."""
    clip='overhead_reach_bilateral'
    proxy=object.__new__(GLB)
    proxy.doc={'asset':{'version':'2.0','generator':'STK contact QA v5'},
      'scene':0,'scenes':[{'nodes':[0]}],
      'nodes':[{'name':'STK_OVERHEAD_BAR_PROXY','mesh':0}],
      'meshes':[{'name':'STK_BAR','primitives':[]}],
      'materials':[{'name':'STK_EQUIPMENT',
                    'pbrMetallicRoughness':{'baseColorFactor':[.62,.65,.70,1],
                                          'metallicFactor':.8,'roughnessFactor':.3}}],
      'animations':[],'accessors':[],'bufferViews':[],
      'buffers':[{'byteLength':0}],
      'extras':{'approved':False,'enabled':False,'referenceOnly':True}}
    proxy.binary=bytearray()
    proxy.nodes=proxy.doc['nodes']
    points=[];normals=[];faces=[]
    v=((-0.52,-.014,-.014),(.52,-.014,-.014),(.52,.014,-.014),
       (-.52,.014,-.014),(-.52,-.014,.014),(.52,-.014,.014),
       (.52,.014,.014),(-.52,.014,.014))
    for corners,normal in (((0,1,2,3),(0,0,-1)),((4,7,6,5),(0,0,1)),
        ((0,4,5,1),(0,-1,0)),((3,2,6,7),(0,1,0)),
        ((0,3,7,4),(-1,0,0)),((1,5,6,2),(1,0,0))):
        start=len(points);points.extend(v[i] for i in corners)
        normals.extend([normal]*4)
        faces.extend([start,start+1,start+2,start,start+2,start+3])
    ap=proxy.append(points,3,'VEC3',target=34962)
    an=proxy.append(normals,3,'VEC3',target=34962)
    ai=proxy.append(faces,1,'SCALAR',component=5123,target=34963)
    proxy.doc['meshes'][0]['primitives']=[{
       'attributes':{'POSITION':ap,'NORMAL':an},
       'indices':ai,'material':0,'mode':4}]
    times=[i/10 for i in range(FRAMES)]
    centers=[]
    for t in times:
        strength=phase(t)
        a=targets(glb,clip,'l',strength)[1]
        b=targets(glb,clip,'r',strength)[1]
        centers.append(mul(add(a,b),.5))
    inp=proxy.append(times,1,'SCALAR')
    out=proxy.append(centers,3,'VEC3')
    proxy.doc['animations']=[{'name':'STK_BAR_OVERHEAD_V5_UNAPPROVED',
      'samplers':[{'input':inp,'output':out,'interpolation':'LINEAR'}],
      'channels':[{'sampler':0,'target':{'node':0,'path':'translation'}}]}]
    return proxy.bytes()

def build(input_file,output_folder):
    raw=Path(input_file).read_bytes()
    compiled,manifest,rig=pack_motion(raw)
    destination=Path(output_folder);destination.mkdir(parents=True,exist_ok=True)
    (destination/'stk_master_v5_contact_review.glb').write_bytes(compiled)
    (destination/'stk_overhead_bar_proxy_v5.glb').write_bytes(export_proxy(rig))
    (destination/'master_contacts_v5_report.json').write_text(
        json.dumps(manifest,indent=2)+'\n',encoding='utf8')
    return {'status':'unapproved_contact_qa','bytes':len(compiled),
            'patterns':7,'joints':55,'approved':False,'enabled':False}
if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--input',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    print(json.dumps(build(args.input,args.output),indent=2))
