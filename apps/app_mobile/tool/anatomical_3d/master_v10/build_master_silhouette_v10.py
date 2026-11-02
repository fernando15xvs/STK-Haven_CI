#!/usr/bin/env python3
"""STK Haven v10 BLOCK 1 — completely NEW static anatomical master A-pose.

Not derived from v9 model. This offline authoring stage produces a neutral,
athletic, watertight silhouette with anatomical mass landmarks and real GLB.
It is deliberately NOT rigged, animated, approved or integrated into Flutter.

Offline authoring dependencies: numpy, scipy, scikit-image, trimesh.
Run: python build_master_silhouette_v10.py --output /path/to/review
The emitted glb/PNG are review evidence, never production exercise media.
"""
from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path

import numpy as np
from scipy.ndimage import gaussian_filter
from skimage.measure import marching_cubes
import trimesh


@dataclass(frozen=True)
class AnatomyVolume:
    region: str
    center_x: float
    center_y: float
    center_z: float
    radius_x: float
    radius_y: float
    radius_z: float
    rotation_xy: float = 0.0
    blend: float = 0.022

    def __post_init__(self):
        if not all(np.isfinite(v) for v in asdict(self).values() if isinstance(v, float)):
            raise ValueError(f'Nonfinite anatomy region {self.region}')
        if min(self.radius_x, self.radius_y, self.radius_z) <= 0:
            raise ValueError('A region must have positive dimensions')
        if not 0 <= self.blend < .065:
            raise ValueError('Unbounded soft tissue blend')


def master_landmarks() -> dict[str, tuple[float, float, float]]:
    """Meters, +Y up, +Z forward; neutral relaxed bilateral A pose."""
    return {
        'pelvis': (0., .98, 0.), 'sternum': (0., 1.39, .11),
        'neck': (0., 1.60, 0.), 'head': (0., 1.73, .018),
        'left_shoulder': (-.365, 1.48, 0.),
        'right_shoulder': (.365, 1.48, 0.),
        'left_elbow': (-.59, 1.17, 0.),
        'right_elbow': (.59, 1.17, 0.),
        'left_wrist': (-.805, .905, .012),
        'right_wrist': (.805, .905, .012),
        'left_hip': (-.165, .92, 0.),
        'right_hip': (.165, .92, 0.),
        'left_knee': (-.165, .48, .018),
        'right_knee': (.165, .48, .018),
        'left_ankle': (-.165, .105, 0.),
        'right_ankle': (.165, .105, 0.),
    }


