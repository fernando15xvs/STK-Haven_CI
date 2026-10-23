"""Audit actual exported glTF LINEAR channels at 30 FPS, not just IK keys.

Check hand-to-bar grip, planted feet, and the last/first frame seam.
This is geometric contact QA only, never biomechanical certification.
"""
import bisect
import json
import math
import os
import unittest
from pathlib import Path

import retarget_cc0_glb as rig
import pilot_motion_quality_v98 as quality
import build_master_exercise_pilots_v99 as master55
import solve_exercise_scapula_v910 as scapula
import exercise_surface_collision_v911 as surface
import build_master_anatomy_v8 as anatomy913
import build_master_high_res_v914 as hires914
import bake_master_detail_v915 as detail915
import build_torso_contours_v916 as torso916
import animate_hand_grip_v917 as hand917
import calibrate_grip_contact_v918 as contact918
import review_fingertip_mesh_v919 as skin919

OUT = Path(os.environ.get("STK_CC0_RETARGET", "build/cc0_53bone_retarget"))
FPS = 30
SAMPLES = 121
MAX_ERROR = .005  # 5 millimetres: deliberately strict but not zero.


def slerp(a, b, factor):
    dot = sum(x*y for x, y in zip(a, b))
    if dot < 0:
        b = tuple(-x for x in b)
        dot = -dot
    if dot > .9995:
        return rig.qnorm(tuple(x*(1-factor)+y*factor for x, y in zip(a, b)))
    angle = math.acos(min(1., max(-1., dot)))
    return tuple(
        (math.sin((1-factor)*angle)*x + math.sin(factor*angle)*y)/math.sin(angle)
        for x, y in zip(a, b)
    )


def world_at(glb, seconds, tracks):
    local = {}
    for node, path, times, values in tracks:
        i = max(0, min(len(times)-2, bisect.bisect_right(times, seconds)-1))
        fraction = max(0., min(1., (seconds-times[i])/(times[i+1]-times[i])))
        a, b = values[i], values[i+1]
        sample = slerp(a, b, fraction) if path == "rotation" else tuple(
            x*(1-fraction)+y*fraction for x, y in zip(a, b))
        record = glb.nodes[node]
        translation, rotation = local.get(node, (
            tuple(record.get("translation", (0, 0, 0))),
            tuple(record.get("rotation", (0, 0, 0, 1)))))
        if path == "rotation":
            rotation = sample
        else:
            translation = sample
        local[node] = (translation, rotation)
    positions, _ = glb.world(local)
    return positions


def sample_30fps(exercise):
    glb = rig.GLB((OUT/(exercise+"_mobile_lod.glb")).read_bytes(),
                  expected_sha=None)
    clip = glb.doc["animations"][0]
    tracks = []
    for channel in clip["channels"]:
        sampler = clip["samplers"][channel["sampler"]]
        times = [x[0] for x in glb.accessor(sampler["input"])]
        frames = glb.accessor(sampler["output"])
        if sampler["interpolation"] != "LINEAR" or len(times) != len(frames):
            raise ValueError("Expected complete GLB LINEAR animation")
        tracks.append((channel["target"]["node"],
                       channel["target"]["path"], times, frames))
    first = world_at(glb, 0, tracks)
    bar_index = glb.by_name["STK_EXERCISE_BAR"]
    max_grip = max_foot = 0.
    for frame in range(SAMPLES):
        sample = world_at(glb, frame/FPS, tracks)
        for side, sign in (("l",1),("r",-1)):
            wrist = sample[glb.by_name["hand_"+side]]
            bar = sample[bar_index]
            grip = (bar[0]+sign*(.51 if exercise=="ex_squat" else .50),
                    bar[1],bar[2])
            max_grip = max(max_grip, math.dist(wrist,grip))
            index = glb.by_name["foot_"+side]
            max_foot = max(max_foot, math.dist(sample[index],first[index]))
    last = world_at(glb, 4, tracks)
    loop = max(math.dist(first[glb.by_name[j]],last[glb.by_name[j]])
               for j in ("hand_l","hand_r","foot_l","foot_r","head"))
    return {
        "exerciseId":exercise,"frames":SAMPLES,"fps":FPS,
        "maximumHandGripErrorMeters":round(max_grip,7),
        "maximumFootDriftMeters":round(max_foot,7),
        "loopSeamMeters":round(loop,7),
        "approved":False,"enabled":False,
        "review":"geometric interpolation only, not expert biomechanics"
    }


class GlbBetweenKeyframesTest(unittest.TestCase):
    def test_three_glb_motion_clips_interpolate_without_slipping(self):
        report = []
        for exercise in rig.EXERCISES:
            result = sample_30fps(exercise)
            self.assertEqual(result["frames"],121)
            self.assertLess(result["maximumHandGripErrorMeters"],MAX_ERROR,result)
            self.assertLess(result["maximumFootDriftMeters"],MAX_ERROR,result)
            self.assertLess(result["loopSeamMeters"],.00001,result)
            report.append(result)
        (OUT/"interpolated_contact_30fps.json").write_text(json.dumps({
            "status":"experimental_review_only",
            "approved":False,"enabled":False,
            "samplesPerExercise":SAMPLES,
            "clips":report},indent=2)+"\n",encoding="utf8")


    def test_v98_actual_lod_bar_bench_and_joint_contact_diagnostics(self):
        audits=[]
        for exercise in rig.EXERCISES:
            glb=rig.GLB((OUT/(exercise+"_mobile_lod.glb")).read_bytes(),
                        expected_sha=None)
            clip=glb.doc['animations'][0]
            tracks=[]
            for channel in clip['channels']:
                sampler=clip['samplers'][channel['sampler']]
                times=[float(x[0]) for x in glb.accessor(sampler['input'])]
                frames=glb.accessor(sampler['output'])
                self.assertEqual(sampler['interpolation'],'LINEAR')
                self.assertEqual(len(times),len(frames))
                tracks.append((channel['target']['node'],
                               channel['target']['path'],times,frames))
            report=quality.review(glb,exercise,tracks,world_at)
            self.assertEqual(report['sampledFrames'],121)
            self.assertLess(report['maxWristBarErrorMeters'],.005)
            self.assertLess(report['maxFootDriftMeters'],.005)
            self.assertGreater(report['barCenterTravelMeters'],.10)
            self.assertFalse(report['approved'])
            self.assertFalse(report['enabled'])
            self.assertFalse(report['expertBiomechanicsReviewed'])
            self.assertFalse(report['nativeIphoneAndroidVerified'])
            self.assertEqual(report['benchNodeRequiredAndStatic'],
                             exercise=='ex_bench_press')
            self.assertGreaterEqual(len(report['manualBlockers']),4)
            audits.append(report)
        result={
            'version':'v9.8','status':'draft_equipment_and_joint_contact_QA',
            'source':'actual 53-bone CC0 mobile GLB LINEAR channels',
            'catalogCount':229,'approved':False,'enabled':False,
            'notMeasured':['muscle anatomy quality','surface collisions',
              'exercise coaching correctness','device FPS or battery'],
            'pilots':audits,
        }
        (OUT/'three_pilot_motion_quality_v98.json').write_text(
            json.dumps(result,indent=2)+'\n',encoding='utf8')

    def test_v98_rejects_untrusted_or_missing_equipment_pilots(self):
        file=OUT/'ex_bench_press_mobile_lod.glb'
        glb=rig.GLB(file.read_bytes(),expected_sha=None)
        self.assertTrue(quality.check_source(glb,'ex_bench_press'))
        glb.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'Unsafe'):
            quality.check_source(glb,'ex_bench_press')
        glb.doc['extras']['approved']=False
        del glb.by_name['STK_BENCH_STATIONARY']
        with self.assertRaisesRegex(ValueError,'bench'):
            quality.check_source(glb,'ex_bench_press')



