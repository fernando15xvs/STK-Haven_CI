"""Numerical IK constraints for 3 experimental GLB models, not medical approval."""
import json
import math
import unittest
from pathlib import Path
import build_anatomical_glb as b

FRAMES=tuple(round(n*.4,7) for n in range(11))
SAMPLES=tuple(n*.05 for n in range(81))

def quat_interpolate(a,c,t):
    cosine=sum(x*y for x,y in zip(a,c))
    if cosine<0:
        c=tuple(-v for v in c);cosine=-cosine
    if cosine>.9995:
        blended=tuple(x*(1-t)+y*t for x,y in zip(a,c))
        length=math.sqrt(sum(y*y for y in blended))
        return tuple(x/length for x in blended)
    angle=math.acos(max(-1.,min(1.,cosine)))
    sine=math.sin(angle)
    return tuple((math.sin((1-t)*angle)*x+math.sin(t*angle)*y)/sine
                 for x,y in zip(a,c))

def scene_world(exercise,second):
    """Sample GLB LINEAR channels including in-between keyframe interpolation."""
    step=min(9,int(second/.4))
    start,stop=FRAMES[step:step+2]
    f=max(0.,min(1.,(second-start)/(stop-start)))
    world,rotations={},{}
    for bone,parent,bind in b.BONES:
        rot=quat_interpolate(
            b.quat_sequence(bone,start,exercise),
            b.quat_sequence(bone,stop,exercise),f)
        if parent is None:
            aa,bb=b.root_translation(exercise,start),b.root_translation(exercise,stop)
            world[bone]=tuple(b.lerp(x,y,f) for x,y in zip(aa,bb))
            rotations[bone]=rot
        else:
            world[bone]=b._add(world[parent],
                               b._qrot(rotations[parent],b._sub(bind,b.BIND[parent])))
            rotations[bone]=b._qmul(rotations[parent],rot)
    aa,bb=b.bar_translation(exercise,start),b.bar_translation(exercise,stop)
    return world,tuple(b.lerp(x,y,f) for x,y in zip(aa,bb))

def audit(exercise):
    report={'exerciseId':exercise,'sampleCount':len(SAMPLES),
            'maxGripErrorMeters':0.,'maxFootDriftMeters':0.,
            'minKneeHeightMeters':float('inf'),
            'deepSquatKneeForwardOfHipMeters':None}
    planted=None
    for time in SAMPLES:
        pose,bar=scene_world(exercise,time)
        if planted is None:planted=(pose['foot_L'],pose['foot_R'])
        for side,sign,foot_start in zip(('L','R'),(-1,1),planted):
            target=(sign*(.65 if exercise==b.IDS[2] else .60),bar[1],bar[2])
            report['maxGripErrorMeters']=max(report['maxGripErrorMeters'],
                                            math.dist(pose['hand_'+side],target))
            report['maxFootDriftMeters']=max(report['maxFootDriftMeters'],
                                             math.dist(pose['foot_'+side],foot_start))
            report['minKneeHeightMeters']=min(report['minKneeHeightMeters'],
                                               pose['shin_'+side][1])
            if exercise==b.IDS[2] and time==2.0:
                report['deepSquatKneeForwardOfHipMeters']=min(
                    pose['shin_L'][2]-pose['thigh_L'][2],
                    pose['shin_R'][2]-pose['thigh_R'][2])
    return report

class KinematicContactTest(unittest.TestCase):
    def test_grip_contacts_feet_and_forward_squat_knees(self):
        results={}
        for exercise in b.IDS:
            result=audit(exercise)
            results[exercise]=result
            self.assertLess(result['maxGripErrorMeters'],.012,result)
            self.assertLess(result['maxFootDriftMeters'],.012,result)
            self.assertGreater(result['minKneeHeightMeters'],.10,result)
            if exercise==b.IDS[2]:
                self.assertGreater(result['deepSquatKneeForwardOfHipMeters'],.25,result)
        destination=Path('build/anatomical_3d_glb/motion_contact_audit.json')
        destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_text(json.dumps({
          'status':'contact_geometry_checked_not_biomechanically_approved',
          'units':'metres','sampleIntervalSeconds':.05,
          'approved':False,'enabled':False,'pilots':results,
        },indent=2,sort_keys=True)+'\n',encoding='utf8')
    def test_bones_and_bar_return_to_same_pose_at_loop_end(self):
        for ex in b.IDS:
            first,bar0=scene_world(ex,0.)
            last,bar4=scene_world(ex,4.)
            self.assertEqual(bar0,bar4)
            for joint in b.INDEX:
                self.assertLess(math.dist(first[joint],last[joint]),1e-7)
    def test_symmetric_stance(self):
        for ex in b.IDS:
            for time in (0.,.6,1.2,1.8,2.,2.4,3.,4.):
                pose,_=scene_world(ex,time)
                for key in ('thigh_','shin_','foot_'):
                    left,right=pose[key+'L'],pose[key+'R']
                    self.assertAlmostEqual(left[0],-right[0],delta=1e-5)
                    self.assertAlmostEqual(left[1],right[1],delta=1e-5)
                    self.assertAlmostEqual(left[2],right[2],delta=1e-5)

if __name__=='__main__':unittest.main()