def volumes() -> list[AnatomyVolume]:
    v: list[AnatomyVolume] = []

    def add(name, cx, cy, cz, rx, ry, rz, angle=0, blend=.022):
        v.append(AnatomyVolume(name, cx, cy, cz, rx, ry, rz, angle, blend))

    # Skeletal body proportions are rebuilt, not patched from v9.
    add('core_ribcage', 0, 1.370, -.002, .287, .295, .165, blend=.035)
    add('core_waist', 0, 1.143, .003, .191, .190, .134, blend=.040)
    add('core_pelvis', 0, .961, -.007, .205, .160, .147, blend=.039)
    add('neck', 0, 1.596, -.006, .083, .106, .080)
    add('head_cranium', 0, 1.747, -.001, .110, .141, .108, blend=.012)
    add('head_jaw', 0, 1.680, .031, .096, .085, .099, blend=.014)
    add('head_nose', 0, 1.704, .106, .012, .023, .014, blend=.011)
    add('head_chin', 0, 1.634, .061, .048, .028, .043, blend=.015)
    for s, side in (('left', -1), ('right', 1)):
        def bilateral(name, cx, cy, cz, rx, ry, rz, angle=0, blend=.022):
            add(s + '_' + name, side*cx, cy, cz, rx, ry, rz,
                side*angle, blend)
        # Pectoral heads create a high, projecting chest (not painted zones).
        bilateral('pectoral_major', .140, 1.431, .121, .151, .105, .079, -.06, .027)
        bilateral('pectoralis_clavicular', .163, 1.492, .107,
                  .108, .064, .057, .22, .020)
        # Shoulder caps and rear shoulder actually widen the silhouette.
        bilateral('deltoid_lateral', .355, 1.465, .008, .105, .105, .103, -.14, .024)
        bilateral('deltoid_anterior', .340, 1.435, .059,
                  .079, .100, .074, -.16, .022)
        bilateral('deltoid_posterior', .342, 1.443, -.081,
                  .076, .096, .068, -.12, .021)
        bilateral('upper_trapezius', .181, 1.547, -.065,
                  .193, .080, .091, -.35, .027)
        bilateral('latissimus_dorsi', .212, 1.328, -.090,
                  .101, .173, .092, -.11, .030)
        bilateral('rhomboid', .139, 1.443, -.140, .102, .104, .052, -.11, .009)
        bilateral('serratus_anterior', .225, 1.326, .085,
                  .063, .111, .065, -.09, .024)
        bilateral('external_oblique', .162, 1.175, .076,
                  .069, .139, .061, -.15, .027)
        # Six distinct shallow belly forms; separation comes from geometry.
        for index,y in enumerate((1.258,1.182,1.103)):
            bilateral('rectus_abdominis_'+str(index+1), .065, y, .126,
                      .050, .038, .035, 0, .020)
        # Arm along outward/downward axis, not cylindrical vertical tubes.
        bilateral('upper_arm', .478, 1.302, -.005,
                  .083, .197, .078, .56, .027)
        bilateral('biceps_brachii', .474, 1.316, .049,
                  .057, .132, .055, .56, .027)
        bilateral('triceps', .482, 1.319, -.064,
                  .060, .141, .060, .55, .024)
        bilateral('elbow', .595, 1.170, -.003, .063, .074, .061)
        bilateral('forearm', .694, 1.059, .013,
                  .071, .160, .068, .60, .025)
        bilateral('brachioradialis', .671, 1.089, .060,
                  .048, .113, .041, .60, .023)
        bilateral('wrist', .804, .915, .016, .040, .056, .044)
        bilateral('palm', .837, .849, .027,
                  .065, .084, .034, .25, .013)
        bilateral('thumb', .786, .825, .078, .026, .060, .028, -.32, .010)
        for finger,offset in enumerate((-.032,-.011,.011,.032)):
            # Silhouette guide only; detailed hands belong to block 3.
            bilateral('finger_'+str(finger), .847+offset, .772, .025,
                      .012, .056-(finger==3)*.013, .013, .0, .006)
        bilateral('gluteus_maximus', .128, .944, -.099,
                  .142, .149, .130, .10, .020)
        bilateral('gluteus_medius', .170, 1.012, -.056,
                  .112, .107, .092, .12, .020)
        # Independently contoured quads, medial adductor and rear hamstrings.
        bilateral('thigh', .168, .691, -.006,
                  .120, .297, .119, -.025, .028)
        bilateral('rectus_femoris', .171, .694, .082,
                  .071, .231, .066, -.015, .022)
        bilateral('vastus_lateralis', .227, .705, .041,
                  .063, .225, .070, -.015, .022)
        bilateral('vastus_medialis', .113, .585, .065,
                  .060, .143, .064, -.02, .023)
        bilateral('adductor', .116, .807, .020,
                  .069, .144, .100, .06, .012)
        bilateral('hamstrings', .170, .697, -.102,
                  .094, .230, .075, .025, .015)
        bilateral('knee_patella', .168, .437, .050,
                  .069, .084, .068, 0, .022)
        bilateral('shin', .171, .288, -.004, .076, .201, .076, .01, .023)
        bilateral('gastrocnemius_medial', .124, .308, -.066,
                  .061, .138, .081, -.03, .012)
        bilateral('gastrocnemius_lateral', .216, .328, -.065,
                  .061, .151, .083, .03, .012)
        bilateral('tibialis_anterior', .180, .250, .061,
                  .055, .166, .055, 0, .012)
        bilateral('ankle', .165, .108, .001,
                  .054, .087, .057, 0, .017)
        bilateral('foot_heel', .165, .058, -.025,
                  .083, .055, .108, 0, .023)
        bilateral('foot_toes', .165, .046, .112,
                  .092, .039, .155, 0, .024)
    return v


def _composite(grid: np.ndarray, bounds: list[np.ndarray], anatomy: list[AnatomyVolume], pitch: float):
    axes = [np.arange(bounds[i][0], bounds[i][1]+pitch*.5, pitch,
                      dtype=np.float32) for i in range(3)]
    for volume in anatomy:
        # Tight patch evaluation avoids huge temporary volumes per landmark.
        spread=max(volume.radius_x,volume.radius_y)*1.6+.11
        low=[volume.center_x-spread,volume.center_y-spread,
             volume.center_z-volume.radius_z-.11]
        high=[volume.center_x+spread,volume.center_y+spread,
              volume.center_z+volume.radius_z+.11]
        slices=[]
        for axis in range(3):
            start=max(0,int(np.searchsorted(axes[axis],low[axis])-1))
            stop=min(len(axes[axis]),int(np.searchsorted(axes[axis],high[axis])+2))
            slices.append(slice(start,stop))
        sl=tuple(slices)
        x=axes[0][slices[0]][:,None,None]-volume.center_x
        y=axes[1][slices[1]][None,:,None]-volume.center_y
        z=axes[2][slices[2]][None,None,:]-volume.center_z
        c=np.cos(volume.rotation_xy)
        s=np.sin(volume.rotation_xy)
        u=c*x+s*y
        v=-s*x+c*y
        sdf=(np.sqrt((u/volume.radius_x)**2 +
                     (v/volume.radius_y)**2 +
                     (z/volume.radius_z)**2) - 1.) * min(
                        volume.radius_x,volume.radius_y,volume.radius_z)
        part=grid[sl]
        k=volume.blend
        if k:
            h=np.maximum(k-np.abs(part-sdf),0)/k
            np.minimum(part,sdf,out=part)
            part-=k*h*h*.25
        else:
            np.minimum(part,sdf,out=part)
    return axes


