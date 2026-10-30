#!/usr/bin/env python3
"""Dense geometry/contact audit for existing CC0 53-joint mobile GLB pilots.

Only independent offline QC. This does NOT validate anatomical form, biomechanics,
joint torque, skin collision, shoe-floor force, or professional coaching quality.
"""
import math

import retarget_cc0_glb as rig

FPS=30
FRAME_COUNT=121
GRIP_MAX_METERS=.005
FOOT_MAX_METERS=.005
SEAM_MAX_METERS=.00001
MAX_MARKER_SPEED_M_PER_S=8.0
REQUIRED_MARKERS=(
    'pelvis','hand_l','hand_r','foot_l','foot_r',
    'calf_l','calf_r','upperarm_l','upperarm_r',
    'STK_EXERCISE_BAR',
)

def check_source(glb,exercise):
    if exercise not in rig.EXERCISES:
        raise ValueError('Unknown pilot exercise ID')
    metadata=glb.doc.get('extras',{})
    if (metadata.get('exerciseId')!=exercise or
        metadata.get('sourceSha256')!=rig.SOURCE_SHA or
        metadata.get('approved') is not False or
        metadata.get('enabled') is not False or
        len(glb.doc['skins'][0]['joints'])!=53 or
        len(glb.doc['animations'])!=1):
        raise ValueError('Unsafe or non-review CC0 pilot GLB')
    if not all(marker in glb.by_name for marker in REQUIRED_MARKERS):
        raise ValueError('Required skeletal or bar marker missing')
    mesh_names={m.get('name'):m for m in glb.doc['meshes']}
    if 'STK_BAR_AND_PLATES' not in mesh_names:
        raise ValueError('Equipment mesh missing')
    equipment=mesh_names['STK_BAR_AND_PLATES']
    positions=glb.accessor(
        equipment['primitives'][0]['attributes']['POSITION'])
    if len(positions)<350 or not all(all(math.isfinite(x) for x in p)
                                      for p in positions):
        raise ValueError('Detailed QA bar proxy is missing or corrupt')
    # The lightweight 3D bar is aligned along X; collars and grip guides
    # should be visible from near side-view with only one equipment material.
    ranges=[(-1.1,.02),(-.835,.044),(-.50,.022),
            (.50,.022),(.835,.044),(1.1,.02)]
    for x,radius in ranges:
        if not any(abs(p[0]-x)<.028 and
                   abs(math.hypot(p[1],p[2])-radius)<.008
                   for p in positions):
            raise ValueError('Bar shaft/collar/grip guide geometry missing')
    bench_present='STK_BENCH_STATIONARY' in glb.by_name
    if bench_present!=(exercise=='ex_bench_press'):
        raise ValueError('Unexpected bench/equipment pilot mismatch')
    if bench_present:
        node=glb.nodes[glb.by_name['STK_BENCH_STATIONARY']]
        bench_mesh=glb.doc['meshes'][node['mesh']]
        vertices=glb.accessor(
            bench_mesh['primitives'][0]['attributes']['POSITION'])
        if not vertices or not any(abs(p[1]-.622)<.001 for p in vertices):
            raise ValueError('Flat bench surface not present at fixed height')
    return bench_present

