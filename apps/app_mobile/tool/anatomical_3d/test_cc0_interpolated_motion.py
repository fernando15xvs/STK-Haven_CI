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
import sculpt_finger_pads_v920 as pads920
import audit_finger_triangles_v921 as triangles921
import refine_fingertip_topology_v922 as topology922
import audit_finger_contact_bounds_v923 as contact923
import sculpt_palm_thenar_v924 as palm924
import refine_palm_thumb_web_v925 as web925
import optimize_finger_grip_v926 as grip926
import audit_grip_temporal_v927 as temporal927
import stabilize_grip_v928 as stabilize928
import optimize_two_joint_grip_v929 as twojoint929
import sculpt_finger_knuckles_v930 as knuckle930
import sculpt_finger_folds_v931 as fold931
import sculpt_nail_beds_v932 as nail932
import build_rig_nail_plates_v933 as nail933
import nail_plate_skin_proximity_v934 as nailproximity934
import nail_plate_offsets_v935 as nailoffset935
import build_nail_medium_lod_v936 as naillod936
import fit_thumb_nail_skin_v937 as thumb937
import optimize_left_thumb_nail_v938 as left938

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

    def test_v920_bounded_real_fingertip_pad_candidates_preserve_55_rig(self):
        origin=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917')
        inputs=origin/'contact_v918'
        if not (inputs/'ex_squat_v918_contact_mobile_qa.glb').exists():
            self.test_v918_measured_finger_gaps_and_safe_wrist_orientation()
        output=inputs/'skin_v919'/'hand_v920'
        report=pads920.build(origin,output)
        self.assertEqual(report['schema'],
            'stk_v920_bounded_hand_surface_review')
        self.assertEqual(report['pilotCount'],3)
        self.assertEqual(report['catalogCount'],229)
        self.assertEqual(report['rigJoints'],55)
        self.assertEqual(report['framesPerExercise'],121)
        self.assertTrue(report['zeroTopologyChanges'])
        self.assertFalse(report['actualFingertipRetopologyCompleted'])
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        self.assertEqual(len(report['pilots']),3)
        for pilot in report['pilots']:
            ex=pilot['exerciseId']
            before=rig.GLB((inputs/(ex+'_v918_contact_mobile_qa.glb')
                            ).read_bytes(),expected_sha=None)
            after=rig.GLB((output/(ex+'_v920_hand_surface_mobile_qa.glb')
                           ).read_bytes(),expected_sha=None)
            self.assertEqual(before.doc['skins'],after.doc['skins'])
            self.assertEqual(before.doc['animations'],after.doc['animations'])
            self.assertEqual(before.doc['meshes'],after.doc['meshes'])
            old_attr=before.doc['meshes'][0]['primitives'][0]['attributes']
            new_attr=after.doc['meshes'][0]['primitives'][0]['attributes']
            self.assertEqual(old_attr,new_attr)
            self.assertEqual(before.accessor(old_attr['JOINTS_0']),
                             after.accessor(new_attr['JOINTS_0']))
            self.assertEqual(before.accessor(old_attr['WEIGHTS_0']),
                             after.accessor(new_attr['WEIGHTS_0']))
            for old_target,new_target in zip(
                before.doc['meshes'][0]['primitives'][0]['targets'],
                after.doc['meshes'][0]['primitives'][0]['targets']):
                self.assertEqual(before.accessor(old_target['POSITION']),
                                 after.accessor(new_target['POSITION']))
            old_pos=before.accessor(old_attr['POSITION'])
            new_pos=after.accessor(new_attr['POSITION'])
            edits=[math.dist(a,b) for a,b in zip(old_pos,new_pos)]
            self.assertGreaterEqual(sum(x>1e-6 for x in edits),10)
            self.assertLessEqual(max(edits),pads920.MAX_PAD_METERS+2e-7)
            self.assertGreater(pilot['changedPositionVertices'],9)
            self.assertEqual(pilot['invertedTriangles'],0)
            self.assertEqual(len(pilot['distalGroups']),10)
            self.assertEqual(len(pilot['skinnedGapComparison']),10)
            self.assertTrue(all(v['expertReviewPending'] for v
                in pilot['skinnedGapComparison'].values()))
            self.assertEqual(after.doc['extras']['fingerPadReviewVersion'],920)
            self.assertFalse(after.doc['extras']['approved'])
            self.assertFalse(after.doc['extras']['enabled'])
        self.assertTrue((output/'hand_surface_v920_report.json').exists())

    def test_v920_rejects_unapproved_input_spoofing_and_double_sculpt(self):
        source=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917'/'contact_v918')
        if not (source/'ex_squat_v918_contact_mobile_qa.glb').exists():
            self.test_v918_measured_finger_gaps_and_safe_wrist_orientation()
        raw=(source/'ex_squat_v918_contact_mobile_qa.glb').read_bytes()
        old=rig.GLB(raw,expected_sha=None)
        old.doc['extras']['approved']=True
        with self.assertRaisesRegex(ValueError,'Require disabled'):
            pads920.sculpt(old.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            pads920.sculpt(raw,'not_an_exercise')
        proposed,_=pads920.sculpt(raw,'ex_squat')
        with self.assertRaisesRegex(ValueError,'Refuse repeated'):
            pads920.sculpt(proposed,'ex_squat')

    def test_v921_triangle_interior_catches_crossings_missed_by_vertices(self):
        # All three corners are outside the bar; the centre of the *actual
        # rendered triangle* crosses the finite cylindrical shaft.
        a,b,c=(0.,-.07,0.),(0.,.07,0.),(0.,0.,.07)
        corner_gaps=[surface.capped_cylinder_sdf(
            p, triangles921.SHAFT_MIN_X, triangles921.SHAFT_MAX_X,
            triangles921.SHAFT_RADIUS) for p in (a,b,c)]
        self.assertTrue(all(gap>.03 for gap in corner_gaps))
        crossing=triangles921.triangle_probe(a,b,c)
        self.assertLess(crossing,-.002)
        self.assertGreater(triangles921.triangle_probe(
            (1.7,-.07,0.),(1.7,.07,0.),(1.7,0.,.07)),.5)
        # A physically rotated bar must use inverse bar orientation; a
        # world-space X-axis-only proximity test would be wrong.
        turn=rig.qnorm((0.,0.,math.sin(math.pi/4),math.cos(math.pi/4)))
        world=[rig.qrot(turn,p) for p in (a,b,c)]
        local=[rig.qrot(rig.qconj(turn),p) for p in world]
        self.assertAlmostEqual(triangles921.triangle_probe(*local),
                               crossing,places=8)
        with self.assertRaises(ValueError):
            triangles921.triangle_probe((math.nan,0,0),b,c)

    def test_v921_report_actual_skinned_triangles_are_quarantined(self):
        origin=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917')
        candidate=origin/'contact_v918'/'skin_v919'/'hand_v920'
        if not (candidate/'ex_squat_v920_hand_surface_mobile_qa.glb').exists():
            self.test_v920_bounded_real_fingertip_pad_candidates_preserve_55_rig()
        out=candidate/'triangle_v921'
        summary=triangles921.build(origin,out)
        self.assertEqual(summary['schema'],
            'stk_v921_skinned_triangle_bar_proximity_qa')
        self.assertEqual(summary['pilotCount'],3)
        self.assertEqual(summary['catalogCount'],229)
        self.assertEqual(summary['rigJoints'],55)
        self.assertEqual(summary['morphTargets'],8)
        self.assertEqual(summary['frames'],121)
        self.assertEqual(summary['pointSamplesPerTriangle'],7)
        self.assertTrue(summary['barFrameIncludesAnimatedQuaternion'])
        self.assertFalse(summary['retopologyComplete'])
        self.assertFalse(summary['contactIKComplete'])
        self.assertFalse(summary['continuousCollisionCertified'])
        self.assertFalse(summary['approved'])
        self.assertFalse(summary['enabled'])
        for pilot in summary['pilots']:
            self.assertEqual(len(pilot['perFingerComparison']),10)
            self.assertFalse(pilot['fingertipCollisionResolved'])
            for version in ('v918','v920'):
                view=pilot[version]
                self.assertFalse(view['approved'])
                self.assertFalse(view['enabled'])
                self.assertFalse(view['exactTriangleCylinderIntersectionCertified'])
                self.assertEqual(view['framesPerExercise'],121)
                self.assertEqual(view['fingerRegions'],10)
                self.assertTrue(view['triangleInteriorSamples'])
                self.assertGreaterEqual(
                    view['uniqueSkinnedVerticesPerFrame'],60)
                self.assertEqual(len(view['surfaceMetrics']),10)
                for region in view['surfaceMetrics'].values():
                    self.assertGreater(region['trianglesPerFrame'],0)
                    self.assertEqual(region['frames'],121)
                    self.assertEqual(region['barycentricSamplesPerTriangle'],7)
                    self.assertEqual(region['totalSurfaceSamples'],
                        121*7*region['trianglesPerFrame'])
                    self.assertLessEqual(region['framesWithin10mmOfShaft'],121)
                    self.assertGreaterEqual(
                        region['framesPossibleTrianglePenetrationOver2mm'],0)
            for region in pilot['perFingerComparison'].values():
                self.assertTrue(region[
                    'requiresFingerRetopologyAndContactSolverReview'])
        self.assertTrue((out/'finger_triangle_bar_v921_report.json').is_file())
        exercise='ex_squat'
        raw=(candidate/(exercise+'_v920_hand_surface_mobile_qa.glb')
             ).read_bytes()
        self.assertRaises(ValueError, triangles921.audit,raw,
                          exercise,candidate=False)
        altered=rig.GLB(raw,expected_sha=None)
        altered.doc['extras']['enabled']=True
        with self.assertRaises(ValueError):
            triangles921.audit(altered.bytes(),exercise,candidate=True)

    def test_v922_conforming_face_patterns_and_shared_edges(self):
        cases=[
            ({},1),
            ({(0,1):4},2),
            ({(0,1):4,(1,2):5},3),
            ({(0,1):4,(1,2):5,(0,2):6},4),
        ]
        for edges,total in cases:
            f=topology922._split(0,1,2,edges)
            self.assertEqual(len(f),total)
            self.assertTrue(all(len(set(tri))==3 for tri in f))
            self.assertEqual(sum(len(tri) for tri in f),total*3)
        # A neighbouring opposite-side primitive uses the SAME midpoint.
        midpoint={(0,1):5}
        left=topology922._split(0,1,2,midpoint)
        right=topology922._split(1,0,3,midpoint)
        self.assertEqual(sum(5 in face for face in left),2)
        self.assertEqual(sum(5 in face for face in right),2)

    def test_v922_real_local_finger_mesh_retopology_mobile_budget(self):
        origin=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917')
        pad=origin/'contact_v918'/'skin_v919'/'hand_v920'
        if not (pad/'ex_squat_v920_hand_surface_mobile_qa.glb').exists():
            self.test_v920_bounded_real_fingertip_pad_candidates_preserve_55_rig()
        target=pad/'topology_v922'
        report=topology922.build(origin,target)
        self.assertEqual(report['schema'],
            'stk_v922_real_local_finger_mesh_subdivision')
        self.assertEqual(report['pilotCount'],3)
        self.assertEqual(report['catalogCount'],229)
        self.assertEqual(report['jointCount'],55)
        self.assertEqual(report['morphTargets'],8)
        self.assertTrue(report['topologyActuallyChanged'])
        self.assertFalse(report['contactIKComplete'])
        self.assertFalse(report['fullAnatomicalHandRetopologyComplete'])
        self.assertFalse(report['productionReady'])
        self.assertFalse(report['approved'])
        self.assertFalse(report['enabled'])
        for pilot in report['pilots']:
            ex=pilot['exerciseId']
            original=rig.GLB((pad/(ex+'_v920_hand_surface_mobile_qa.glb')
                              ).read_bytes(),expected_sha=None)
            dst=target/(ex+'_v922_fingertip_mesh_mobile_qa.glb')
            updated=rig.GLB(dst.read_bytes(),expected_sha=None)
            self.assertEqual(original.doc['skins'],updated.doc['skins'])
            self.assertEqual(original.doc['nodes'],updated.doc['nodes'])
            self.assertEqual(original.doc['animations'],updated.doc['animations'])
            self.assertEqual(original.doc['materials'],updated.doc['materials'])
            self.assertEqual(len(original.doc['accessors']),
                             len(updated.doc['accessors']))
            self.assertEqual(len(original.doc['bufferViews']),
                             len(updated.doc['bufferViews']))
            beforeparts=original.doc['meshes'][0]['primitives']
            afterparts=updated.doc['meshes'][0]['primitives']
            self.assertEqual(len(afterparts),12)
            self.assertEqual(len(beforeparts),len(afterparts))
            before=beforeparts[0]['attributes']
            after=afterparts[0]['attributes']
            self.assertEqual(before,after)
            self.assertEqual(pilot['sourceVertices'],4727)
            self.assertEqual(pilot['originalTriangles'],9843)
            self.assertGreater(pilot['edgeMidpointVerticesAdded'],60)
            self.assertLessEqual(pilot['edgeMidpointVerticesAdded'],
                                 topology922.MAX_NEW_VERTICES)
            self.assertEqual(pilot['newVertices'],
                             4727+pilot['edgeMidpointVerticesAdded'])
            self.assertGreater(pilot['retopologizedTriangles'],9843)
            self.assertLess(pilot['retopologizedTriangles'],20001)
            self.assertLess(pilot['mobileBytes'],topology922.MAX_MOBILE_BYTES)
            self.assertTrue(pilot['topologyConforming'])
            self.assertFalse(pilot['handProportionCorrectionCompleted'])
            self.assertFalse(pilot['contactIKCompleted'])
            self.assertEqual(updated.doc['extras']['fingerLocalRetopologyVersion'],922)
            self.assertFalse(updated.doc['extras']['approved'])
            self.assertFalse(updated.doc['extras']['enabled'])
            for label in ('POSITION','NORMAL','JOINTS_0','WEIGHTS_0'):
                before_rows=original.accessor(before[label])
                after_rows=updated.accessor(after[label])
                self.assertEqual(before_rows,after_rows[:len(before_rows)])
                self.assertEqual(len(after_rows),pilot['newVertices'])
            for before_morph,after_morph in zip(beforeparts[0]['targets'],
                                                afterparts[0]['targets']):
                b=original.accessor(before_morph['POSITION'])
                a=updated.accessor(after_morph['POSITION'])
                self.assertEqual(b,a[:len(b)])
                self.assertEqual(len(a),pilot['newVertices'])
            weights=updated.accessor(after['WEIGHTS_0'])
            joints=updated.accessor(after['JOINTS_0'])
            for a,b in zip(joints[4727:],weights[4727:]):
                self.assertTrue(all(0<=int(x)<55 for x in a))
                self.assertAlmostEqual(sum(b),1.,places=4)
            for before_part,after_part in zip(beforeparts,afterparts):
                self.assertEqual(before_part['material'],after_part['material'])
                self.assertEqual(before_part['attributes'],after_part['attributes'])
                self.assertEqual(before_part['targets'],after_part['targets'])
                before_ids=original.accessor(before_part['indices'])
                after_ids=updated.accessor(after_part['indices'])
                self.assertGreaterEqual(len(after_ids),len(before_ids))
                self.assertTrue(all(0<=v[0]<pilot['newVertices']
                                    for v in after_ids))
        self.assertTrue((target/'fingertip_topology_v922_report.json').is_file())

    def test_v922_rejects_approved_glb_and_double_subdivision(self):
        origin=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917'/'contact_v918'/
                'skin_v919'/'hand_v920')
        raw=(origin/'ex_squat_v920_hand_surface_mobile_qa.glb').read_bytes()
        old=rig.GLB(raw,expected_sha=None)
        old.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            topology922.retopologize(old.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            topology922.retopologize(raw,'bogus')
        candidate,_=topology922.retopologize(raw,'ex_squat')
        with self.assertRaises(ValueError):
            topology922.retopologize(candidate,'ex_squat')


    def test_v923_conservative_bounds_on_real_triangle_surfaces(self):
        far = contact923.bounded_triangle(
            (0., .40, .0), (.002, .40, .0), (0., .402, 0.))
        self.assertEqual(far['classification'], 'separated_at_sampled_pose')
        self.assertGreater(far['lower'], 0.)
        crossing = contact923.bounded_triangle(
            (0., -.06, 0.), (0., .06, 0.), (.008, 0., 0.))
        self.assertEqual(crossing['classification'], 'sampled_penetration')
        self.assertLess(crossing['upper'], 0.)
        self.assertLessEqual(crossing['lower'], crossing['upper'])
        with self.assertRaises(ValueError):
            contact923.bounded_triangle(
                (float('nan'), 0., 0.), (0., 0., 0.), (0., .1, 0.))
        with self.assertRaises(ValueError):
            contact923.bounded_triangle(
                (0., .1, 0.), (0., .2, 0.), (0., .3, 0.), depth=-1)

    def test_v923_bounded_real_finger_contact_remains_qa_only(self):
        parent=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917'/'contact_v918'/
                'skin_v919'/'hand_v920')
        src=parent/'topology_v922'
        if not (src/'ex_squat_v922_fingertip_mesh_mobile_qa.glb').exists():
            topology922.build(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                              'torso_v916'/'hand_v917', src)
        out=src/'contact_bounds_v923'
        result=contact923.build(src, out)
        self.assertEqual(result['pilotCount'], 3)
        self.assertEqual(result['sampledPoseCount'], 9)
        self.assertFalse(result['continuousTimeCollisionCertified'])
        self.assertFalse(result['fingerIKSolved'])
        self.assertFalse(result['approved'])
        self.assertFalse(result['enabled'])
        for pilot in result['pilots']:
            self.assertEqual(pilot['rigJoints'], 55)
            self.assertEqual(len(pilot['fingerRegions']), 10)
            self.assertFalse(pilot['contactIKCompleted'])
            self.assertEqual(pilot['sampledFrames'], list(range(0,121,15)))
            for finger in pilot['fingerRegions'].values():
                self.assertGreater(finger['trianglesPerFrame'], 0)
                self.assertEqual(finger['evaluatedTriangles'],
                                 9*finger['trianglesPerFrame'])
                self.assertEqual(
                    sum(finger[k] for k in (
                        'sampledPenetrationFrames', 'separatedFrames',
                        'unresolvedFrames')), 9)
        self.assertTrue((out/'finger_contact_bounds_v923.json').is_file())
        raw=(src/'ex_squat_v922_fingertip_mesh_mobile_qa.glb').read_bytes()
        forged=rig.GLB(raw, expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            contact923.audit(forged.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            contact923.audit(raw,'fake_exercise')


    def test_v924_real_palm_thenar_sculpt_preserves_retopology_and_ik(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/
              'skin_v919'/'hand_v920'/'topology_v922')
        if not (root/'ex_squat_v922_fingertip_mesh_mobile_qa.glb').exists():
            topology922.build(root.parent,root)
        out=root/'palm_v924'
        summary=palm924.build(root,out)
        self.assertEqual(summary['catalogCount'],229)
        self.assertEqual(summary['rigJoints'],55)
        self.assertFalse(summary['approved'])
        self.assertFalse(summary['productionReady'])
        for pilot in summary['pilots']:
            exercise=pilot['exerciseId']
            source=rig.GLB((root/(exercise+'_v922_fingertip_mesh_mobile_qa.glb'))
                           .read_bytes(), expected_sha=None)
            target=rig.GLB(
                (out/(exercise+'_v924_palm_thumb_surface_mobile_qa.glb'))
                .read_bytes(), expected_sha=None)
            self.assertEqual(source.doc['skins'],target.doc['skins'])
            self.assertEqual(source.doc['nodes'],target.doc['nodes'])
            self.assertEqual(source.doc['animations'],target.doc['animations'])
            self.assertEqual(source.doc['materials'],target.doc['materials'])
            self.assertEqual(source.doc['meshes'],target.doc['meshes'])
            self.assertEqual(source.doc['accessors'],target.doc['accessors'])
            self.assertEqual(target.doc['extras']['palmThumbSculptVersion'],924)
            self.assertFalse(target.doc['extras']['approved'])
            self.assertFalse(target.doc['extras']['enabled'])
            a=source.doc['meshes'][0]['primitives'][0]['attributes']
            b=target.doc['meshes'][0]['primitives'][0]['attributes']
            self.assertEqual(a,b)
            old_positions=source.accessor(a['POSITION'])
            new_positions=target.accessor(b['POSITION'])
            changed=[i for i,(x,y) in enumerate(zip(old_positions,new_positions))
                     if math.dist(x,y)>0.000005]
            self.assertGreaterEqual(len(changed),16)
            self.assertEqual(len(old_positions),len(new_positions))
            self.assertLessEqual(pilot['maximumDisplacementMeters'],
                                 palm924.MAX_DISPLACEMENT_METERS+.000001)
            self.assertGreater(pilot['maximumDisplacementMeters'],0)
            self.assertGreater(pilot['normalsRecomputedForVertices'],0)
            for side in ('l','r'):
                self.assertGreaterEqual(
                    pilot['bilateralEditedVertices'][side],
                    palm924.MIN_CHANGED_PER_HAND)
                self.assertGreaterEqual(
                    pilot['bilateralThenarVertices'][side],3)
            for key in ('JOINTS_0','WEIGHTS_0'):
                self.assertEqual(source.accessor(a[key]),
                                 target.accessor(b[key]))
            for sp,tp in zip(source.doc['meshes'][0]['primitives'],
                             target.doc['meshes'][0]['primitives']):
                self.assertEqual(source.accessor(sp['indices']),
                                 target.accessor(tp['indices']))
                for sm,tm in zip(sp['targets'],tp['targets']):
                    self.assertEqual(source.accessor(sm['POSITION']),
                                     target.accessor(tm['POSITION']))
            self.assertEqual(palm924._oriented(
                old_positions,new_positions,
                palm924._triangles(source,len(old_positions))),0)
        self.assertTrue((out/'palm_thenar_surface_v924_report.json').is_file())

    def test_v924_rejects_approved_and_already_modified_mesh(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/
              'skin_v919'/'hand_v920'/'topology_v922')
        if not (root/'ex_squat_v922_fingertip_mesh_mobile_qa.glb').exists():
            topology922.build(root.parent,root)
        original=(root/'ex_squat_v922_fingertip_mesh_mobile_qa.glb').read_bytes()
        denied=rig.GLB(original,expected_sha=None)
        denied.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            palm924.sculpt(denied.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            palm924.sculpt(original,'not_real')
        output,report=palm924.sculpt(original,'ex_squat')
        self.assertFalse(report['approved'])
        with self.assertRaises(ValueError):
            palm924.sculpt(output,'ex_squat')


    def test_v925_conforming_real_palm_thumb_topology(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922')
        palm=root/'palm_v924'
        if not (palm/'ex_squat_v924_palm_thumb_surface_mobile_qa.glb').exists():
            palm924.build(root,palm)
        target=palm/'web_v925'
        report=web925.build(palm,target)
        self.assertEqual(report['pilotCount'],3)
        self.assertFalse(report['approved'])
        self.assertFalse(report['contactIKComplete'])
        for item in report['pilots']:
            exercise=item['exerciseId']
            before=rig.GLB(
                (palm/(exercise+'_v924_palm_thumb_surface_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            after=rig.GLB(
                (target/(exercise+'_v925_palm_web_topology_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            self.assertEqual(before.doc['skins'],after.doc['skins'])
            self.assertEqual(before.doc['nodes'],after.doc['nodes'])
            self.assertEqual(before.doc['animations'],after.doc['animations'])
            self.assertEqual(before.doc['materials'],after.doc['materials'])
            self.assertEqual(after.doc['extras']['palmThumbRetopologyVersion'],925)
            self.assertFalse(after.doc['extras']['approved'])
            self.assertFalse(after.doc['extras']['enabled'])
            self.assertGreater(item['newPalmVertices'],40)
            self.assertLessEqual(item['newPalmVertices'],web925.MAX_NEW_VERTICES)
            self.assertEqual(item['resultVertices'],
                             item['sourceVertices']+item['newPalmVertices'])
            self.assertGreater(item['resultTriangles'],item['sourceTriangles'])
            self.assertLessEqual(item['resultTriangles'],
                                 web925.MAX_TOTAL_TRIANGLES)
            self.assertLessEqual(item['assetBytes'],web925.MAX_MOBILE_BYTES)
            for side in ('l','r'):
                self.assertGreaterEqual(
                    item['bilateralRegions'][side]['edgeSplits'],
                    web925.MIN_EDGES_PER_HAND)
                self.assertGreaterEqual(
                    item['bilateralRegions'][side]['thenarEdgeSplits'],
                    web925.MIN_THENAR_EDGES_PER_HAND)
            x=before.doc['meshes'][0]['primitives'][0]['attributes']
            y=after.doc['meshes'][0]['primitives'][0]['attributes']
            self.assertEqual(x,y)
            for key in ('POSITION','NORMAL','JOINTS_0','WEIGHTS_0'):
                a=before.accessor(x[key])
                b=after.accessor(y[key])
                self.assertEqual(a,b[:len(a)])
                self.assertEqual(len(b),item['resultVertices'])
            for previous,updated in zip(
                    before.doc['meshes'][0]['primitives'],
                    after.doc['meshes'][0]['primitives']):
                self.assertEqual(previous['material'],updated['material'])
                self.assertEqual(previous['targets'],updated['targets'])
                self.assertEqual(previous['attributes'],updated['attributes'])
                self.assertGreaterEqual(
                    len(after.accessor(updated['indices'])),
                    len(before.accessor(previous['indices'])))
                for a,b in zip(previous['targets'],updated['targets']):
                    old=before.accessor(a['POSITION'])
                    new=after.accessor(b['POSITION'])
                    self.assertEqual(old,new[:len(old)])
        self.assertTrue((target/'palm_thumb_topology_v925_report.json').exists())

    def test_v925_refuses_approved_or_double_subdivision(self):
        folder=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
                'hand_v920'/'topology_v922'/'palm_v924')
        if not (folder/'ex_squat_v924_palm_thumb_surface_mobile_qa.glb').exists():
            palm924.build(folder.parent,folder)
        raw=(folder/'ex_squat_v924_palm_thumb_surface_mobile_qa.glb').read_bytes()
        forged=rig.GLB(raw,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            web925.retopologize(forged.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            web925.retopologize(raw,'bogus')
        output,_=web925.retopologize(raw,'ex_squat')
        with self.assertRaises(ValueError):
            web925.retopologize(output,'ex_squat')


    def test_v926_finger_rotation_candidate_is_bounded_and_loop_safe(self):
        self.assertEqual(grip926.envelope(0.),0)
        self.assertEqual(grip926.envelope(4.),0)
        self.assertAlmostEqual(grip926.envelope(2.),1.)
        self.assertAlmostEqual(grip926.envelope(1.),.5)
        with self.assertRaises(ValueError):
            grip926.envelope(float('nan'))
        identity=[(0.,0.,0.,1.) for _ in range(41)]
        candidate=grip926.corrected_track(identity,3.)
        self.assertEqual(candidate[0],identity[0])
        self.assertEqual(candidate[-1],identity[-1])
        self.assertAlmostEqual(hand917.quaternion_distance_degrees(
            identity[20],candidate[20]),3.,places=4)
        with self.assertRaises(ValueError):
            grip926.corrected_track(identity,5.)
        with self.assertRaises(ValueError):
            grip926.corrected_track(identity[:4],1.)

    def test_v926_real_skinned_grip_candidate_does_not_change_rig_or_assets(self):
        parent=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
                'hand_v920'/'topology_v922'/'palm_v924')
        web=parent/'web_v925'
        if not (web/'ex_squat_v925_palm_web_topology_mobile_qa.glb').is_file():
            web925.build(parent,web)
        dest=web/'grip_v926'
        report=grip926.build(web,dest)
        self.assertEqual(report['pilotCount'],3)
        self.assertFalse(report['fullContactIKCompleted'])
        self.assertFalse(report['approved'])
        for pilot in report['pilots']:
            exercise=pilot['exerciseId']
            before=rig.GLB(
                (web/(exercise+'_v925_palm_web_topology_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            after=rig.GLB(
                (dest/(exercise+'_v926_grip_optimized_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            for name in ('skins','nodes','meshes','animations','materials'):
                self.assertEqual(before.doc[name],after.doc[name])
            self.assertEqual(
                after.doc['extras']['fingerContactOptimizerVersion'],926)
            self.assertFalse(after.doc['extras']['approved'])
            self.assertFalse(after.doc['extras']['enabled'])
            self.assertEqual(pilot['fingerTracksPreserved'],30)
            self.assertEqual(pilot['fingersEvaluated'],10)
            self.assertLessEqual(pilot['editedTracks'],10)
            self.assertFalse(pilot['fullContactIKCompleted'])
            self.assertLessEqual(pilot['outputBytes'],grip926.MAX_MOBILE_BYTES)
            self.assertEqual(len(pilot['fingerReports']),10)
            for record in pilot['fingerReports'].values():
                self.assertEqual(record['candidatesConsidered'],12)
                self.assertEqual(record['sampledFrames'],[10,20,30])
                if record['accepted']:
                    self.assertLess(record['candidateScore'],
                                    record['baselineScore'])
                    self.assertLessEqual(abs(record['degrees']),
                                         grip926.MAX_EXTRA_DEGREES)
                    self.assertGreaterEqual(
                        record['candidateWorstSignedMeters']+
                        grip926.MAX_DEEPER_METERS,
                        record['baselineWorstSignedMeters']-1e-8)
            for part_b,part_a in zip(before.doc['meshes'][0]['primitives'],
                                     after.doc['meshes'][0]['primitives']):
                self.assertEqual(before.accessor(part_b['indices']),
                                 after.accessor(part_a['indices']))
                for attribute in ('POSITION','NORMAL','JOINTS_0','WEIGHTS_0'):
                    self.assertEqual(
                        before.accessor(part_b['attributes'][attribute]),
                        after.accessor(part_a['attributes'][attribute]))
                for x,y in zip(part_b['targets'],part_a['targets']):
                    self.assertEqual(before.accessor(x['POSITION']),
                                     after.accessor(y['POSITION']))
        self.assertTrue((dest/'grip_optimizer_v926_report.json').is_file())

    def test_v926_rejects_non_pilot_and_already_corrected_files(self):
        folder=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
                'hand_v920'/'topology_v922'/'palm_v924'/'web_v925')
        if not (folder/'ex_squat_v925_palm_web_topology_mobile_qa.glb').exists():
            web925.build(folder.parent,folder)
        raw=(folder/'ex_squat_v925_palm_web_topology_mobile_qa.glb'
             ).read_bytes()
        forged=rig.GLB(raw,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            grip926.optimize(forged.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            grip926.optimize(raw,'bogus')
        candidate,details=grip926.optimize(raw,'ex_squat')
        self.assertFalse(details['approved'])
        with self.assertRaises(ValueError):
            grip926.optimize(candidate,'ex_squat')


    def test_v927_signed_regression_classifier_and_60hz_sampling(self):
        self.assertEqual(temporal927.FPS,60)
        self.assertEqual(temporal927.FRAMES,241)
        self.assertFalse(temporal927.regression(.003,.0028))
        self.assertTrue(temporal927.regression(-.002,-.0028))
        with self.assertRaises(ValueError):
            temporal927.regression(float('nan'),0.)

    def test_v927_three_pilots_review_real_skin_241_frames(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925')
        candidate=root/'grip_v926'
        if not (candidate/'ex_squat_v926_grip_optimized_mobile_qa.glb').exists():
            grip926.build(root,candidate)
        output=candidate/'temporal_v927'
        summary=temporal927.build(root,candidate,output)
        self.assertEqual(summary['pilotCount'],3)
        self.assertEqual(summary['sampledFramesPerExercise'],241)
        self.assertFalse(summary['continuousCollisionCertified'])
        self.assertFalse(summary['approved'])
        for pilot in summary['pilots']:
            self.assertEqual(pilot['frames'],241)
            self.assertEqual(pilot['betweenKeyframeSamples'],200)
            self.assertEqual(len(pilot['fingerResults']),10)
            self.assertFalse(pilot['contactIKCompleted'])
            self.assertFalse(pilot['enabled'])
            for finger in pilot['fingerResults'].values():
                a=finger['baselineSignedDistanceTraceMeters']
                b=finger['candidateSignedDistanceTraceMeters']
                self.assertEqual(len(a),241)
                self.assertEqual(len(b),241)
                self.assertEqual(
                    len(finger['regressionFrames']),
                    sum(temporal927.regression(x,y)
                        for x,y in zip(a,b)))
                self.assertTrue(all(n%6 for n in
                                    finger['betweenKeyRegressions']))
                self.assertFalse(finger['approved'])
        self.assertTrue(
            (output/'finger_bar_temporal_v927_report.json').is_file())

    def test_v927_rejects_approved_and_unmatched_provenance(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925')
        folder=root/'grip_v926'
        if not (folder/'ex_squat_v926_grip_optimized_mobile_qa.glb').exists():
            grip926.build(root,folder)
        old=(root/'ex_squat_v925_palm_web_topology_mobile_qa.glb'
             ).read_bytes()
        new=(folder/'ex_squat_v926_grip_optimized_mobile_qa.glb'
             ).read_bytes()
        with self.assertRaises(ValueError):
            temporal927.review(old,old,'ex_squat')
        with self.assertRaises(ValueError):
            temporal927.review(old,new,'no_exercise')
        forged=rig.GLB(new,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            temporal927.review(old,forged.bytes(),'ex_squat')



    def test_v928_gate_refuses_regression_or_no_measured_benefit(self):
        stat={
            'sampledFrames':241,'regressionFrames':[],
            'introducedDeep':0,'deepBefore':3,'deepAfter':3,
            'baselineMeanPositiveGapMeters':.02,
            'candidateMeanPositiveGapMeters':.019,
        }
        self.assertTrue(stabilize928.gate(stat,True)[0])
        self.assertFalse(stabilize928.gate(stat,False)[0])
        self.assertFalse(stabilize928.gate(
            dict(stat,regressionFrames=[22]),True)[0])
        self.assertFalse(stabilize928.gate(
            dict(stat,introducedDeep=1),True)[0])
        self.assertFalse(stabilize928.gate(
            dict(stat,candidateMeanPositiveGapMeters=.019999),True)[0])
        with self.assertRaises(ValueError):
            stabilize928.gate(dict(stat,sampledFrames=3),True)
        with self.assertRaises(ValueError):
            stabilize928.gate(dict(stat,baselineMeanPositiveGapMeters=float('nan')),True)

    def test_v928_actual_three_pilot_rollback_preserves_master55(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925')
        candidate=root/'grip_v926'
        if not (candidate/'ex_squat_v926_grip_optimized_mobile_qa.glb').exists():
            grip926.build(root,candidate)
        target=candidate/'stable_v928'
        report=stabilize928.build(root,candidate,target)
        self.assertEqual(report['pilotCount'],3)
        self.assertTrue(report['all241SamplesNoObservedRegression'])
        self.assertFalse(report['continuousCollisionCertified'])
        self.assertFalse(report['approved'])
        for pilot in report['pilots']:
            exercise=pilot['exerciseId']
            original=rig.GLB(
                (root/(exercise+'_v925_palm_web_topology_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            result=rig.GLB(
                (target/(exercise+'_v928_grip_stabilized_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            for field in ('nodes','skins','meshes','materials','animations'):
                self.assertEqual(original.doc[field],result.doc[field])
            self.assertEqual(result.doc['extras']['gripTemporalRollbackVersion'],928)
            self.assertFalse(result.doc['extras']['approved'])
            self.assertFalse(result.doc['extras']['enabled'])
            self.assertEqual(pilot['final60HzRegressionFrames'],0)
            self.assertEqual(pilot['finalIntroducedDeepFrames'],0)
            self.assertEqual(pilot['framesEvaluated'],241)
            self.assertEqual(pilot['keptTracks']+pilot['revertedTracks'],
                             pilot['initialChangedTracks'])
            self.assertEqual(len(pilot['perDigit']),10)
            self.assertEqual(result.doc['extras']['fingerCorrectedTracks'],
                             pilot['keptTracks'])
        self.assertTrue(
            (target/'grip_temporal_rollback_v928_report.json').is_file())

    def test_v928_refuses_approved_or_fake_exercise(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925')
        candidate=root/'grip_v926'
        if not (candidate/'ex_squat_v926_grip_optimized_mobile_qa.glb').exists():
            grip926.build(root,candidate)
        original=(root/'ex_squat_v925_palm_web_topology_mobile_qa.glb'
                  ).read_bytes()
        modified=(candidate/'ex_squat_v926_grip_optimized_mobile_qa.glb'
                  ).read_bytes()
        forged=rig.GLB(modified,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            stabilize928.stabilize(original,forged.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            stabilize928.stabilize(original,modified,'bogus')


    def test_v929_two_joint_safety_gate_rejects_bad_60hz_motion(self):
        stat={
            'frames':241,'regressionFrames':0,
            'introducedDeep':0,'deepBefore':5,'deepAfter':5,
            'gapBefore':.03,'gapAfter':.027,
        }
        self.assertTrue(twojoint929.gate(None,stat,True)[0])
        self.assertFalse(twojoint929.gate(None,stat,False)[0])
        self.assertFalse(twojoint929.gate(
            None,dict(stat,regressionFrames=2),True)[0])
        self.assertFalse(twojoint929.gate(
            None,dict(stat,introducedDeep=1),True)[0])
        self.assertFalse(twojoint929.gate(
            None,dict(stat,deepAfter=6),True)[0])
        self.assertFalse(twojoint929.gate(
            None,dict(stat,gapAfter=.029999),True)[0])
        with self.assertRaises(ValueError):
            twojoint929.gate(None,dict(stat,frames=121),True)
        with self.assertRaises(ValueError):
            twojoint929.gate(
                None,dict(stat,gapBefore=float('nan')),True)

    def test_v929_real_two_joint_solver_three_unapproved_mobile_pilots(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925')
        if not (root/'ex_squat_v925_palm_web_topology_mobile_qa.glb').exists():
            web925.build(root.parent,root)
        output=root/'two_joint_v929'
        summary=twojoint929.build(root,output)
        self.assertEqual(summary['pilotCount'],3)
        self.assertEqual(summary['maxJointTracksPerFinger'],2)
        self.assertEqual(summary['sampledFrames'],241)
        self.assertFalse(summary['approved'])
        self.assertFalse(summary['fullContactIKComplete'])
        for pilot in summary['pilots']:
            exercise=pilot['exerciseId']
            baseline=rig.GLB(
                (root/(exercise+'_v925_palm_web_topology_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            output_glb=rig.GLB(
                (output/(exercise+'_v929_two_joint_grip_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            for name in ('nodes','meshes','skins','materials','animations'):
                self.assertEqual(baseline.doc[name],output_glb.doc[name])
            self.assertFalse(output_glb.doc['extras']['approved'])
            self.assertFalse(output_glb.doc['extras']['enabled'])
            self.assertEqual(
                output_glb.doc['extras']['twoJointGripCandidateVersion'],929)
            self.assertEqual(pilot['sampledFrames'],241)
            self.assertEqual(len(pilot['jointSearch']),10)
            self.assertEqual(len(pilot['gateDecisions']),10)
            self.assertLessEqual(pilot['keptModifiedTracks'],20)
            self.assertEqual(pilot['keptModifiedTracks']%2,0)
            self.assertLess(pilot['outputBytes'],
                            twojoint929.MAX_MOBILE_BYTES+1)
            self.assertFalse(pilot['anatomicalIKComplete'])
            for item in pilot['jointSearch'].values():
                self.assertEqual(item['considered'],12)
                self.assertLessEqual(len(item['jointNames']),2)
                self.assertLessEqual(len(item['degrees']),2)
                self.assertTrue(all(
                    abs(d)<=twojoint929.MAX_JOINT_DEGREES
                    for d in item['degrees']))
            source_parts=baseline.doc['meshes'][0]['primitives']
            new_parts=output_glb.doc['meshes'][0]['primitives']
            for p1,p2 in zip(source_parts,new_parts):
                self.assertEqual(
                    baseline.accessor(p1['indices']),
                    output_glb.accessor(p2['indices']))
                for channel in ('POSITION','NORMAL','JOINTS_0','WEIGHTS_0'):
                    self.assertEqual(
                        baseline.accessor(p1['attributes'][channel]),
                        output_glb.accessor(p2['attributes'][channel]))
                for m1,m2 in zip(p1['targets'],p2['targets']):
                    self.assertEqual(
                        baseline.accessor(m1['POSITION']),
                        output_glb.accessor(m2['POSITION']))
            old=surface._samplers(baseline)
            new=surface._samplers(output_glb)
            self.assertEqual(old.keys(),new.keys())
            changed=[key for key in old if old[key]!=new[key]]
            self.assertEqual(len(changed),pilot['keptModifiedTracks'])
            self.assertTrue(all(
                key[1]=='rotation' and any(
                    key[0]==baseline.by_name[
                        f'{digit}_0{k}_{side}']
                    for side in ('l','r')
                    for digit in ('thumb','index','middle','ring','pinky')
                    for k in (1,2,3))
                for key in changed))
            self.assertTrue(all(
                old[key][0]==new[key][0] and old[key][-1]==new[key][-1]
                for key in changed))
        self.assertTrue((output/'two_joint_grip_v929_report.json').exists())

    def test_v929_refuses_approved_or_double_optimization(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925')
        if not (root/'ex_squat_v925_palm_web_topology_mobile_qa.glb').exists():
            web925.build(root.parent,root)
        source=(root/'ex_squat_v925_palm_web_topology_mobile_qa.glb'
                ).read_bytes()
        forged=rig.GLB(source,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            twojoint929.optimize(forged.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            twojoint929.optimize(source,'invalid_exercise')
        output,report=twojoint929.optimize(source,'ex_squat')
        self.assertFalse(report['approved'])
        with self.assertRaises(ValueError):
            twojoint929.optimize(output,'ex_squat')


    def test_v930_real_knuckle_mesh_sculpt_three_pilots(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925')
        joints=root/'two_joint_v929'
        if not (joints/'ex_squat_v929_two_joint_grip_mobile_qa.glb').exists():
            twojoint929.build(root,joints)
        dest=joints/'knuckle_v930'
        report=knuckle930.build(joints,dest)
        self.assertEqual(report['pilotCount'],3)
        self.assertFalse(report['approved'])
        self.assertFalse(report['fullIKComplete'])
        for item in report['pilots']:
            exercise=item['exerciseId']
            original=rig.GLB((joints/(
                exercise+'_v929_two_joint_grip_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            improved=rig.GLB((dest/(
                exercise+'_v930_knuckle_volume_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            for key in ('nodes','skins','animations','materials','meshes'):
                self.assertEqual(original.doc[key],improved.doc[key])
            self.assertEqual(improved.doc['extras']['fingerKnuckleVolumeVersion'],930)
            self.assertFalse(improved.doc['extras']['approved'])
            self.assertFalse(improved.doc['extras']['enabled'])
            self.assertGreater(item['verticesEdited'],9)
            self.assertGreaterEqual(item['knuckleGroupsWithEdits'],2)
            self.assertLessEqual(item['maxDisplacementMeters'],
                                 knuckle930.MAX_KNUCKLE_DELTA_METERS+.0000002)
            self.assertLessEqual(item['maxWorsenedSignedDistanceMeters'],
                                 knuckle930.MAX_CONTACT_DELTA_METERS)
            self.assertEqual(item['sampledContactFrames'],9)
            self.assertEqual(item['rigJoints'],55)
            self.assertEqual(item['morphTargets'],8)
            self.assertLessEqual(item['assetBytes'],knuckle930.MAX_MOBILE_BYTES)
            a=original.doc['meshes'][0]['primitives'][0]['attributes']
            b=improved.doc['meshes'][0]['primitives'][0]['attributes']
            self.assertEqual(a,b)
            self.assertEqual(
                len(original.accessor(a['POSITION'])),
                len(improved.accessor(b['POSITION'])))
            self.assertNotEqual(
                original.accessor(a['POSITION']),
                improved.accessor(b['POSITION']))
            self.assertNotEqual(
                original.accessor(a['NORMAL']),
                improved.accessor(b['NORMAL']))
            for key in ('JOINTS_0','WEIGHTS_0'):
                self.assertEqual(
                    original.accessor(a[key]),improved.accessor(b[key]))
            for before,after in zip(
                    original.doc['meshes'][0]['primitives'],
                    improved.doc['meshes'][0]['primitives']):
                self.assertEqual(
                    original.accessor(before['indices']),
                    improved.accessor(after['indices']))
                for ta,tb in zip(before['targets'],after['targets']):
                    self.assertEqual(
                        original.accessor(ta['POSITION']),
                        improved.accessor(tb['POSITION']))
        self.assertTrue((dest/'knuckle_surface_v930_report.json').is_file())

    def test_v930_refuses_approved_and_already_sculpted_glbs(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925')
        joints=root/'two_joint_v929'
        if not (joints/'ex_squat_v929_two_joint_grip_mobile_qa.glb').exists():
            twojoint929.build(root,joints)
        input_bytes=(joints/'ex_squat_v929_two_joint_grip_mobile_qa.glb'
                     ).read_bytes()
        forged=rig.GLB(input_bytes,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            knuckle930.sculpt(forged.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            knuckle930.sculpt(input_bytes,'invented_exercise')
        result,_=knuckle930.sculpt(input_bytes,'ex_squat')
        with self.assertRaises(ValueError):
            knuckle930.sculpt(result,'ex_squat')


    def test_v931_joint_skin_fold_bounded_profile_and_invalid_inputs(self):
        self.assertEqual(fold931.FRAME_COUNT,241)
        self.assertLessEqual(abs(fold931.fold_profile(0.,.009,.03)),
                             fold931.MAX_FOLD_METERS)
        self.assertNotEqual(fold931.fold_profile(0.,.009,.03),0.)
        with self.assertRaises(ValueError):
            fold931.fold_profile(0.,-1.,.03)
        with self.assertRaises(ValueError):
            fold931.fold_profile(float('inf'),.01,.03)

    def test_v931_real_three_pilot_fold_surface_and_60hz_contact(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929')
        knuckles=root/'knuckle_v930'
        if not (knuckles/'ex_squat_v930_knuckle_volume_mobile_qa.glb').exists():
            knuckle930.build(root,knuckles)
        folder=knuckles/'fold_v931'
        report=fold931.build(knuckles,folder)
        self.assertEqual(report['pilotCount'],3)
        self.assertEqual(report['framesAt60Hz'],241)
        self.assertFalse(report['approved'])
        self.assertFalse(report['triangleContinuousCollisionCertified'])
        self.assertEqual(report['acceptedFoldPilots']+
                         report['fallbackPilots'],3)
        for pilot in report['pilots']:
            eid=pilot['exerciseId']
            base=rig.GLB((knuckles/(
                eid+'_v930_knuckle_volume_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            model=rig.GLB((folder/(
                eid+'_v931_finger_fold_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            for field in ('skins','nodes','animations','meshes','materials'):
                self.assertEqual(base.doc[field],model.doc[field])
            self.assertEqual(model.doc['extras']['fingerFoldSculptVersion'],931)
            self.assertFalse(model.doc['extras']['enabled'])
            self.assertFalse(model.doc['extras']['approved'])
            self.assertEqual(pilot['skinJointCount'],55)
            self.assertEqual(pilot['morphTargets'],8)
            self.assertEqual(pilot['unchangedFingerTracks'],30)
            self.assertGreaterEqual(pilot['candidateFoldVertices'],12)
            self.assertGreaterEqual(
                sum(bool(v) for v in
                    pilot['bilateralCandidateGroups'].values()),2)
            self.assertLessEqual(
                pilot['actualMaxDeltaMeters'],
                fold931.MAX_FOLD_METERS+.0000001)
            self.assertLessEqual(pilot['outputBytes'],fold931.MAX_MOBILE_BYTES)
            aa=base.doc['meshes'][0]['primitives'][0]['attributes']
            ab=model.doc['meshes'][0]['primitives'][0]['attributes']
            for field in ('JOINTS_0','WEIGHTS_0'):
                self.assertEqual(base.accessor(aa[field]),
                                 model.accessor(ab[field]))
            for prior,new in zip(base.doc['meshes'][0]['primitives'],
                                 model.doc['meshes'][0]['primitives']):
                self.assertEqual(
                    base.accessor(prior['indices']),
                    model.accessor(new['indices']))
                for before,after in zip(prior['targets'],new['targets']):
                    self.assertEqual(
                        base.accessor(before['POSITION']),
                        model.accessor(after['POSITION']))
            observed=pilot['contactAudit60Hz']
            self.assertEqual(observed['samplesPerClip'],241)
            self.assertFalse(observed['continuousCollisionCertified'])
            if pilot['accepted']:
                self.assertGreater(pilot['editedFoldVertices'],9)
                self.assertNotEqual(base.accessor(aa['POSITION']),
                                    model.accessor(ab['POSITION']))
                self.assertTrue(observed['passesSampledContactGuards'])
            else:
                self.assertEqual(base.accessor(aa['POSITION']),
                                 model.accessor(ab['POSITION']))
                self.assertEqual(pilot['editedFoldVertices'],0)
        self.assertTrue((folder/'finger_fold_surface_v931_report.json').exists())

    def test_v931_rejects_approved_or_repeated_sculpt(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929')
        parent=root/'knuckle_v930'
        if not (parent/'ex_squat_v930_knuckle_volume_mobile_qa.glb').exists():
            knuckle930.build(root,parent)
        original=(parent/'ex_squat_v930_knuckle_volume_mobile_qa.glb'
                  ).read_bytes()
        forged=rig.GLB(original,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            fold931.sculpt(forged.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            fold931.sculpt(original,'invalid_exercise')
        candidate,_=fold931.sculpt(original,'ex_squat')
        with self.assertRaises(ValueError):
            fold931.sculpt(candidate,'ex_squat')


    def test_v932_limited_nail_bed_profile_and_invalid_coords(self):
        self.assertEqual(nail932.MAX_BED_RELIEF_METERS,.00030)
        self.assertGreater(nail932.nail_bed_profile(.004,0.,.007,.026),0.)
        self.assertEqual(nail932.nail_bed_profile(.5,0.,.007,.026),0.)
        self.assertEqual(nail932.nail_bed_profile(0.,.040,.007,.026),0.)
        with self.assertRaises(ValueError):
            nail932.nail_bed_profile(0.,.0,float('nan'),.02)
        with self.assertRaises(ValueError):
            nail932.nail_bed_profile(0.,0.,.005,0.)

    def test_v932_three_real_skinned_nail_bed_pilots_remain_disabled(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930')
        source=root/'fold_v931'
        if not (source/'ex_squat_v931_finger_fold_mobile_qa.glb').exists():
            fold931.build(root,source)
        destination=source/'nail_bed_v932'
        result=nail932.build(source,destination)
        self.assertEqual(result['pilotCount'],3)
        self.assertEqual(result['acceptedPilots']+result['fallbackPilots'],3)
        self.assertFalse(result['nailPlateMeshComplete'])
        self.assertFalse(result['approved'])
        for item in result['pilots']:
            eid=item['exerciseId']
            original=rig.GLB((source/(eid+'_v931_finger_fold_mobile_qa.glb'))
                             .read_bytes(),expected_sha=None)
            updated=rig.GLB((destination/(
                eid+'_v932_nail_bed_mobile_qa.glb')).read_bytes(),
                expected_sha=None)
            for field in ('skins','nodes','meshes','animations','materials'):
                self.assertEqual(original.doc[field],updated.doc[field])
            self.assertEqual(
                updated.doc['extras']['distalNailBedVersion'],932)
            self.assertFalse(updated.doc['extras']['nailPlateMeshComplete'])
            self.assertFalse(updated.doc['extras']['approved'])
            self.assertFalse(updated.doc['extras']['enabled'])
            self.assertEqual(item['jointCount'],55)
            self.assertEqual(item['morphCount'],8)
            self.assertEqual(item['fingerChannelsPreserved'],30)
            self.assertLessEqual(
                item['maxActualDisplacementMeters'],
                nail932.MAX_BED_RELIEF_METERS+.0000001)
            self.assertLessEqual(item['outputBytes'],nail932.MAX_MOBILE_BYTES)
            self.assertEqual(len(item['regionCandidates']),10)
            before=original.doc['meshes'][0]['primitives'][0]['attributes']
            after=updated.doc['meshes'][0]['primitives'][0]['attributes']
            self.assertEqual(
                original.accessor(before['JOINTS_0']),
                updated.accessor(after['JOINTS_0']))
            self.assertEqual(
                original.accessor(before['WEIGHTS_0']),
                updated.accessor(after['WEIGHTS_0']))
            for old_part,new_part in zip(
                    original.doc['meshes'][0]['primitives'],
                    updated.doc['meshes'][0]['primitives']):
                self.assertEqual(
                    original.accessor(old_part['indices']),
                    updated.accessor(new_part['indices']))
                for old_target,new_target in zip(
                        old_part['targets'],new_part['targets']):
                    self.assertEqual(
                        original.accessor(old_target['POSITION']),
                        updated.accessor(new_target['POSITION']))
            if item['candidateAccepted']:
                self.assertGreaterEqual(item['editedNailBedVertices'],8)
                self.assertNotEqual(
                    original.accessor(before['POSITION']),
                    updated.accessor(after['POSITION']))
                self.assertTrue(
                    item['sampledContactAudit']['passesSampledContactGuards'])
                self.assertEqual(
                    item['sampledContactAudit']['samplesPerClip'],241)
            else:
                self.assertEqual(item['editedNailBedVertices'],0)
                self.assertEqual(
                    original.accessor(before['POSITION']),
                    updated.accessor(after['POSITION']))
        self.assertTrue((destination/'nail_bed_v932_report.json').is_file())

    def test_v932_refuses_approved_or_double_nail_bed_sculpt(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930')
        source=root/'fold_v931'
        if not (source/'ex_squat_v931_finger_fold_mobile_qa.glb').exists():
            fold931.build(root,source)
        data=(source/'ex_squat_v931_finger_fold_mobile_qa.glb').read_bytes()
        glb=rig.GLB(data,expected_sha=None)
        glb.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            nail932.sculpt(glb.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            nail932.sculpt(data,'made_up_exercise')
        new,_=nail932.sculpt(data,'ex_squat')
        with self.assertRaises(ValueError):
            nail932.sculpt(new,'ex_squat')


    def test_v933_rejects_invalid_uv(self):
        with self.assertRaises(ValueError):
            nail933.append_uv(None,[])
        with self.assertRaises(ValueError):
            nail933.append_uv(None,[(float('nan'),.5)])
        with self.assertRaises(ValueError):
            nail933.append_uv(None,[(1.1,.5)])

    def test_v933_real_10_bone_attached_uv_nail_plates(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931')
        source=root/'nail_bed_v932'
        if not (source/'ex_squat_v932_nail_bed_mobile_qa.glb').exists():
            nail932.build(root,source)
        target=source/'nail_plates_v933'
        data=nail933.build(source,target)
        self.assertEqual(data['pilotCount'],3)
        self.assertFalse(data['approved'])
        for item in data['pilots']:
            exercise=item['exerciseId']
            a=rig.GLB((source/(exercise+'_v932_nail_bed_mobile_qa.glb'))
                      .read_bytes(),expected_sha=None)
            c=rig.GLB((target/(exercise+'_v933_rig_nail_plates_mobile_qa.glb'))
                      .read_bytes(),expected_sha=None)
            self.assertEqual(a.doc['skins'],c.doc['skins'])
            self.assertEqual(a.doc['animations'],c.doc['animations'])
            self.assertEqual(a.doc['meshes'],c.doc['meshes'][:len(a.doc['meshes'])])
            self.assertEqual(len(c.doc['meshes']),len(a.doc['meshes'])+10)
            self.assertEqual(len(c.doc['nodes']),len(a.doc['nodes'])+10)
            self.assertEqual(c.doc['extras']['nailPlatePrototypeVersion'],933)
            self.assertFalse(c.doc['extras']['approved'])
            self.assertFalse(c.doc['extras']['enabled'])
            self.assertTrue(item['phalanxAttachmentsVerified'])
            self.assertEqual(item['nailPlateNodes'],10)
            self.assertEqual(item['nailUVSets'],10)
            self.assertEqual(item['nailTriangles'],1360)
            for detail in item['plates']:
                child=c.doc['nodes'][detail['node']]
                parent=c.doc['nodes'][detail['bone']]
                self.assertIn(detail['node'],parent['children'])
                self.assertEqual(child['name'],
                                 'STK_NAIL_PLATE_'+detail['digit']+
                                 '_'+detail['side'])
                mesh=c.doc['meshes'][detail['mesh']]['primitives'][0]
                attr=mesh['attributes']
                self.assertEqual(len(c.accessor(attr['POSITION'])),70)
                self.assertEqual(len(c.accessor(attr['NORMAL'])),70)
                uv=c.accessor(attr['TEXCOORD_0'])
                self.assertEqual(len(uv),70)
                self.assertTrue(all(0<=x<=1 for row in uv for x in row))
                self.assertEqual(len(c.accessor(mesh['indices']))//3,136)
            self.assertLessEqual(item['bytes'],nail933.MAX_MOBILE_BYTES)
        self.assertTrue((target/'nail_plates_v933_report.json').is_file())

    def test_v933_rejects_approved_and_double_attachment(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931')
        source=root/'nail_bed_v932'
        if not (source/'ex_squat_v932_nail_bed_mobile_qa.glb').exists():
            nail932.build(root,source)
        raw=(source/'ex_squat_v932_nail_bed_mobile_qa.glb').read_bytes()
        approved=rig.GLB(raw,expected_sha=None)
        approved.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            nail933.build_one(approved.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            nail933.build_one(raw,'not_real')
        result,_=nail933.build_one(raw,'ex_squat')
        with self.assertRaises(ValueError):
            nail933.build_one(result,'ex_squat')


    def test_v934_real_triangle_closest_point_and_degeneracy(self):
        a=(0.,0.,0.)
        b=(1.,0.,0.)
        c=(0.,1.,0.)
        q=nailproximity934.closest_triangle((.25,.25,.002),a,b,c)
        self.assertAlmostEqual(q[0],.25,places=6)
        self.assertAlmostEqual(q[1],.25,places=6)
        self.assertAlmostEqual(q[2],0.,places=6)
        self.assertEqual(
            nailproximity934.closest_triangle((-.5,-.5,0.),a,b,c),a)
        self.assertEqual(
            nailproximity934.closest_triangle((.6,.6,0.),a,b,c),
            (.5,.5,0.))

    def test_v934_actual_ten_nails_against_skinned_triangles_60hz(self):
        source=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
                'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
                'two_joint_v929'/'knuckle_v930'/'fold_v931'/
                'nail_bed_v932')
        nails=source/'nail_plates_v933'
        if not (nails/'ex_squat_v933_rig_nail_plates_mobile_qa.glb').exists():
            nail933.build(source,nails)
        target=nails/'proximity_v934'
        report=nailproximity934.build(nails,target)
        self.assertEqual(report['pilotCount'],3)
        self.assertEqual(report['nailsAudited'],30)
        self.assertEqual(report['totalSurfaceProbeSamples'],3*241*10*9)
        self.assertTrue(report['noContinuousTriangleCCD'])
        self.assertFalse(report['approved'])
        for item in report['pilots']:
            self.assertEqual(item['pilotNailPlates'],10)
            self.assertEqual(item['sampledFrames'],241)
            self.assertEqual(item['sampleRateHz'],60)
            self.assertFalse(item['allSampledSurfacesPerfect'])
            self.assertFalse(item['continuousCollisionCertified'])
            self.assertTrue(item['reviewRequired'])
            self.assertEqual(item['nailSurfaceSamples'],241*90)
            self.assertEqual(len(item['digits']),10)
            for digit in item['digits'].values():
                self.assertEqual(digit['sampledPoses'],241)
                self.assertEqual(
                    digit['closestDistancesEvaluated'],241*9)
                self.assertGreaterEqual(
                    digit['selectedSkinnedTriangles'],3)
                self.assertLessEqual(
                    digit['selectedSkinnedTriangles'],
                    nailproximity934.MAX_FACES_PER_FINGER)
                self.assertTrue(math.isfinite(
                    digit['minimumUnsignedDistanceMeters']))
                self.assertLessEqual(
                    digit['minimumUnsignedDistanceMeters'],
                    digit['largestObservedSeparationMeters'])
                self.assertGreaterEqual(
                    digit['possibleEmbeddedVertexSamples'],0)
                self.assertGreaterEqual(
                    digit['possiblyDetachedVertexSamples'],0)
        self.assertTrue(
            (target/'nail_plate_skin_proximity_v934_report.json').exists())

    def test_v934_rejects_wrong_provenance(self):
        source=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
                'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
                'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
                'two_joint_v929'/'knuckle_v930'/'fold_v931'/
                'nail_bed_v932')
        nails=source/'nail_plates_v933'
        if not (nails/'ex_squat_v933_rig_nail_plates_mobile_qa.glb').exists():
            nail933.build(source,nails)
        raw=(nails/'ex_squat_v933_rig_nail_plates_mobile_qa.glb'
             ).read_bytes()
        forged=rig.GLB(raw,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            nailproximity934.review(forged.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            nailproximity934.review(raw,'not_an_exercise')


    def test_v935_contact_guard_fails_closed(self):
        base={
            'possibleEmbeddedVertexSamples':3,
            'possiblyDetachedVertexSamples':8,
            'largestObservedSeparationMeters':.010,
        }
        self.assertTrue(nailoffset935.risk_gate(base,dict(
            base,possibleEmbeddedVertexSamples=2))[0])
        self.assertFalse(nailoffset935.risk_gate(base,base)[0])
        self.assertFalse(nailoffset935.risk_gate(base,dict(
            base,possiblyDetachedVertexSamples=9))[0])
        self.assertFalse(nailoffset935.risk_gate(base,dict(
            base,possibleEmbeddedVertexSamples=4))[0])
        self.assertFalse(nailoffset935.risk_gate(base,dict(
            base,possibleEmbeddedVertexSamples=2,
            largestObservedSeparationMeters=.011))[0])
        with self.assertRaises(ValueError):
            nailoffset935.risk_gate(base,dict(base,
                 largestObservedSeparationMeters=float('nan')))

    def test_v935_actual_nail_offset_search_three_mobile_pilots(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931'/
              'nail_bed_v932')
        nails=root/'nail_plates_v933'
        if not (nails/'ex_squat_v933_rig_nail_plates_mobile_qa.glb').exists():
            nail933.build(root,nails)
        target=nails/'offset_v935'
        report=nailoffset935.build(nails,target)
        self.assertEqual(report['pilotCount'],3)
        self.assertFalse(report['approved'])
        self.assertEqual(report['verifiedFramesPerClip'],241)
        for item in report['pilots']:
            ex=item['exerciseId']
            before=rig.GLB((nails/(ex+
               '_v933_rig_nail_plates_mobile_qa.glb')).read_bytes(),
               expected_sha=None)
            after=rig.GLB((target/(ex+
               '_v935_nail_contact_offset_mobile_qa.glb')).read_bytes(),
               expected_sha=None)
            for key in ('nodes','skins','meshes','animations','materials'):
                self.assertEqual(before.doc[key],after.doc[key])
            self.assertEqual(
                after.doc['extras']['nailContactOffsetOptimizerVersion'],935)
            self.assertEqual(item['nailPlatesReviewed'],10)
            self.assertEqual(item['fullGateFrames'],241)
            self.assertEqual(item['searchFrames'],9)
            self.assertLessEqual(item['offsetsKept'],10)
            self.assertLessEqual(item['assetBytes'],
                                 nailoffset935.MAX_MOBILE_BYTES)
            self.assertFalse(after.doc['extras']['approved'])
            self.assertFalse(after.doc['extras']['enabled'])
            for name,offset in item['selectedMeters'].items():
                self.assertIn(name,item['candidateSearch'])
                self.assertLessEqual(abs(offset),.0005)
                before_skin=item['before60Hz'][name]
                after_skin=item['after60Hz'][name]
                self.assertLessEqual(after_skin['embedded'],
                                     before_skin['embedded'])
                self.assertLessEqual(after_skin['detached'],
                                     before_skin['detached'])
            self.assertEqual(item['offsetsKept'],
                             len(item['selectedMeters']))
        self.assertTrue((target/'nail_offsets_v935_report.json').is_file())

    def test_v935_rejects_approved_reprocessing(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931'/
              'nail_bed_v932'/'nail_plates_v933')
        if not (root/'ex_squat_v933_rig_nail_plates_mobile_qa.glb').exists():
            nail933.build(root.parent,root)
        raw=(root/'ex_squat_v933_rig_nail_plates_mobile_qa.glb').read_bytes()
        forged=rig.GLB(raw,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            nailoffset935.optimize(forged.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            nailoffset935.optimize(raw,'wrong_exercise')
        # The optimizer cannot authorize QA output as a subsequent input.
        candidate=(root/'offset_v935'/
                   'ex_squat_v935_nail_contact_offset_mobile_qa.glb')
        if candidate.exists():
            with self.assertRaises(ValueError):
                nailoffset935.optimize(candidate.read_bytes(),'ex_squat')


    def test_v936_nail_medium_lod_grid_is_closed_and_reduced(self):
        ids=naillod936._lod_indices()
        self.assertEqual(len(ids)//3,56)
        self.assertEqual(set(ids),set(range(30)))
        self.assertEqual(len(naillod936._subsample([(float(i),0.,0.) for i in range(70)])),30)
        with self.assertRaises(ValueError):
            naillod936._subsample([(float(i),0.,0.) for i in range(69)])

    def test_v936_real_three_animated_pilot_nail_lods(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931'/
              'nail_bed_v932'/'nail_plates_v933')
        source=root/'offset_v935'
        if not (source/'ex_squat_v935_nail_contact_offset_mobile_qa.glb').exists():
            nailoffset935.build(root,source)
        output=source/'lod_v936'
        result=naillod936.build(source,output)
        self.assertEqual(result['pilotCount'],3)
        self.assertEqual(result['nailTrianglesBeforePerPilot'],1360)
        self.assertEqual(result['nailTrianglesAfterPerPilot'],560)
        self.assertFalse(result['approved'])
        for row in result['pilots']:
            exercise=row['exerciseId']
            original=rig.GLB((source/(exercise+
                '_v935_nail_contact_offset_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            revised=rig.GLB((output/(exercise+
                '_v936_nail_lod_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            self.assertEqual(original.doc['skins'],revised.doc['skins'])
            self.assertEqual(original.doc['nodes'],revised.doc['nodes'])
            self.assertEqual(original.doc['animations'],
                             revised.doc['animations'])
            self.assertEqual(original.doc['meshes'][0],
                             revised.doc['meshes'][0])
            self.assertEqual(revised.doc['extras']['nailLodPrototypeVersion'],936)
            self.assertFalse(revised.doc['extras']['approved'])
            self.assertFalse(revised.doc['extras']['enabled'])
            self.assertFalse(row['sampledContactRetestCompleted'])
            self.assertFalse(row['newGpuBenchmarkCompleted'])
            self.assertEqual(row['reducedNailMeshCount'],10)
            self.assertEqual(row['originalNailTriangles'],1360)
            self.assertEqual(row['lodNailTriangles'],560)
            self.assertGreater(row['nailTriangleReductionPercent'],58)
            self.assertLessEqual(
                row['maximumSourceVertexErrorMeters'],
                naillod936.MAX_VERTEX_TO_SURFACE_ERROR_METERS)
            self.assertLessEqual(row['assetBytes'],naillod936.MAX_MOBILE_BYTES)
            self.assertEqual(row['materialExperimentRoughness'],.46)
            for entry in row['plates']:
                part=revised.doc['meshes'][entry['meshIndex']]['primitives'][0]
                attr=part['attributes']
                self.assertEqual(len(revised.accessor(attr['POSITION'])),30)
                self.assertEqual(len(revised.accessor(attr['NORMAL'])),30)
                uv=revised.accessor(attr['TEXCOORD_0'])
                self.assertEqual(len(uv),30)
                self.assertTrue(all(0<=x<=1 for u in uv for x in u))
                self.assertEqual(len(revised.accessor(part['indices']))//3,56)
                self.assertLessEqual(
                    entry['maxOriginalVertexToLodSurfaceMeters'],
                    naillod936.MAX_VERTEX_TO_SURFACE_ERROR_METERS)
        self.assertTrue((output/'nail_lod_v936_report.json').exists())

    def test_v936_rejects_approved_or_repeated_lod_derivation(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931'/
              'nail_bed_v932'/'nail_plates_v933')
        source=root/'offset_v935'
        if not (source/'ex_squat_v935_nail_contact_offset_mobile_qa.glb').exists():
            nailoffset935.build(root,source)
        raw=(source/'ex_squat_v935_nail_contact_offset_mobile_qa.glb'
             ).read_bytes()
        bad=rig.GLB(raw,expected_sha=None)
        bad.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            naillod936.reduce_one(bad.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            naillod936.reduce_one(raw,'invented_exercise')
        candidate,_=naillod936.reduce_one(raw,'ex_squat')
        with self.assertRaises(ValueError):
            naillod936.reduce_one(candidate,'ex_squat')


    def test_v937_rejects_worsening_thumb_contact_metrics(self):
        base={'embedded':2,'detached':100,'maxDistance':.015}
        self.assertTrue(thumb937.gate(
            base,dict(base,detached=90))[0])
        self.assertFalse(thumb937.gate(base,base)[0])
        self.assertFalse(thumb937.gate(
            base,dict(base,embedded=3,detached=90))[0])
        self.assertFalse(thumb937.gate(
            base,dict(base,detached=90,maxDistance=.016))[0])
        with self.assertRaises(ValueError):
            thumb937.gate(
                base,dict(base,maxDistance=float('nan')))

    def test_v937_retargets_actual_thumb_nail_nodes_with_full_60hz_guards(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931'/
              'nail_bed_v932'/'nail_plates_v933'/
              'offset_v935')
        source=root/'lod_v936'
        if not (source/'ex_squat_v936_nail_lod_mobile_qa.glb').exists():
            naillod936.build(root,source)
        folder=source/'thumb_fit_v937'
        report=thumb937.build(source,folder)
        self.assertEqual(report['pilotCount'],3)
        self.assertEqual(report['thumbsReviewed'],6)
        self.assertEqual(report['thumbsAdjusted']+
                         report['thumbsUnresolved'],6)
        self.assertFalse(report['approved'])
        for rec in report['pilots']:
            eid=rec['exerciseId']
            prior=rig.GLB((source/(
                eid+'_v936_nail_lod_mobile_qa.glb')).read_bytes(),
                expected_sha=None)
            current=rig.GLB((folder/(
                eid+'_v937_thumb_nail_fit_mobile_qa.glb')).read_bytes(),
                expected_sha=None)
            for key in ('meshes','skins','materials','animations'):
                self.assertEqual(prior.doc[key],current.doc[key])
            self.assertEqual(current.doc['extras']['thumbNail3dFitVersion'],937)
            self.assertFalse(current.doc['extras']['approved'])
            self.assertFalse(current.doc['extras']['enabled'])
            self.assertEqual(rec['sampledFullFrames'],241)
            self.assertEqual(rec['sampledRateHz'],60)
            self.assertEqual(len(rec['thumbRecords']),2)
            self.assertEqual(rec['thumbsReviewed'],2)
            self.assertEqual(rec['unchangedRigJoints'],55)
            self.assertEqual(rec['unchangedMorphTargets'],8)
            self.assertLessEqual(rec['outputBytes'],thumb937.MAX_MOBILE_BYTES)
            changed={current.by_name['STK_NAIL_PLATE_'+k]
                     for k in rec['acceptedOffsetsMeters']}
            for index,old in enumerate(prior.doc['nodes']):
                now=current.doc['nodes'][index]
                if index in changed:
                    revised=dict(now)
                    revised['translation']=old['translation']
                    self.assertEqual(revised,old)
                else:
                    self.assertEqual(now,old)
            for name,detail in rec['thumbRecords'].items():
                self.assertEqual(detail['baseline']['frames'],241)
                if detail['accepted']:
                    self.assertTrue(thumb937.gate(
                        detail['baseline'],detail['candidate'])[0])
                    self.assertLessEqual(
                        math.dist((0,0,0),rec['acceptedOffsetsMeters'][name]),
                        thumb937.MAX_MOVE+.0000001)
                else:
                    self.assertNotIn(name,rec['acceptedOffsetsMeters'])
        self.assertTrue((folder/'thumb_nail_fit_v937_report.json').is_file())

    def test_v937_refuses_approved_models_and_reprocessing(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931'/
              'nail_bed_v932'/'nail_plates_v933'/'offset_v935')
        src=root/'lod_v936'
        if not (src/'ex_squat_v936_nail_lod_mobile_qa.glb').exists():
            naillod936.build(root,src)
        raw=(src/'ex_squat_v936_nail_lod_mobile_qa.glb').read_bytes()
        fake=rig.GLB(raw,expected_sha=None)
        fake.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            thumb937.fit(fake.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            thumb937.fit(raw,'fake_exercise')
        after=src/'thumb_fit_v937'/'ex_squat_v937_thumb_nail_fit_mobile_qa.glb'
        if after.exists():
            with self.assertRaises(ValueError):
                thumb937.fit(after.read_bytes(),'ex_squat')


    def test_v938_strict_left_nail_axis_and_contact_gate(self):
        self.assertAlmostEqual(left938.qaxis((1,0,0),0)[3],1.)
        with self.assertRaises(ValueError):
            left938.qaxis((0,0,0),2)
        with self.assertRaises(ValueError):
            left938.qaxis((1,0,0),25)
        with self.assertRaises(ValueError):
            left938.qaxis((1,0,0),float('nan'))
        prev={'embedded':2,'detached':100,'maxDistance':.014}
        self.assertTrue(left938.gate(
            prev,dict(prev,detached=99))[0])
        self.assertFalse(left938.gate(
            prev,dict(prev,embedded=3,detached=99))[0])

    def test_v938_real_left_thumbnail_pose_fit_preserves_right(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931'/
              'nail_bed_v932'/'nail_plates_v933'/'offset_v935')
        lod=root/'lod_v936'
        if not (lod/'ex_squat_v936_nail_lod_mobile_qa.glb').exists():
            naillod936.build(root,lod)
        thumb=lod/'thumb_fit_v937'
        if not (thumb/'ex_squat_v937_thumb_nail_fit_mobile_qa.glb').exists():
            thumb937.build(lod,thumb)
        out=thumb/'left_thumb_angle_v938'
        report=left938.build(thumb,lod,out)
        self.assertEqual(report['pilotCount'],3)
        self.assertEqual(report['leftThumbsReviewed'],3)
        self.assertFalse(report['approved'])
        for row in report['pilots']:
            eid=row['exerciseId']
            a=rig.GLB((thumb/(
                eid+'_v937_thumb_nail_fit_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            b=rig.GLB((out/(
                eid+'_v938_left_thumb_angle_mobile_qa.glb'))
                .read_bytes(),expected_sha=None)
            for k in ('skins','meshes','materials','animations'):
                self.assertEqual(a.doc[k],b.doc[k])
            self.assertFalse(b.doc['extras']['approved'])
            self.assertFalse(b.doc['extras']['enabled'])
            self.assertEqual(b.doc['extras'][
                'leftThumbPlateContourFitVersion'],938)
            self.assertEqual(row['fullSampledFrames'],241)
            self.assertEqual(row['coarseSampledFrames'],9)
            self.assertLessEqual(row['fullCandidatesChecked'],
                                 left938.MAX_FULL_REVIEWS)
            self.assertTrue(row['rightThumbV937Preserved'])
            changed=a.by_name['STK_NAIL_PLATE_thumb_l']
            for index,old in enumerate(a.doc['nodes']):
                new=dict(b.doc['nodes'][index])
                if index==changed:
                    new['rotation']=old['rotation']
                    new['translation']=old['translation']
                self.assertEqual(new,old)
            if row['leftThumbAdjusted']:
                self.assertTrue(left938.gate(
                    row['baseline'],row['final'])[0])
                self.assertLessEqual(abs(row['leftThumbTiltDegrees']),18)
                self.assertLessEqual(math.dist((0,0,0),
                     row['leftThumbTranslationMeters']),.0120001)
            else:
                self.assertEqual(row['baseline'],row['final'])
            self.assertLessEqual(row['outputBytes'],
                                 left938.MAX_MOBILE_BYTES)
        self.assertTrue((out/'left_thumb_angle_v938_report.json').is_file())

    def test_v938_rejects_approved_and_second_processing(self):
        root=(self.MASTER/'v8_authoring'/'detail_bake_v915'/
              'torso_v916'/'hand_v917'/'contact_v918'/'skin_v919'/
              'hand_v920'/'topology_v922'/'palm_v924'/'web_v925'/
              'two_joint_v929'/'knuckle_v930'/'fold_v931'/
              'nail_bed_v932'/'nail_plates_v933'/'offset_v935')
        lod=root/'lod_v936'
        if not (lod/'ex_squat_v936_nail_lod_mobile_qa.glb').exists():
            naillod936.build(root,lod)
        thumb=lod/'thumb_fit_v937'
        if not (thumb/'ex_squat_v937_thumb_nail_fit_mobile_qa.glb').exists():
            thumb937.build(lod,thumb)
        raw=(thumb/'ex_squat_v937_thumb_nail_fit_mobile_qa.glb'
             ).read_bytes()
        neutral=(lod/'ex_squat_v936_nail_lod_mobile_qa.glb').read_bytes()
        fake=rig.GLB(raw,expected_sha=None)
        fake.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            left938.fit(fake.bytes(),neutral,'ex_squat')
        with self.assertRaises(ValueError):
            left938.fit(raw,neutral,'invented_exercise')
        out=thumb/'left_thumb_angle_v938'/'ex_squat_v938_left_thumb_angle_mobile_qa.glb'
        if out.exists():
            with self.assertRaises(ValueError):
                left938.fit(out.read_bytes(),neutral,'ex_squat')

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