def generate_mesh(pitch:float=.008):
    if not .005 <= pitch <= .018:
        raise ValueError('Review meshing pitch is outside safe authoring limits')
    bounds=[(-1.03,1.03),(-.04,1.94),(-.48,.48)]
    shape=tuple(int(np.ceil((b-a)/pitch))+1 for a,b in bounds)
    field=np.full(shape,1.0,dtype=np.float32)
    anatomy=volumes()
    axes=_composite(field,[np.array(p,dtype=np.float32) for p in bounds],anatomy,pitch)
    # Light sub-voxel smoothing retains actual muscle volumes.
    field=gaussian_filter(field,sigma=.80)
    verts,faces,_,_=marching_cubes(field,level=0,spacing=(pitch,)*3,
                                   allow_degenerate=False)
    verts+=np.array([axes[i][0] for i in range(3)],dtype=np.float64)
    mesh=trimesh.Trimesh(vertices=verts,faces=faces,process=True)
    mesh.remove_unreferenced_vertices()
    mesh.fix_normals()
    if not mesh.is_watertight:
        raise ValueError('The new master requires closed manifold topology')
    if not mesh.is_winding_consistent:
        raise ValueError('Inconsistent normals in anatomical master')
    return mesh,anatomy


def build(output:Path,pitch:float=.008):
    output=Path(output)
    output.mkdir(parents=True,exist_ok=True)
    mesh,anatomy=generate_mesh(pitch)
    # Indexed glTF geometry: separate static QA master, no v9 rig/asset.
    material=trimesh.visual.material.PBRMaterial(
        name='STK_Master_Clay_Unapproved',baseColorFactor=[178,184,196,255],
        metallicFactor=.0,roughnessFactor=.77,doubleSided=False)
    mesh.visual=trimesh.visual.TextureVisuals(material=material)
    scene=trimesh.Scene()
    scene.add_geometry(mesh,geom_name='STK_Master_V10_Static_Unauthorised_QA')
    glb=scene.export(file_type='glb')
    (output/'stk_master_v10_silhouette_unapproved.glb').write_bytes(glb)
    lo,hi=mesh.bounds
    landmark=master_landmarks()
    shoulder_span=landmark['right_shoulder'][0]-landmark['left_shoulder'][0]
    hip_span=landmark['right_hip'][0]-landmark['left_hip'][0]
    report={
        'schema':'stk_v10_new_static_anatomical_master_silhouette_qa',
        'source':'independent procedural anatomical reconstruction, NOT v9 geometry',
        'scope':'block_1_nonanimated_standing_A_pose_silhouette',
        'coordinateSystem':'meters, Y up, Z front',
        'nominalHeightMeters':1.84,
        'mesh':{
            'vertices':int(len(mesh.vertices)),
            'triangles':int(len(mesh.faces)),
            'watertight':bool(mesh.is_watertight),
            'volumeMetersCubed':round(float(abs(mesh.volume)),6),
            'boundsMeters':[np.round(lo,5).tolist(),np.round(hi,5).tolist()],
            'pitchMeters':pitch,
        },
        'anatomicalRegions':len(anatomy),
        'landmarks':{k:list(v) for k,v in landmark.items()},
        'shoulderLandmarkSpanMeters':shoulder_span,
        'hipLandmarkSpanMeters':hip_span,
        'shoulderToHipLandmarkRatio':round(shoulder_span/hip_span,3),
        'reviewViews':['front','back','profile','three_quarter'],
        'comparisonAgainstPreviousMasterReviewed':False,
        'topologyArtistReviewed':False,
        'materialsArtistReviewed':False,
        'physicalDeviceVerified':False,
        'animated':False,'skinned':False,
        'approved':False,'enabled':False,'productionReady':False,
        'catalogExercisesEnabled':0,'catalogExercisesTotal':229,
    }
    (output/'stk_master_v10_silhouette_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return mesh,report


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--pitch',type=float,default=.008)
    args=parser.parse_args()
    _,report=build(args.output,args.pitch)
    print(json.dumps({'schema':report['schema'],
        'triangles':report['mesh']['triangles'],
        'regions':report['anatomicalRegions'],
        'watertight':report['mesh']['watertight'],
        'approved':False},indent=2))


if __name__=='__main__':
    main()