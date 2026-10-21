"""121-sample contact audit of the actual glTF joint channels, not just solver inputs."""
import bisect,json,math,os,unittest
from pathlib import Path
from retarget_cc0_glb import GLB,sub,norm,qnorm
import build_master_contacts_v5 as solver

OUT=Path(os.environ.get('STK_MASTER_CONTACTS_V5','build/cc0_master_contacts_v5'))
SRC=Path(os.environ.get('STK_MASTER_MOBILE_V4','build/cc0_master_mobile_v4'))

def quaternion(a,b,t):
    d=sum(x*y for x,y in zip(a,b))
    if d<0:b=tuple(-v for v in b);d=-d
    if d>.9995:
        return qnorm(tuple((1-t)*x+t*y for x,y in zip(a,b)))
    angle=math.acos(max(-1.,min(1.,d)))
    return tuple((math.sin((1-t)*angle)*x+math.sin(t*angle)*y)/
                 math.sin(angle) for x,y in zip(a,b))

def at(rig,clip,t):
    local={}
    for c in clip['channels']:
        if c['target']['path']=='weights':continue
        node=c['target']['node'];kind=c['target']['path']
        sampler=clip['samplers'][c['sampler']]
        times=[row[0] for row in rig.accessor(sampler['input'])]
        values=rig.accessor(sampler['output'])
        j=max(0,min(len(times)-2,bisect.bisect_right(times,t)-1))
        mix=max(0,min(1,(t-times[j])/(times[j+1]-times[j])))
        value=(quaternion(values[j],values[j+1],mix) if kind=='rotation' else
               tuple(a*(1-mix)+b*mix for a,b in zip(values[j],values[j+1])))
        trans,rot=local.get(node,solver.rest(rig,node))
        if kind=='rotation':rot=value
        else:trans=value
        local[node]=(trans,rot)
    return rig.world(local)[0]

class ContactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original=GLB((SRC/'stk_master_v4_mobile_morph_lod_unapproved.glb')
                        .read_bytes(),expected_sha=None)
        cls.rig=GLB((OUT/'stk_master_v5_contact_review.glb')
                   .read_bytes(),expected_sha=None)
        cls.bar=GLB((OUT/'stk_overhead_bar_proxy_v5.glb')
                   .read_bytes(),expected_sha=None)
        cls.report=json.loads((OUT/'master_contacts_v5_report.json').read_text())

    def test_same_55_joint_skin_and_eight_morphs(self):
        a,b=self.original.doc,self.rig.doc
        self.assertEqual(a['meshes'],b['meshes'])
        self.assertEqual(a['skins'],b['skins'])
        self.assertEqual(a['nodes'],b['nodes'])
        self.assertEqual(len(b['animations']),7)
        self.assertEqual(self.report['catalogCount'],229)
        self.assertFalse(b['extras']['approved'])
        self.assertFalse(b['extras']['enabled'])
        for old,new in zip(a['animations'],b['animations']):
            x=next(c for c in old['channels'] if c['target']['path']=='weights')
            y=next(c for c in new['channels'] if c['target']['path']=='weights')
            sx=old['samplers'][x['sampler']]
            sy=new['samplers'][y['sampler']]
            self.assertEqual(self.original.accessor(sx['output']),
                             self.rig.accessor(sy['output']))

    def test_seven_patterns_contacts_across_121_frames(self):
        for clip in self.rig.doc['animations']:
            kind=clip['extras']['pattern']
            lower=kind in ('hip_hinge','squat_articulation','split_lunge_left')
            for k in range(121):
                t=k/30
                pos=at(self.rig,clip,t)
                active=solver.SIDES if lower or not kind.startswith('unilateral') else (
                  ('l',) if kind.endswith('left') else ('r',))
                for side in active:
                    foot,hand=solver.targets(self.rig,kind,side,solver.phase(t))
                    part='foot_'+side if lower else 'hand_'+side
                    err=norm(sub(pos[self.rig.by_name[part]],foot if lower else hand))
                    self.assertLess(err,.018,(kind,t,side,err))
                    if lower:
                        y0=self.rig.restpos[self.rig.by_name[part]][1]
                        self.assertAlmostEqual(pos[self.rig.by_name[part]][1],
                                               y0,delta=.018)
            peak=at(self.rig,clip,2)
            if 'reach' in kind:
                side='r' if kind.endswith('right') else 'l'
                self.assertGreater(peak[self.rig.by_name['hand_'+side]][1],
                                   peak[self.rig.by_name['head']][1]+.1)
            if kind.startswith('unilateral'):
                other='r' if kind.endswith('left') else 'l'
                self.assertLess(norm(sub(peak[self.rig.by_name['hand_'+other]],
                         self.rig.restpos[self.rig.by_name['hand_'+other]])),.0001)

    def test_separate_bar_proxy_stays_on_bilateral_wrist_line(self):
        self.assertFalse(self.bar.doc['extras']['approved'])
        self.assertEqual(self.bar.doc['meshes'][0]['name'],'STK_BAR')
        sample=self.bar.doc['animations'][0]['samplers'][0]
        times=[v[0] for v in self.bar.accessor(sample['input'])]
        positions=self.bar.accessor(sample['output'])
        self.assertEqual(len(positions),41)
        for t,position in zip(times,positions):
            hands=[solver.targets(self.original,'overhead_reach_bilateral',
                                 side,solver.phase(t))[1] for side in solver.SIDES]
            mean=tuple(sum(h[i] for h in hands)/2 for i in range(3))
            self.assertLess(norm(sub(position,mean)),.00001)
            self.assertTrue(all(abs(h[0]-position[0])<.52 for h in hands))
        self.assertTrue(all(not data['certifiedBiomechanics']
                     for data in self.report['patterns'].values()))
if __name__=='__main__':unittest.main()
