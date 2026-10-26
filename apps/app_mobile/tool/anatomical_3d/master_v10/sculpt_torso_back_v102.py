#!/usr/bin/env python3
"""STK Haven Master v10 block 2 — independent torso/back geometric sculpt.

This script uses the NEW v10 static A-pose blueprint, not the old v9 model.
Produces 55? NO. It is NOT rigged, skinned, animated or production-ready.
Anatomical grooves are geometry, not textures. Professional artist review
and biomechanical approval remain mandatory.
"""
from __future__ import annotations

import argparse
from dataclasses import replace
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.ndimage import gaussian_filter
from skimage.measure import marching_cubes
import trimesh

from build_master_silhouette_v10 import _composite, volumes

VERSION = 102
BIND_PITCH = .009
REGIONS_RESHAPED = {
    'pectoral_major': dict(center_y=1.438,center_z=.117,
        radius_x=.161,radius_y=.089,radius_z=.062,blend=.029),
    'pectoralis_clavicular': dict(center_y=1.488,center_z=.112,
        radius_x=.104,radius_y=.043,radius_z=.046,blend=.022),
    'rhomboid':dict(center_y=1.437,center_z=-.135,
        radius_x=.087,radius_y=.096,radius_z=.040,blend=.018),
    'upper_trapezius':dict(center_y=1.539,center_z=-.066,
        radius_x=.161,radius_y=.081,radius_z=.065,blend=.027),
    'latissimus_dorsi':dict(center_y=1.302,center_z=-.108,
        radius_x=.100,radius_y=.190,radius_z=.078,blend=.034),
    'rectus_abdominis_1':dict(center_z=.113,radius_y=.044,
        radius_x=.056,radius_z=.023,blend=.021),
    'rectus_abdominis_2':dict(center_z=.110,radius_y=.042,
        radius_x=.054,radius_z=.022,blend=.022),
    'rectus_abdominis_3':dict(center_z=.100,radius_y=.040,
        radius_x=.052,radius_z=.022,blend=.023),
    'external_oblique':dict(center_y=1.180,center_z=.058,
        radius_x=.076,radius_y=.149,radius_z=.058,blend=.032),
    'serratus_anterior':dict(center_y=1.338,center_z=.084,
        radius_x=.069,radius_y=.114,radius_z=.054,blend=.025),
}


def shaped_volumes():
    original=volumes()
    out=[]
    altered=[]
    for v in original:
        suffix=(v.region.split('_',1)[1]
                if v.region.startswith(('left_','right_')) else v.region)
        changes=REGIONS_RESHAPED.get(suffix)
        if changes:
            altered.append(v.region)
            out.append(replace(v,**changes))
        else:
            out.append(v)
    if len(altered)!=20 or len(out)!=len(original):
        raise ValueError('Missing bilateral torso landmark')
    return out,altered


def _segment_distance(x,y,start,end):
    x0,y0=start
    x1,y1=end
    vx,vy=x1-x0,y1-y0
    d=max(1e-8,vx*vx+vy*vy)
    t=np.clip(((x-x0)*vx+(y-y0)*vy)/d,0.,1.)
    return np.sqrt((x-(x0+t*vx))**2+(y-(y0+t*vy))**2)


def _incision(field,axes,start,end,depth,width,face='front'):
    """Carve a *bounded* anatomically placed channel into the true SDF."""
    if not 0<depth<=.018 or not .004<=width<=.030:
        raise ValueError('Out-of-range contour groove')
    if face not in ('front','back'):
        raise ValueError('Invalid torso side')
    bounds=[(min(start[0],end[0])-4*width,
             max(start[0],end[0])+4*width),
            (min(start[1],end[1])-4*width,
             max(start[1],end[1])+4*width),
            (.073,.31) if face=='front' else (-.35,-.075)]
    slices=[]
    for axis,(lo,hi) in enumerate(bounds):
        a=axes[axis]
        slices.append(slice(max(0,int(np.searchsorted(a,lo)-1)),
                            min(len(a),int(np.searchsorted(a,hi)+1))))
    xx=axes[0][slices[0]][:,None,None]
    yy=axes[1][slices[1]][None,:,None]
    zz=axes[2][slices[2]][None,None,:]
    xy=np.exp(-.5*(_segment_distance(xx,yy,start,end)/width)**2)
    z_gate=(np.clip((zz-.076)/.046,0,1) if face=='front'
            else np.clip((-.076-zz)/.046,0,1))
    z_gate=z_gate*z_gate*(3-2*z_gate)
    field[tuple(slices)]+=depth*xy*z_gate