class Master55ExercisePilotTest(unittest.TestCase):
    """Test all three exercise-specific 55-bone GLB derivatives in public CI.

    This checks compatible glTF transforms and morph inputs; it does NOT mean
    the 53-bone motion is certified or the scapular rig is correctly animated.
    """
    MASTER=Path(os.environ.get(
        'STK_MASTER_SURFACE_V7','build/cc0_master_surface_v7'))
    OUTPUT=MASTER/'three_exercise_pilots_v99'

    @classmethod
    def setUpClass(cls):
        cls.source=(cls.MASTER/'stk_master_v7_surface_preview.glb').read_bytes()
        cls.master=rig.GLB(cls.source,expected_sha=None)
        cls.manifest=master55.build(
            cls.MASTER/'stk_master_v7_surface_preview.glb',
            OUT,cls.OUTPUT)

    @staticmethod
    def _tracks(glb):
        result=[]
        for channel in glb.doc['animations'][0]['channels']:
            sampler=glb.doc['animations'][0]['samplers'][channel['sampler']]
            if channel['target']['path']=='weights':continue
            result.append((channel['target']['node'],channel['target']['path'],
                          [p[0] for p in glb.accessor(sampler['input'])],
                          glb.accessor(sampler['output'])))
        return result

    def test_exact_55_joint_skin_atlas_eight_morphs_and_no_publication(self):
        self.assertEqual(self.manifest['version'],99)
        self.assertEqual(self.manifest['catalogCount'],229)
        self.assertFalse(self.manifest['approved'])
        self.assertFalse(self.manifest['enabled'])
        self.assertEqual(len(self.manifest['pilots']),3)
        for exercise in rig.EXERCISES:
            filename=self.OUTPUT/(exercise+'_master55_v99_unapproved.glb')
            data=filename.read_bytes()
            preview=rig.GLB(data,expected_sha=None)
            doc=preview.doc
            self.assertLess(len(data),master55.MAX_QA_GLb_BYTES)
            self.assertEqual(len(doc['skins'][0]['joints']),55)
            self.assertEqual(len(doc['meshes'][0]['primitives']),12)
            self.assertEqual(tuple(doc['meshes'][0]['extras']['targetNames']),
                             master55.MORPH_NAMES)
            self.assertEqual(len(doc['animations']),1)
            self.assertEqual(doc['extras']['exerciseId'],exercise)
            self.assertEqual(doc['extras']['masterExercisePilotVersion'],99)
            self.assertFalse(doc['extras']['approved'])
            self.assertFalse(doc['extras']['enabled'])
            self.assertTrue(doc['extras']['contactAndExpertReviewPending'])
            for node in ('stk_scapula_control_l','stk_scapula_control_r'):
                self.assertIn(node,preview.by_name)
            self.assertEqual(doc['skins'],self.master.doc['skins'])
            self.assertEqual(doc['meshes'][0],self.master.doc['meshes'][0])
            for name in ('POSITION','NORMAL','JOINTS_0','WEIGHTS_0'):
                idx=doc['meshes'][0]['primitives'][0]['attributes'][name]
                self.assertEqual(preview.accessor(idx),
                                 self.master.accessor(idx))
            for shape in doc['meshes'][0]['primitives'][0]['targets']:
                idx=shape['POSITION']
                self.assertEqual(preview.accessor(idx),
                                 self.master.accessor(idx))
            channels=doc['animations'][0]['channels']
            weight_channels=[x for x in channels
                             if x['target']['path']=='weights']
            self.assertEqual(len(weight_channels),1)
            w=weight_channels[0]
            sampled=preview.accessor(
                doc['animations'][0]['samplers'][w['sampler']]['output'])
            self.assertEqual(len(sampled),41*8)
            self.assertTrue(all(0<=v[0]<=1.025 for v in sampled))
            self.assertEqual(len(doc['meshes'])-1,
                             2 if exercise=='ex_bench_press' else 1)
            report=next(p for p in self.manifest['pilots']
                        if p['exerciseId']==exercise)
            self.assertFalse(report['approved'])
            self.assertFalse(report['enabled'])
            self.assertTrue(report['rigControlsStillNeutral'])

    def test_121_frame_55_joint_motion_and_grip_contact_parity(self):
        for exercise in rig.EXERCISES:
            original=rig.GLB(
                (OUT/(exercise+'_mobile_lod.glb')).read_bytes(),
                expected_sha=None)
            restored=rig.GLB(
                (self.OUTPUT/(exercise+'_master55_v99_unapproved.glb'))
                .read_bytes(),expected_sha=None)
            old_tracks=self._tracks(original)
            new_tracks=self._tracks(restored)
            base_old=world_at(original,0.,old_tracks)
            base_new=world_at(restored,0.,new_tracks)
            largest_difference=0.
            biggest_grip=0.
            biggest_foot=0.
            for i in range(SAMPLES):
                t=i/FPS
                old=world_at(original,t,old_tracks)
                new=world_at(restored,t,new_tracks)
                for name in ('pelvis','hand_l','hand_r','foot_l',
                             'foot_r','upperarm_l','upperarm_r',
                             'STK_EXERCISE_BAR'):
                    delta=math.dist(
                        old[original.by_name[name]],
                        new[restored.by_name[name]])
                    largest_difference=max(largest_difference,delta)
                bar=new[restored.by_name['STK_EXERCISE_BAR']]
                for side,sign in (('l',1),('r',-1)):
                    hand=new[restored.by_name['hand_'+side]]
                    target=(bar[0]+sign*(.51 if exercise=='ex_squat' else .50),
                            bar[1],bar[2])
                    biggest_grip=max(biggest_grip,math.dist(hand,target))
                    foot=restored.by_name['foot_'+side]
                    biggest_foot=max(biggest_foot,math.dist(new[foot],
                                                         base_new[foot]))
                # Both added controls must stay neutral until a future
                # exercise-specific scapular re-solve.
                for side in ('l','r'):
                    name='stk_scapula_control_'+side
                    self.assertEqual(
                        restored.nodes[restored.by_name[name]].get(
                            'rotation',[0,0,0,1]),[0,0,0,1])
            self.assertLess(largest_difference,.002,
                            (exercise,'rest/pose migration drift'))
            self.assertLess(biggest_grip,.005,(exercise,'new rig wrist grip'))
            self.assertLess(biggest_foot,.005,(exercise,'new rig stance'))

    def test_v911_signed_distance_helpers_and_invalid_equipment(self):
        self.assertAlmostEqual(
            surface.capped_cylinder_sdf((0,0,0),-1.,1.,.10),-.10)
        self.assertAlmostEqual(
            surface.capped_cylinder_sdf((0,.15,0),-1.,1.,.10),.05)
        self.assertAlmostEqual(
            surface.capped_cylinder_sdf((1.05,0,0),-1.,1.,.10),.05)
        self.assertAlmostEqual(
            surface.box_sdf((0,0,0),(-1,-1,-1),(1,1,1)),-1.)
        self.assertAlmostEqual(
            surface.box_sdf((0,0,1.12),(-1,-1,-1),(1,1,1)),.12)
        with self.assertRaises(ValueError):
            surface.capped_cylinder_sdf((0,0,0),1.,-1.,.10)
        with self.assertRaises(ValueError):
            surface.box_sdf((0,0,0),(1,1,1),(1,2,2))

    def test_v911_actual_55_joint_surface_to_rigid_proxy_review(self):
        folder=self.OUTPUT/'scapular_v910'
        if not (folder/'ex_squat_master55_v910_scapular_qa.glb').is_file():
            scapula.build(self.OUTPUT,folder)
        audited=folder/'surface_v911'
        report=surface.build(folder,audited)
        self.assertEqual(report['catalogCount'],229)
        self.assertEqual(report['samplesPerExercise'],121)
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        self.assertEqual(len(report['pilots']),3)
        for result in report['pilots']:
            exercise=result['exerciseId']
            self.assertIn(exercise,rig.EXERCISES)
            self.assertEqual(result['frames'],121)
            self.assertEqual(result['skinningJointCount'],55)
            self.assertEqual(result['morphTargetCount'],8)
            self.assertEqual(result['barPiecesChecked'],7)
            self.assertEqual(result['benchProxyParts']>0,
                             exercise=='ex_bench_press')
            metrics=result['metrics']
            self.assertEqual(metrics['samples'],
                             121*result['skinnedPointsPerFrame'])
            self.assertTrue(math.isfinite(metrics[
                'minBarSignedDistanceMeters']))
            self.assertTrue(math.isfinite(metrics[
                'minBodyHeightMeters']))
            self.assertFalse(result['collisionFreeCertified'])
            self.assertFalse(result['approved'])
            self.assertFalse(result['enabled'])
            self.assertGreater(len(result['manualBlockers']),2)
        self.assertTrue((audited/'surface_collision_v911.json').is_file())
        source=(folder/'ex_bench_press_master55_v910_scapular_qa.glb')
        compromised=rig.GLB(source.read_bytes(),expected_sha=None)
        compromised.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'disabled 55'):
            surface.review(compromised.bytes(),'ex_bench_press')

    def test_v910_three_pilots_scapular_ik_and_continuous_bar_contact(self):
        folder=self.OUTPUT/'scapular_v910'
        report=scapula.build(self.OUTPUT,folder)
        self.assertEqual(report['rigJointCount'],55)
        self.assertEqual(report['exerciseCount'],3)
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        for exercise in rig.EXERCISES:
            previous=rig.GLB(
                (self.OUTPUT/(exercise+'_master55_v99_unapproved.glb'))
                .read_bytes(),expected_sha=None)
            current=rig.GLB(
                (folder/(exercise+'_master55_v910_scapular_qa.glb'))
                .read_bytes(),expected_sha=None)
            self.assertEqual(current.doc['extras']['masterExercisePilotVersion'],
                             910)
            self.assertEqual(previous.doc['skins'],current.doc['skins'])
            self.assertEqual(previous.doc['meshes'],current.doc['meshes'])
            self.assertFalse(current.doc['extras']['approved'])
            self.assertFalse(current.doc['extras']['enabled'])
            self.assertEqual(
                len(current.doc['animations'][0]['channels']),
                len(previous.doc['animations'][0]['channels'])+2)
            self.assertEqual(
                {x['target']['path'] for x in current.doc['animations'][0]
                   ['channels']},{'rotation','translation','weights'})
            for side in ('l','r'):
                node=current.by_name['stk_scapula_control_'+side]
                clips=[c for c in current.doc['animations'][0]['channels']
                       if c['target']=={'node':node,'path':'rotation'}]
                self.assertEqual(len(clips),1)
                sampler=current.doc['animations'][0]['samplers'][
                    clips[0]['sampler']]
                self.assertEqual(len(current.accessor(sampler['output'])),41)
            prior_tracks=self._tracks(previous)
            updated_tracks=self._tracks(current)
            start=world_at(current,0,updated_tracks)
            max_wrist_drift=0.
            max_foot_drift=0.
            max_old_motion_drift=0.
            for frame in range(121):
                t=frame/30.
                baseline=world_at(previous,t,prior_tracks)
                sample=world_at(current,t,updated_tracks)
                for side,sign in (('l',1),('r',-1)):
                    hand=sample[current.by_name['hand_'+side]]
                    old_hand=baseline[previous.by_name['hand_'+side]]
                    max_wrist_drift=max(max_wrist_drift,
                                        math.dist(hand,old_hand))
                    bar=sample[current.by_name['STK_EXERCISE_BAR']]
                    grip=(bar[0]+sign*(.51 if exercise=='ex_squat' else .50),
                          bar[1],bar[2])
                    max_wrist_drift=max(max_wrist_drift,
                                        math.dist(hand,grip))
                    foot=sample[current.by_name['foot_'+side]]
                    max_foot_drift=max(max_foot_drift,math.dist(
                        foot,start[current.by_name['foot_'+side]]))
                for name in ('pelvis','STK_EXERCISE_BAR'):
                    max_old_motion_drift=max(max_old_motion_drift,
                        math.dist(sample[current.by_name[name]],
                            baseline[previous.by_name[name]]))
            self.assertLess(max_wrist_drift,.005,
                            (exercise,'sustained hand-bar contact'))
            self.assertLess(max_foot_drift,.005,
                            (exercise,'foot plant'))
            self.assertLess(max_old_motion_drift,.00005,
                            (exercise,'unchanged root/equipment paths'))
            summary=next(p for p in report['pilots']
                         if p['exerciseId']==exercise)
            self.assertGreater(sum(summary['solvedIKKeys'].values()),0)
            self.assertLess(
                max(summary['peakScapularLocalDegrees'].values()),3.01)
            self.assertLess(
                max(summary['maxContactErrorAtKeysMeters'].values()),.001)
            self.assertFalse(summary['surfaceCollisionValidated'])
            self.assertFalse(summary['physicalDeviceMeasured'])

    def test_v910_rejects_wrong_rig_and_approved_preview(self):
        data=(self.OUTPUT/'ex_bench_press_master55_v99_unapproved.glb')
        raw=data.read_bytes()
        self.assertRaises(ValueError,scapula.correct,raw,'ex_not_real')
        master=rig.GLB(raw,expected_sha=None)
        master.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'disabled v9.9'):
            scapula.correct(master.bytes(),'ex_bench_press')

    def test_v913_11_bilateral_regions_and_three_consistent_55_joint_pilots(self):
        # Offline authoring only: builds after the existing v9.10 pilot inputs,
        # and requires exactly the same v7 surface before each transplant.
        source_folder=self.OUTPUT/'scapular_v910'
        if not (source_folder/'ex_squat_master55_v910_scapular_qa.glb').exists():
            scapula.build(self.OUTPUT,source_folder)
        baseline_bytes=(self.MASTER/'stk_master_v7_surface_preview.glb').read_bytes()
        raw={ex:(source_folder/(ex+'_master55_v910_scapular_qa.glb')).read_bytes()
             for ex in rig.EXERCISES}
        master_out,pilots,report=anatomy913.build(baseline_bytes,raw)
        dest=self.MASTER/'v8_authoring'
        dest.mkdir(parents=True,exist_ok=True)
        (dest/'stk_master_v8_anatomy_preview.glb').write_bytes(master_out)
        for exercise,bytes_ in pilots.items():
            (dest/(exercise+'_master55_v8_sculpt_qa.glb')).write_bytes(bytes_)
        (dest/'master_anatomy_v913_report.json').write_text(
            json.dumps(report,indent=2)+'\\n',encoding='utf8')
        self.assertEqual(report['version'],913)
        self.assertEqual(report['atlasRegions'],11)
        self.assertEqual(report['catalogCount'],229)
        self.assertEqual(report['jointCount'],55)
        self.assertGreater(report['sculpt']['editedVertices'],800)
        self.assertEqual(set(report['sculpt']['regionAffectedVertices']),
                         set(anatomy913.REGION_ORDER))
        self.assertTrue(all(count>0 for count in
                            report['sculpt']['regionAffectedVertices'].values()))
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        original=rig.GLB(baseline_bytes,expected_sha=None)
        sculpted=rig.GLB(master_out,expected_sha=None)
        self.assertLessEqual(len(master_out),850*1024)
        self.assertEqual(sculpted.doc['skins'],original.doc['skins'])
        self.assertEqual(sculpted.doc['animations'],original.doc['animations'])
        self.assertEqual(sculpted.doc['meshes'],original.doc['meshes'])
        self.assertEqual(sculpted.doc['extras']['masterSculptDetailVersion'],8)
        attrs=original.doc['meshes'][0]['primitives'][0]['attributes']
        for label in ('JOINTS_0','WEIGHTS_0'):
            self.assertEqual(original.accessor(attrs[label]),
                             sculpted.accessor(attrs[label]),label)
        for target in original.doc['meshes'][0]['primitives'][0]['targets']:
            a=target['POSITION']
            self.assertEqual(original.accessor(a),sculpted.accessor(a))
        previous=original.accessor(attrs['POSITION'])
        updated=sculpted.accessor(attrs['POSITION'])
        changes=[math.dist(a,b) for a,b in zip(previous,updated)]
        self.assertLessEqual(max(changes),anatomy913.MAX_ADDED_RELIEF+.000001)
        self.assertGreater(sum(x>.00004 for x in changes),800)
        for index,point in enumerate(previous):
            if abs(point[0])<=anatomy913.SIDE_GUARD:
                self.assertLess(changes[index],1e-6)
        for ex in rig.EXERCISES:
            before=rig.GLB(raw[ex],expected_sha=None)
            after=rig.GLB(pilots[ex],expected_sha=None)
            self.assertEqual(before.doc['skins'],after.doc['skins'])
            self.assertEqual(before.doc['animations'],after.doc['animations'])
            self.assertEqual(before.doc['nodes'],after.doc['nodes'])
            self.assertEqual(before.doc['meshes'],after.doc['meshes'])
            self.assertEqual(after.doc['extras']['approved'],False)
            self.assertEqual(after.doc['extras']['enabled'],False)
            self.assertEqual(after.doc['extras']['anatomyArtVersion'],913)
            a=after.doc['meshes'][0]['primitives'][0]['attributes']
            self.assertEqual(after.accessor(a['POSITION']),updated)
            self.assertEqual(after.accessor(a['NORMAL']),
                             sculpted.accessor(attrs['NORMAL']))
            self.assertLess(len(pilots[ex]),1400*1024)


    def test_v914_four_high_res_GLBS_preserve_exercise_kinematics(self):
        # 4 authoring assets, not copies deployed in app/pubspec.
        prior=self.MASTER/'v8_authoring'
        if not (prior/'ex_squat_master55_v8_sculpt_qa.glb').is_file():
            self.test_v913_11_bilateral_regions_and_three_consistent_55_joint_pilots()
        root=prior/'high_res_v914'
        report=hires914.build(
            prior/'stk_master_v8_anatomy_preview.glb',prior,root)
        self.assertEqual(report['schema'],'stk_anatomy_v914_high_res_unapproved')
        self.assertEqual(report['catalogCount'],229)
        self.assertEqual(len(report['assets']),4)
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        for ex in (None,*rig.EXERCISES):
            original=(prior/('stk_master_v8_anatomy_preview.glb'
                      if ex is None else ex+'_master55_v8_sculpt_qa.glb'))
            output=(root/('stk_master_v914_high_res_authoring.glb'
                      if ex is None else ex+'_master55_v914_high_res_qa.glb'))
            before=rig.GLB(original.read_bytes(),expected_sha=None)
            after=rig.GLB(output.read_bytes(),expected_sha=None)
            self.assertEqual(before.doc['skins'],after.doc['skins'])
            self.assertEqual(before.doc['nodes'],after.doc['nodes'])
            self.assertEqual(before.doc['animations'],after.doc['animations'])
            self.assertEqual(before.doc['materials'],after.doc['materials'])
            self.assertEqual(before.doc['extras']['approved'],False)
            self.assertEqual(after.doc['extras']['approved'],False)
            self.assertEqual(after.doc['extras']['enabled'],False)
            self.assertEqual(after.doc['extras']['anatomyAuthoringVersion'],914)
            parts=after.doc['meshes'][0]['primitives']
            self.assertEqual(len(parts),12)
            oldparts=before.doc['meshes'][0]['primitives']
            attr=parts[0]['attributes']
            oldattr=oldparts[0]['attributes']
            vertex=after.accessor(attr['POSITION'])
            source_vertex=before.accessor(oldattr['POSITION'])
            self.assertEqual(len(source_vertex),4727)
            self.assertEqual(len(vertex),19004)
            for old,new in zip(source_vertex,vertex):
                self.assertEqual(old,new)
            joint=after.accessor(attr['JOINTS_0'])
            weight=after.accessor(attr['WEIGHTS_0'])
            self.assertTrue(all(abs(sum(w)-1)<.0002 for w in weight))
            self.assertTrue(all(0<=int(j)<55 for row in joint for j in row))
            self.assertEqual(joint[:4727],before.accessor(oldattr['JOINTS_0']))
            self.assertEqual(weight[:4727],before.accessor(oldattr['WEIGHTS_0']))
            for prior_target,new_target in zip(oldparts[0]['targets'],
                                               parts[0]['targets']):
                oldshape=before.accessor(prior_target['POSITION'])
                newshape=after.accessor(new_target['POSITION'])
                self.assertEqual(newshape[:4727],oldshape)
                self.assertEqual(len(newshape),19004)
            for left,right in zip(oldparts,parts):
                a=len(before.accessor(left['indices']))
                b=len(after.accessor(right['indices']))
                self.assertEqual(b,4*a)
                self.assertEqual(left['extras'],right['extras'])
                self.assertEqual(left['material'],right['material'])
            self.assertEqual(after.doc['meshes'][1:],before.doc['meshes'][1:])
            summary=next(x for x in report['assets'] if x['exerciseId']==ex)
            self.assertEqual(summary['originalTriangles'],9843)
            self.assertEqual(summary['highResolutionTriangles'],39372)
            self.assertEqual(summary['triangleFlips'],0)
            self.assertEqual(summary['morphTargetCount'],8)
            self.assertEqual(summary['jointCount'],55)
            self.assertGreater(summary['curvatureSuppressedEdges'],0)
            self.assertLessEqual(summary['maxMidpointCurvatureMeters'],
                                 hires914.MAX_CURVE+.000001)
            self.assertLess(summary['authoringBytes'],6*1024*1024)
            self.assertFalse(summary['productionAsset'])
            self.assertFalse(summary['professionalAnatomy'])
        self.assertTrue((root/'high_res_authoring_v914_report.json').is_file())

    def test_v915_detail_transfer_preserves_exact_motion_and_mobile_mesh(self):
        folder=self.MASTER/'v8_authoring'
        high=folder/'high_res_v914'
        if not (high/'ex_squat_master55_v914_high_res_qa.glb').exists():
            self.test_v914_four_high_res_GLBS_preserve_exercise_kinematics()
        output=folder/'detail_bake_v915'
        report=detail915.build(
            high/'stk_master_v914_high_res_authoring.glb',
            folder/'stk_master_v8_anatomy_preview.glb',
            high,folder,output)
        self.assertEqual(report['schema'],
            'stk_anatomy_detail_bake_v915_QA_only')
        self.assertEqual(len(report['assets']),4)
        self.assertEqual(report['highVertices'],19004)
        self.assertEqual(report['mobileVertices'],4727)
        self.assertEqual(report['highTriangles'],39372)
        self.assertEqual(report['muscleRegions'],11)
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        self.assertFalse(report['productionReady'])
        self.assertGreater(
            report['geometry']['affectedHighResVertices'],350)
        self.assertLessEqual(
            report['geometry']['maxDisplacementMeters'],
            detail915.MAX_DETAIL_DISPLACEMENT+.000001)
        self.assertEqual(report['geometry']['flippedTriangles'],0)
        for ex in (None,*rig.EXERCISES):
            basename='stk_master' if ex is None else ex
            original_high=(high/('stk_master_v914_high_res_authoring.glb'
                if ex is None else ex+'_master55_v914_high_res_qa.glb'))
            original_low=(folder/('stk_master_v8_anatomy_preview.glb'
                if ex is None else ex+'_master55_v8_sculpt_qa.glb'))
            old_high=rig.GLB(original_high.read_bytes(),expected_sha=None)
            old_low=rig.GLB(original_low.read_bytes(),expected_sha=None)
            new_high=rig.GLB((output/(
                basename+'_v915_high_detail_authoring.glb')).read_bytes(),
                expected_sha=None)
            new_low=rig.GLB((output/(
                basename+'_v915_mobile_normal_bake_qa.glb')).read_bytes(),
                expected_sha=None)
            for source,new in ((old_high,new_high),(old_low,new_low)):
                for name in ('skins','animations','nodes','meshes','materials'):
                    self.assertEqual(source.doc[name],new.doc[name],
                                     (basename,name))
                self.assertEqual(new.doc['extras']['anatomyShadingVersion'],915)
                self.assertFalse(new.doc['extras']['approved'])
                self.assertFalse(new.doc['extras']['enabled'])
                attrs=source.doc['meshes'][0]['primitives'][0]['attributes']
                for key in ('JOINTS_0','WEIGHTS_0'):
                    self.assertEqual(source.accessor(attrs[key]),
                                     new.accessor(attrs[key]),key)
                for original,new_shape in zip(
                    source.doc['meshes'][0]['primitives'][0]['targets'],
                    new.doc['meshes'][0]['primitives'][0]['targets']):
                    self.assertEqual(
                        source.accessor(original['POSITION']),
                        new.accessor(new_shape['POSITION']))
            low_attr=old_low.doc['meshes'][0]['primitives'][0]['attributes']
            self.assertEqual(old_low.accessor(low_attr['POSITION']),
                             new_low.accessor(low_attr['POSITION']))
            old_normals=old_low.accessor(low_attr['NORMAL'])
            normals=new_low.accessor(low_attr['NORMAL'])
            self.assertEqual(len(normals),4727)
            self.assertTrue(all(abs(detail915.length(v)-1)<.00005
                                for v in normals))
            changes=sum(math.dist(a,b)>.0005
                        for a,b in zip(old_normals,normals))
            self.assertGreater(changes,75)
            old_attr=old_high.doc['meshes'][0]['primitives'][0]['attributes']
            after_h=new_high.accessor(old_attr['POSITION'])
            before_h=old_high.accessor(old_attr['POSITION'])
            self.assertEqual(len(after_h),19004)
            self.assertLessEqual(max(math.dist(a,b) for a,b in
                zip(after_h,before_h)),
                detail915.MAX_DETAIL_DISPLACEMENT+.000001)
            measured=next(x for x in report['assets']
                          if x['exerciseId']==ex)
            self.assertGreater(measured['bake']['changedMobileNormals'],75)
            self.assertLess(measured['bake'][
                'maximumNormalDeviationDegrees'],12.1)
            self.assertFalse(measured['approved'])
            self.assertFalse(measured['enabled'])
            self.assertLess(measured['mobileBytes'],
                850*1024 if ex is None else 1400*1024)
        self.assertTrue((output/'normal_bake_v915_report.json').is_file())


    def test_v916_three_torso_contours_and_four_exact_55_joint_GLBS(self):
        # Uses already produced real v9.15 geometry, no fake metadata stubs.
        stage=self.MASTER/'v8_authoring'/'detail_bake_v915'
        if not (stage/'stk_master_v915_high_detail_authoring.glb').is_file():
            self.test_v915_detail_transfer_preserves_exact_motion_and_mobile_mesh()
        out=stage/'torso_v916'
        report=torso916.build(
            stage/'stk_master_v915_high_detail_authoring.glb',
            stage/'stk_master_v915_mobile_normal_bake_qa.glb',
            stage,stage,out)
        self.assertEqual(report['schema'],'stk_anatomy_torso_contours_v916')
        self.assertEqual(report['catalogCount'],229)
        self.assertEqual(report['newApproximateTorsoContours'],3)
        self.assertEqual(report['existingMuscleAtlasGroups'],11)
        self.assertEqual(report['skeletonJoints'],55)
        self.assertEqual(report['morphCount'],8)
        self.assertEqual(report['trianglesAddedToMobile'],0)
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        self.assertEqual(len(report['assets']),4)
        groups=report['geometry']['highVerticesByContour']
        self.assertEqual(set(groups),set(torso916.ARTIST_GROUPS))
        for region,min_hits in torso916.MIN_HIGH_HITS.items():
            self.assertGreaterEqual(groups[region],min_hits)
        self.assertEqual(report['geometry']['triangleFlips'],0)
        self.assertLessEqual(
            report['geometry']['maximumReliefMeters'],
            torso916.MAX_TORSO_RELIEF_METERS+.000001)
        for ex in (None,*rig.EXERCISES):
            basename='stk_master' if ex is None else ex
            old_hi=rig.GLB((stage/(
                basename+'_v915_high_detail_authoring.glb')
                ).read_bytes(),expected_sha=None)
            old_lo=rig.GLB((stage/(
                basename+'_v915_mobile_normal_bake_qa.glb')
                ).read_bytes(),expected_sha=None)
            hi=rig.GLB((out/(
                basename+'_v916_torso_high_qa.glb')
                ).read_bytes(),expected_sha=None)
            lo=rig.GLB((out/(
                basename+'_v916_torso_mobile_qa.glb')
                ).read_bytes(),expected_sha=None)
            for old,new in ((old_hi,hi),(old_lo,lo)):
                for field in ('skins','nodes','animations','meshes','materials'):
                    self.assertEqual(old.doc[field],new.doc[field],
                        (basename,field))
                self.assertEqual(new.doc['extras']['torsoContourArtVersion'],916)
                self.assertEqual(new.doc['extras']['torsoContourGroups'],
                                 list(torso916.ARTIST_GROUPS))
                self.assertFalse(new.doc['extras']['approved'])
                self.assertFalse(new.doc['extras']['enabled'])
                attrs=old.doc['meshes'][0]['primitives'][0]['attributes']
                for key in ('JOINTS_0','WEIGHTS_0'):
                    self.assertEqual(old.accessor(attrs[key]),
                                     new.accessor(attrs[key]),key)
                for t in old.doc['meshes'][0]['primitives'][0]['targets']:
                    self.assertEqual(old.accessor(t['POSITION']),
                                     new.accessor(t['POSITION']))
            ah=hi.doc['meshes'][0]['primitives'][0]['attributes']
            al=lo.doc['meshes'][0]['primitives'][0]['attributes']
            old_hi_p=old_hi.accessor(ah['POSITION'])
            new_hi_p=hi.accessor(ah['POSITION'])
            old_lo_p=old_lo.accessor(al['POSITION'])
            new_lo_p=lo.accessor(al['POSITION'])
            self.assertEqual(old_lo_p,new_lo_p)
            self.assertEqual(len(new_hi_p),19004)
            self.assertEqual(len(new_lo_p),4727)
            self.assertLessEqual(max(math.dist(a,b) for a,b in
                zip(old_hi_p,new_hi_p)),
                torso916.MAX_TORSO_RELIEF_METERS+.000001)
            self.assertGreater(sum(math.dist(a,b)>.00002 for a,b in
                zip(old_hi_p,new_hi_p)),450)
            modified_normals=sum(math.dist(a,b)>.0006 for a,b in zip(
                old_lo.accessor(al['NORMAL']),
                lo.accessor(al['NORMAL'])))
            self.assertGreater(modified_normals,torso916.MIN_LOW_CHANGED)
            self.assertTrue(all(abs(torso916.length(n)-1)<.0001
                for n in lo.accessor(al['NORMAL'])))
            self.assertEqual(old_hi.doc['meshes'][1:],
                             hi.doc['meshes'][1:],
                             'Do not change bench or moving bar geometry')
            measured=next(v for v in report['assets']
                          if v['exerciseId']==ex)
            self.assertGreater(
                measured['normalTransfer']['changedMobileNormals'],
                torso916.MIN_LOW_CHANGED)
            self.assertLessEqual(
                measured['normalTransfer']['maxNormalDeviationDegrees'],10.02)
            self.assertTrue(all(n>=12 for n in
                measured['normalTransfer']['changedNormalsByGroup'].values()))
            self.assertLess(measured['lowBytes'],
                850*1024 if ex is None else 1400*1024)
            self.assertLess(measured['highBytes'],6*1024*1024)
        self.assertTrue((out/'torso_contours_v916_report.json').is_file())

    def test_v916_bilateral_masks_are_bounded_and_untrusted_is_blocked(self):
        left=torso916.contour_fields((-.065,1.08,.15),(0,0,1))
        right=torso916.contour_fields((.065,1.08,.15),(0,0,1))
        self.assertEqual(left,right)
        self.assertGreater(left['rectus_abdominis'],.3)
        self.assertEqual(
            torso916.contour_fields((0,1.08,-.05),(0,0,-1))[
                'serratus_anterior'],0)
        self.assertEqual(
            torso916.contour_fields((.42,.34,.21),(0,0,1))[
                'obliquus_externus_abdominis'],0)
        self.assertRaises(ValueError,torso916.window,.5,.9,.8,.03)
        self.assertRaises(ValueError,torso916.window,.5,0,1,0)
        stage=self.MASTER/'v8_authoring'/'detail_bake_v915'
        if not (stage/'stk_master_v915_high_detail_authoring.glb').exists():
            self.test_v915_detail_transfer_preserves_exact_motion_and_mobile_mesh()
        raw=(stage/'stk_master_v915_high_detail_authoring.glb').read_bytes()
        changed=rig.GLB(raw,expected_sha=None)
        changed.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            torso916._validate_input(changed,changed)


    def test_v917_three_pilots_add_real_finger_clips_without_ik_regression(self):
        source=self.MASTER/'v8_authoring'/'detail_bake_v915'/'torso_v916'
        if not (source/'ex_squat_v916_torso_mobile_qa.glb').exists():
            self.test_v916_three_torso_contours_and_four_exact_55_joint_GLBS()
        out=source/'hand_v917'
        report=hand917.build(source,out)
        self.assertEqual(report['schema'],
            'stk_haven_v917_finger_ik_artist_preview')
        self.assertEqual(report['catalogCount'],229)
        self.assertEqual(report['variants'],6)
        self.assertEqual(report['fingerChannelsPerExercise'],30)
        self.assertEqual(len(report['files']),6)
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        for ex in rig.EXERCISES:
            for label,high in (('mobile',False),('high',True)):
                previous=rig.GLB((source/(ex+'_v916_torso_'+
                    ('high' if high else 'mobile')+'_qa.glb')).read_bytes(),
                    expected_sha=None)
                upgraded=rig.GLB((out/(ex+'_v917_finger_'+
                    label+'_qa.glb')).read_bytes(),expected_sha=None)
                for field in ('skins','nodes','meshes','materials','scenes'):
                    self.assertEqual(previous.doc[field],
                                     upgraded.doc[field],(ex,label,field))
                self.assertEqual(upgraded.doc['extras']['handGripArtVersion'],917)
                self.assertFalse(upgraded.doc['extras']['approved'])
                self.assertFalse(upgraded.doc['extras']['enabled'])
                self.assertFalse(upgraded.doc['extras'][
                    'fingerSurfaceToBarContactValidated'])
                old_clip=previous.doc['animations'][0]
                clip=upgraded.doc['animations'][0]
                self.assertEqual(clip['name'],old_clip['name'])
                self.assertEqual(clip['channels'][:len(old_clip['channels'])],
                                 old_clip['channels'])
                self.assertEqual(clip['samplers'][:len(old_clip['samplers'])],
                                 old_clip['samplers'])
                self.assertEqual(len(clip['channels']),
                                 len(old_clip['channels'])+30)
                for side in ('l','r'):
                    for digit in hand917.DIGITS:
                        for segment in hand917.SEGMENTS:
                            joint=upgraded.by_name[
                                f'{digit}_0{segment}_{side}']
                            track=[c for c in clip['channels']
                                   if c['target']=={'node':joint,
                                                  'path':'rotation'}]
                            self.assertEqual(len(track),1)
                            sampling=clip['samplers'][track[0]['sampler']]
                            self.assertEqual(len(upgraded.accessor(
                                sampling['output'])),41)
                base_tracks=self._tracks(previous)
                new_tracks=self._tracks(upgraded)
                for frame in range(121):
                    tick=frame/30.
                    base=world_at(previous,tick,base_tracks)
                    fresh=world_at(upgraded,tick,new_tracks)
                    for node in ('hand_l','hand_r','foot_l','foot_r',
                                 'STK_EXERCISE_BAR','head','pelvis'):
                        error=math.dist(base[previous.by_name[node]],
                                        fresh[upgraded.by_name[node]])
                        self.assertLess(error,.000001,
                            (ex,label,node,frame,'unchanged wrist/equipment'))
                    for side in ('l','r'):
                        bar=fresh[upgraded.by_name['STK_EXERCISE_BAR']]
                        hand=fresh[upgraded.by_name['hand_'+side]]
                        sign=1 if side=='l' else -1
                        distance=math.dist(hand,
                           (bar[0]+sign*(.51 if ex=='ex_squat' else .50),
                            bar[1],bar[2]))
                        self.assertLess(distance,.005,
                            (ex,label,side,frame,'original bar grip'))
                start=world_at(upgraded,0,new_tracks)
                raised=world_at(upgraded,2,new_tracks)
                finish=world_at(upgraded,4,new_tracks)
                for side in ('l','r'):
                    for digit in hand917.DIGITS:
                        name=f'{digit}_03_{side}'
                        index=upgraded.by_name[name]
                        self.assertLess(math.dist(start[index],
                                                  finish[index]),.00001)
                        self.assertGreater(math.dist(start[index],
                                                     raised[index]),.00010)
                for field in ('POSITION','NORMAL','WEIGHTS_0','JOINTS_0'):
                    attr=previous.doc['meshes'][0]['primitives'][0][
                        'attributes'][field]
                    self.assertEqual(previous.accessor(attr),
                                     upgraded.accessor(attr))
                measured=next(x for x in report['files']
                          if x['exerciseId']==ex and
                             x['highResolution']==high)
                self.assertLess(measured['maxFingerExcursionDegrees'],7.01)
                self.assertLess(measured[
                    'maxPerKeyframeAngularStepDegrees'],1.51)
                self.assertTrue(measured['wristIKUnchanged'])
                self.assertFalse(measured['fingertipSurfaceContactCertified'])
                self.assertLess(len((out/(ex+'_v917_finger_'+
                    label+'_qa.glb')).read_bytes()),
                    6*1024*1024 if high else 1400*1024)
        self.assertTrue((out/'finger_kinematics_v917_report.json').is_file())


    def test_v918_measured_finger_gaps_and_safe_wrist_orientation(self):
        pilot_root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                    'torso_v916'/'hand_v917')
        if not (pilot_root/'ex_squat_v917_finger_mobile_qa.glb').exists():
            self.test_v917_three_pilots_add_real_finger_clips_without_ik_regression()
        target=pilot_root/'contact_v918'
        summary=contact918.build(pilot_root,target)
        self.assertEqual(summary['schema'],
                         'stk_master_55_v918_conservative_wrist_contact_qa')
        self.assertEqual(summary['catalogCount'],229)
        self.assertEqual(summary['exercises'],3)
        self.assertFalse(summary['fingerPhysicalContactValidated'])
        self.assertFalse(summary['approved'])
        self.assertFalse(summary['enabled'])
        self.assertEqual(len(summary['assets']),6)
        for ex in rig.EXERCISES:
            for quality,high in (('mobile',False),('high',True)):
                old=rig.GLB((pilot_root/(
                    ex+'_v917_finger_'+quality+'_qa.glb')).read_bytes(),
                    expected_sha=None)
                new=rig.GLB((target/(
                    ex+'_v918_contact_'+quality+'_qa.glb')).read_bytes(),
                    expected_sha=None)
                for immutable in ('skins','nodes','meshes','materials','scenes'):
                    self.assertEqual(old.doc[immutable],new.doc[immutable],
                                     (ex,quality,immutable))
                a=old.doc['animations'][0];b=new.doc['animations'][0]
                self.assertEqual(a['name'],b['name'])
                self.assertEqual(b['channels'][:len(a['channels'])],
                                 a['channels'])
                self.assertEqual(b['samplers'][:len(a['samplers'])],
                                 a['samplers'])
                self.assertEqual(len(b['channels']),len(a['channels'])+2)
                for side in ('l','r'):
                    wrist=new.by_name['hand_'+side]
                    matches=[c for c in b['channels']
                             if c['target']=={
                                 'node':wrist,'path':'rotation'}]
                    self.assertEqual(len(matches),1)
                    out=b['samplers'][matches[0]['sampler']]['output']
                    self.assertEqual(len(new.accessor(out)),41)
                self.assertEqual(new.doc['extras'][
                    'gripContactCalibrationVersion'],918)
                self.assertFalse(new.doc['extras']['approved'])
                self.assertFalse(new.doc['extras']['enabled'])
                self.assertFalse(new.doc['extras'][
                    'fingerSurfaceToBarContactValidated'])
                result=next(v for v in summary['assets']
                            if v['exerciseId']==ex and
                               v['highResolution']==high)
                self.assertEqual(result['calibrated']['frames'],121)
                self.assertEqual(result['calibrated']['fps'],30)
                self.assertEqual(result['calibrated'][
                    'sampledDistalJointCenters'],1210)
                self.assertLess(result['calibrated'][
                    'meanPositiveGapMeters'],
                    result['baseline']['meanPositiveGapMeters']*.94)
                self.assertGreaterEqual(result['calibrated'][
                    'closestSignedGapMeters'],
                    contact918.PENETRATION_GUARD)
                self.assertGreater(result['calibrated'][
                    'worstPositiveGapMeters'],.01)
                self.assertTrue(result[
                    'wristPositionsIdenticalAt121Frames'])
                self.assertFalse(result['certifiedFingerSurfaceContact'])
                self.assertFalse(result['approved'])
                self.assertFalse(result['enabled'])
                self.assertLessEqual(result['maxPerKeyframeWristAngularStepDegrees'],
                                     contact918.MAX_STEP_DEG)
                for angle in result['maxWristOrientationDegrees'].values():
                    self.assertLessEqual(angle,contact918.MAX_ANGLE_DEG+.02)
                previous=old.doc['meshes'][0]['primitives'][0]['attributes']
                after=new.doc['meshes'][0]['primitives'][0]['attributes']
                for accessor in ('POSITION','NORMAL','JOINTS_0','WEIGHTS_0'):
                    self.assertEqual(old.accessor(previous[accessor]),
                                     new.accessor(after[accessor]),
                                     (ex,quality,accessor))
        self.assertTrue((target/'contact_gap_v918_report.json').exists())


    def test_v919_121_frame_real_finger_skin_and_bar_geometry_audit(self):
        source=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917')
        target=source/'contact_v918'
        if not (target/'ex_squat_v918_contact_mobile_qa.glb').is_file():
            self.test_v918_measured_finger_gaps_and_safe_wrist_orientation()
        out=target/'skin_v919'
        report=skin919.build(source,out)
        self.assertEqual(report['schema'],
            'stk_v919_real_skinned_fingertip_geometry_audit')
        self.assertEqual(report['pilotCount'],3)
        self.assertEqual(report['catalogCount'],229)
        self.assertEqual(report['rigJoints'],55)
        self.assertEqual(report['skinnedMorphTargets'],8)
        self.assertEqual(report['framesPerExercise'],121)
        self.assertFalse(report['certifiesFingertipContact'])
        self.assertFalse(report['collisionFreeCertified'])
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        self.assertEqual(len(report['pilots']),3)
        for pilot in report['pilots']:
            self.assertIn(pilot['exerciseId'],rig.EXERCISES)
            for version in ('v917','v918'):
                data=pilot[version]
                self.assertEqual(data['samplesPerGroup'],121)
                self.assertEqual(data['distalSurfaceGroups'],10)
                self.assertGreaterEqual(data['uniqueSkinnedSurfaceVertices'],60)
                self.assertEqual(data['totalVertexSkinEvaluations'],
                                 data['uniqueSkinnedSurfaceVertices']*121)
                self.assertFalse(data['surfaceContactCertified'])
                self.assertEqual(len(data['fingerSurfaceMetrics']),10)
                for name,entry in data['fingerSurfaceMetrics'].items():
                    self.assertEqual(entry['frames'],121)
                    self.assertGreaterEqual(entry['sampledMeshVertexCount'],6)
                    self.assertGreaterEqual(
                        entry['meanNearestPositiveGapMeters'],0.)
                    self.assertGreaterEqual(
                        entry['worstNearestPositiveGapMeters'],0.)
                    self.assertLessEqual(entry['framesWithin10mmOfShaft'],121)
                    self.assertGreaterEqual(
                        entry['framesPossibleSkinPenetrationOver2mm'],0)
            self.assertEqual(len(pilot['fingerComparisons']),10)
            self.assertFalse(pilot['skinContactCorrectlyCertified'])
            self.assertTrue(all(v['needsExpertVisualReview']
                for v in pilot['fingerComparisons'].values()))
        self.assertTrue(
            (out/'fingertip_skin_contact_v919_report.json').exists())

    def test_v919_refuses_untrusted_and_unavailable_finger_surfaces(self):
        source=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917')
        if not (source/'ex_squat_v917_finger_mobile_qa.glb').exists():
            self.test_v917_three_pilots_add_real_finger_clips_without_ik_regression()
        raw=(source/'ex_squat_v917_finger_mobile_qa.glb').read_bytes()
        old=rig.GLB(raw,expected_sha=None)
        old.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'Require disabled'):
            skin919._verified_mesh(old.bytes(),'ex_squat',False)
        self.assertRaises(ValueError,skin919.measure,raw,'ex_squat',True)
        self.assertRaises(ValueError,skin919.measure,raw,'not_valid',False)

    def test_v918_rejects_unsafe_or_approved_sources(self):
        self.assertRaises(ValueError,contact918.grip_pose,
                          (0.,0.,0.,1.),'ex_squat','l',-1)
        self.assertRaises(ValueError,contact918.grip_pose,
                          (0.,0.,0.,1.),'unknown','l',1)
        self.assertEqual(len(contact918.DIRECTIONS),3)
        self.assertEqual(len(contact918.DIGITS),5)
        self.assertEqual(contact918.FPS,30)
        folder=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917')
        if not (folder/'ex_squat_v917_finger_mobile_qa.glb').exists():
            self.test_v917_three_pilots_add_real_finger_clips_without_ik_regression()
        raw=(folder/'ex_squat_v917_finger_mobile_qa.glb').read_bytes()
        tampered=rig.GLB(raw,expected_sha=None)
        tampered.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'disabled original'):
            contact918.verify_input(tampered,'ex_squat',False)
        old=rig.GLB(raw,expected_sha=None)
        clip=old.doc['animations'][0]
        clip['channels'].append({
            'sampler':clip['channels'][0]['sampler'],
            'target':{'node':old.by_name['hand_l'],'path':'rotation'}})
        with self.assertRaises(ValueError):
            contact918.verify_input(old,'ex_squat',False)

    def test_v917_grip_curve_rejects_invalid_motions_and_source(self):
        self.assertAlmostEqual(hand917.grip_pressure(0,'ex_squat'),0)
        self.assertAlmostEqual(hand917.grip_pressure(4,'ex_squat'),0,
                               places=10)
        self.assertGreater(hand917.grip_pressure(2,'ex_bench_press'),
                           hand917.grip_pressure(2,'ex_squat'))
        self.assertRaises(ValueError,hand917.grip_pressure,5,'ex_squat')
        self.assertRaises(ValueError,hand917.grip_pressure,
                          2,'not_a_valid_exercise')
        self.assertEqual(len(hand917.FINGERS),30)
        path=self.MASTER/'v8_authoring'/'detail_bake_v915'/'torso_v916'
        if not (path/'ex_squat_v916_torso_mobile_qa.glb').exists():
            self.test_v916_three_torso_contours_and_four_exact_55_joint_GLBS()
        source=(path/'ex_squat_v916_torso_mobile_qa.glb').read_bytes()
        altered=rig.GLB(source,expected_sha=None)
        altered.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'Untrusted'):
            hand917.valid_source(altered,'ex_squat',False)

    def test_v915_refuses_invalid_provenance_and_bad_normal_map(self):
        folder=self.MASTER/'v8_authoring'
        if not (folder/'stk_master_v8_anatomy_preview.glb').exists():
            self.test_v913_11_bilateral_regions_and_three_consistent_55_joint_pilots()
        old=rig.GLB(
            (folder/'stk_master_v8_anatomy_preview.glb').read_bytes(),
            expected_sha=None)
        old.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'Untrusted'):
            detail915._assert_source(old,False)
        with self.assertRaises(ValueError):
            detail915._bake_normals([(0,0,0)],[],[],[],[])

    def test_v914_rejects_unsafe_joint_palettes_and_approved_source(self):
        self.assertRaises(ValueError,hires914.blended_joint,
            (0,1,2,3),(.25,)*4,(4,5,6,7),(.25,)*4)
        self.assertRaises(ValueError,hires914.normalized,(0,0,0))
        prior=self.MASTER/'v8_authoring'/'stk_master_v8_anatomy_preview.glb'
        if not prior.exists():
            self.test_v913_11_bilateral_regions_and_three_consistent_55_joint_pilots()
        before=rig.GLB(prior.read_bytes(),expected_sha=None)
        before.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'disabled and trusted'):
            hires914.check_source(before)

    def test_v913_rejects_untrusted_or_approved_legacy_geometry(self):
        old=rig.GLB(
            (self.MASTER/'stk_master_v7_surface_preview.glb').read_bytes(),
            expected_sha=None)
        old.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'trusted unapproved'):
            anatomy913._check_base(old)
        self.assertEqual(len(anatomy913.REGION_ORDER),11)

    def test_v99_rejects_unknown_ids_and_prematurely_approved_pilots(self):
        sample=rig.GLB(
            (OUT/'ex_bench_press_mobile_lod.glb').read_bytes(),
            expected_sha=None)
        self.assertRaises(ValueError,master55._valid_inputs,
                          self.master,sample,'ex_not_real')
        sample.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'disabled 53'):
            master55._valid_inputs(self.master,sample,'ex_bench_press')


if __name__ == "__main__":
    unittest.main()
