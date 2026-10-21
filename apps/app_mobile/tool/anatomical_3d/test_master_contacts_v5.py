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
        self.assertEqual(b['extras']['masterCorrectiveDriverVersion'],2)
        self.assertTrue(self.report['correctivesRecomputedFromIK'])
        for old,new in zip(a['animations'],b['animations']):
            x=next(c for c in old['channels'] if c['target']['path']=='weights')
            y=next(c for c in new['channels'] if c['target']['path']=='weights')
            sx=old['samplers'][x['sampler']]
            sy=new['samplers'][y['sampler']]
            self.assertEqual(sx['output'],sy['output'])
            self.assertEqual(len(self.rig.accessor(sy['output'])),41*8)
            self.assertEqual(self.original.accessor(sx['input']),
                             self.rig.accessor(sy['input']))

    def test_corrective_drivers_follow_ik_and_unilateral_independence(self):
        self.assertEqual(len(solver.MORPH_NAMES),8)
        for clip in self.rig.doc['animations']:
            kind=clip['extras']['pattern']
            channel=next(c for c in clip['channels']
                         if c['target']['path']=='weights')
            sampler=clip['samplers'][channel['sampler']]
            stored=[v[0] for v in self.rig.accessor(sampler['output'])]
            self.assertEqual(len(stored),41*8)
            self.assertTrue(all(0<=v<=1 and math.isfinite(v) for v in stored))
            samples=[solver.pose(self.original,kind,k/10)[0]
                     for k in range(41)]
            zero=samples[0]
            predicted=[solver.corrective_weights(self.original,local,zero)
                       for local in samples]
            for frame in range(41):
                for i,name in enumerate(solver.MORPH_NAMES):
                    self.assertAlmostEqual(stored[frame*8+i],
                        predicted[frame][name],delta=.000002,
                        msg=(kind,frame,name))
                if frame in (0,40):
                    self.assertTrue(all(abs(stored[frame*8+i])<1e-6
                                        for i in range(8)),kind)
            peaks=self.report['patterns'][kind]['morphPeakWeights']
            for name in solver.MORPH_NAMES:
                self.assertAlmostEqual(peaks[name],
                    max(f[name] for f in predicted),delta=.000001)
            if kind.startswith('unilateral_reach_'):
                other='r' if kind.endswith('left') else 'l'
                self.assertTrue(all(peaks[name]<.000001 for name
                                    in solver.MORPH_NAMES if name.endswith('_'+other)))
            self.assertTrue(any(value>.01 for value in peaks.values()),kind)
            self.assertTrue(self.report['patterns'][kind][
                'correctivesLinkedToSolvedIK'])

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

    def test_independent_scapular_girdle_pivots_drive_reach_clips(self):
        # Validate exported GLB channels, not only pre-export solver poses.
        for clip in self.rig.doc['animations']:
            kind=clip['extras']['pattern']
            channels={self.rig.nodes[c['target']['node']]['name']:c
                      for c in clip['channels']
                      if c['target']['path']=='rotation'}
            expected=(set(('l','r')) if kind=='overhead_reach_bilateral'
                      else ({'l'} if kind=='unilateral_reach_left' else
                            {'r'} if kind=='unilateral_reach_right' else set()))
            for side in ('l','r'):
                name='stk_scapula_control_'+side
                if side not in expected:
                    self.assertNotIn(name,channels,(kind,side))
                    continue
                self.assertIn(name,channels,(kind,side))
                sampler=clip['samplers'][channels[name]['sampler']]
                values=self.rig.accessor(sampler['output'])
                self.assertEqual(len(values),41)
                self.assertAlmostEqual(values[0][2],0.,delta=.00001)
                self.assertAlmostEqual(values[-1][2],0.,delta=.00001)
                peak=values[20]
                direction=1 if side=='l' else -1
                self.assertGreater(peak[2]*direction,.04)
                degrees=2*math.degrees(math.acos(min(1,abs(peak[3]))))
                self.assertAlmostEqual(degrees,6.,delta=.15)
                self.assertLessEqual(degrees,20.)
            self.assertEqual(self.report['patterns'][kind][
                'scapularGirdlePreviewDegrees'],6 if expected else 0)
            self.assertFalse(self.report['patterns'][kind][
                'scapularGeometryIndependentlySculpted'])

    def test_rotation_excursions_remain_inside_preview_angular_gates(self):
        # These are deliberately mechanical excursion ceilings, NOT
        # human range-of-motion/clinical limits. A coach must still review.
        for clip in self.rig.doc['animations']:
            for channel in clip['channels']:
                if channel['target']['path']!='rotation':continue
                node=channel['target']['node']
                joint_name=self.rig.nodes[node]['name']
                sample=clip['samplers'][channel['sampler']]
                before=solver.rest(self.rig,node)[1]
                samples=self.rig.accessor(sample['output'])
                for q in samples:
                    d=abs(sum(x*y for x,y in zip(before,q)))
                    swing=2*math.degrees(math.acos(min(1,max(0,d))))
                    limit=100 if joint_name.startswith('upperarm_') else 135
                    self.assertLess(swing,limit,(clip['name'],joint_name,swing))
if __name__=='__main__':unittest.main()