def _surface_anatomy(field,axes):
    """35 deliberately placed actual-surface torso folds and boundaries."""
    marks=[]
    def carve(name,a,b,depth,width,side='front'):
        _incision(field,axes,a,b,depth,width,side)
        marks.append({'name':name,'a':list(a),'b':list(b),
                      'maximumDepthMeters':depth,'sigmaMeters':width,
                      'side':side})
    carve('sternum_upper',(0.,1.367),(0.,1.516),.012,.0062)
    for sign in (-1,1):
        def seg(name,a,b,d,w,side='front'):
            carve(('left_' if sign<0 else 'right_')+name,
                (sign*a[0],a[1]),(sign*b[0],b[1]),d,w,side)
        seg('pectoral_inferior_a',(.015,1.365),(.104,1.361),.011,.008)
        seg('pectoral_inferior_b',(.104,1.361),(.205,1.373),.010,.009)
        seg('pectoral_axillary',(.205,1.373),(.281,1.422),.009,.010)
        seg('deltopectoral',(.264,1.465),(.314,1.405),.008,.008)
        for level,y in enumerate((1.294,1.216,1.140,1.067)):
            seg('rectus_tendinous_'+str(level),
                (.010,y),(.105,y+.005),.0064 if level<3 else .004,.0068)
        seg('linea_semilunaris',(.117,1.062),(.130,1.290),.006,.010)
        seg('serratus_a',(.189,1.315),(.243,1.294),.006,.008)
        seg('serratus_b',(.196,1.276),(.242,1.256),.0058,.008)
        seg('oblique_cut',(.130,1.173),(.213,1.133),.006,.009)
        seg('rhomboid_border',(.046,1.460),(.201,1.423),
            .011,.011,'back')
        seg('scapula_inferior',(.179,1.395),(.240,1.315),
            .010,.013,'back')
        seg('lat_dorsi_boundary',(.256,1.330),(.176,1.169),
            .008,.011,'back')
        seg('trapezius_mid',(.088,1.497),(.217,1.524),
            .007,.013,'back')
    carve('linea_alba',(0.,1.056),(0.,1.327),.007,.0055)
    carve('thoracic_spine',(0.,1.236),(0.,1.537),.010,.010,'back')
    if len(marks)!=35:
        raise ValueError('Missing bilateral sculpt contour')
    return marks


def generate(pitch=.009):
    if not .006<=pitch<=.018:
        raise ValueError('Unsafe authoring pitch')
    bounds=[(-1.03,1.03),(-.04,1.94),(-.48,.48)]
    shape=tuple(int(np.ceil((b-a)/pitch))+1 for a,b in bounds)
    field=np.full(shape,1.,dtype=np.float32)
    anatomy,altered=shaped_volumes()
    axes=_composite(field,
        [np.asarray(v,dtype=np.float32) for v in bounds],anatomy,pitch)
    strokes=_surface_anatomy(field,axes)
    field=gaussian_filter(field,sigma=.62)
    points,triangles,_,_=marching_cubes(field,level=0,
        spacing=(pitch,)*3,allow_degenerate=False)
    points+=np.asarray([a[0] for a in axes],dtype=np.float64)
    mesh=trimesh.Trimesh(vertices=points,faces=triangles,process=True)
    mesh.remove_unreferenced_vertices()
    mesh.fix_normals()
    if not mesh.is_watertight or not mesh.is_winding_consistent:
        raise ValueError('New master needs watertight oriented geometry')
    if not .15<float(mesh.volume)<.35 or len(mesh.faces)<10000:
        raise ValueError('Invalid geometry scale or budget')
    return mesh,altered,strokes


def build(output:Path,pitch=.009):
    output=Path(output)
    output.mkdir(parents=True,exist_ok=True)
    mesh,altered,strokes=generate(pitch)
    material=trimesh.visual.material.PBRMaterial(
        name='STK_Master_V102_Neutral_Clay_Unapproved',
        baseColorFactor=[178,184,196,255],metallicFactor=0.,
        roughnessFactor=.78,doubleSided=False)
    mesh.visual=trimesh.visual.TextureVisuals(material=material)
    scene=trimesh.Scene()
    scene.add_geometry(mesh,geom_name='STK_Master_V102_Torso_Static_QA')
    data=scene.export(file_type='glb')
    filename='stk_master_v102_torso_back_unapproved.glb'
    (output/filename).write_bytes(data)
    report={
      'schema':'stk_master_v102_art_direction_torso_back_QA',
      'source':'new independent v10 character, no v9 body reuse',
      'stage':'phase_1_block_2_torso_back_early_sculpt',
      'sourceMasterV10Frozen':True,
      'modifications':altered,
      'torsoIncisionCount':len(strokes),
      'incisions':strokes,
      'pitchMeters':pitch,
      'mesh':{'vertices':len(mesh.vertices),'triangles':len(mesh.faces),
        'watertight':bool(mesh.is_watertight),
        'windingConsistent':bool(mesh.is_winding_consistent),
        'volumeMetersCubed':round(float(mesh.volume),6),
        'boundsMeters':np.round(mesh.bounds,5).tolist()},
      'glb':{'filename':filename,'bytes':len(data),
             'sha256':hashlib.sha256(data).hexdigest()},
      'baselineComparisonRequired':True,
      'manualArtistApproval':False,
      'anatomyProfessionalSignoff':False,
      'uvComplete':False,'rigged':False,'animated':False,
      'physicalDeviceVerified':False,'approved':False,'enabled':False,
      'productionReady':False,'exercisesApproved':0,'catalogTotal':229,
    }
    (output/'stk_master_v102_torso_back_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return mesh,report


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--pitch',type=float,default=BIND_PITCH)
    args=parser.parse_args()
    _,report=build(args.output,args.pitch)
    print(json.dumps({k:report[k] for k in
        ('schema','mesh','torsoIncisionCount','approved')},indent=2))