def review(glb,exercise,tracks,world_sample):
    bench=check_source(glb,exercise)
    if not callable(world_sample):
        raise ValueError('No real GLB channel sampler')
    animated={(node,path) for node,path,*_ in tracks}
    bar_index=glb.by_name['STK_EXERCISE_BAR']
    if (bar_index,'translation') not in animated:
        raise ValueError('Bar must follow an explicit world translation track')
    if bench and any(node==glb.by_name['STK_BENCH_STATIONARY']
                     for node,path,*_ in tracks):
        raise ValueError('Bench must not move during exercise')
    nodes={name:glb.by_name[name] for name in REQUIRED_MARKERS}
    start=world_sample(glb,0.,tracks)
    finish=world_sample(glb,4.,tracks)
    max_grip=0.
    max_foot=0.
    max_speed=0.
    max_hand_error_asymmetry=0.
    min_knee_above_foot=math.inf
    max_knee_lateral_offset=0.
    min_bar_pelvis_distance=math.inf
    min_pelvis_above_bench=math.inf
    max_bar_travel=0.
    prior=None
    for k in range(FRAME_COUNT):
        sample=world_sample(glb,k/FPS,tracks)
        values=[sample[nodes[name]] for name in REQUIRED_MARKERS]
        if not all(math.isfinite(x) for marker in values for x in marker):
            raise ValueError('Non-finite interpolated joint transform')
        bar=sample[bar_index]
        current_errors=[]
        for side,sign in (('l',1),('r',-1)):
            grip=(bar[0]+sign*(.51 if exercise=='ex_squat' else .50),
                  bar[1],bar[2])
            err=math.dist(sample[nodes['hand_'+side]],grip)
            current_errors.append(err)
            max_grip=max(max_grip,err)
            foot=sample[nodes['foot_'+side]]
            max_foot=max(max_foot,math.dist(foot,start[nodes['foot_'+side]]))
            knee=sample[nodes['calf_'+side]]
            min_knee_above_foot=min(min_knee_above_foot,knee[1]-foot[1])
            max_knee_lateral_offset=max(
                max_knee_lateral_offset,abs(knee[0]-foot[0]))
        max_hand_error_asymmetry=max(max_hand_error_asymmetry,
                                      abs(current_errors[0]-current_errors[1]))
        max_bar_travel=max(max_bar_travel,math.dist(bar,start[bar_index]))
        min_bar_pelvis_distance=min(
            min_bar_pelvis_distance,math.dist(bar,sample[nodes['pelvis']]))
        if bench:
            min_pelvis_above_bench=min(
                min_pelvis_above_bench,sample[nodes['pelvis']][1]-.622)
        if prior is not None:
            for name in REQUIRED_MARKERS:
                speed=FPS*math.dist(
                    sample[nodes[name]],prior[nodes[name]])
                max_speed=max(max_speed,speed)
        prior=sample
    seam=max(math.dist(start[nodes[x]],finish[nodes[x]])
             for x in REQUIRED_MARKERS)
    if (max_grip>=GRIP_MAX_METERS or max_foot>=FOOT_MAX_METERS or
        seam>=SEAM_MAX_METERS or max_speed>=MAX_MARKER_SPEED_M_PER_S or
        max_bar_travel<=.10):
        raise ValueError('Contact/interpolation gate failed for '+exercise)
    return {
        'exerciseId':exercise,'sampledFrames':FRAME_COUNT,
        'sampledFps':FPS,'equipmentDetailedCappedBarProxy':True,
        'benchNodeRequiredAndStatic':bench,
        'sourceRigJoints':53,
        'maxWristBarErrorMeters':round(max_grip,7),
        'maxFootDriftMeters':round(max_foot,7),
        'loopSeamMeters':round(seam,7),
        'maxJointSpeedMetersPerSecond':round(max_speed,5),
        'barCenterTravelMeters':round(max_bar_travel,5),
        'handGripErrorAsymmetryMeters':round(max_hand_error_asymmetry,7),
        'minimumKneeAboveFootJointMeters':round(min_knee_above_foot,5),
        'maximumKneeLateralJointOffsetMeters':round(max_knee_lateral_offset,5),
        'minimumBarToPelvisJointMeters':round(min_bar_pelvis_distance,5),
        'minimumPelvisJointAboveBenchTopMeters':
            round(min_pelvis_above_bench,5) if bench else None,
        'geometryGatePassed':True,
        'skinAndMuscleQualityReviewed':False,
        'trueSurfaceCollisionTested':False,
        'expertBiomechanicsReviewed':False,
        'nativeIphoneAndroidVerified':False,
        'approved':False,'enabled':False,
        'manualBlockers':[
            'Visible finger-bar and shoe-floor surface collisions not evaluated',
            'True joint angles, axis conventions and load mechanics not certified',
            'Bench shoulder/scapula, hip and head support not certified',
            'No anatomist/coach or real device geometry sign-off',
        ],
    }
