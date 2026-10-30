#!/usr/bin/env python3
"""Unapproved anatomical 2.5D vector experiment for the three mobile pilots.

NOT the approved photorealistic 3D reference. The 229 original drafts remain
untouched. Output is generated on demand for Flutter QA, not bundled in the app.
"""
import argparse
import json
from pathlib import Path
import build_visual_pilots as base

HERE = Path(__file__).resolve().parents[1]
OUTPUT = HERE/'build/anatomical_v2'
IDS = ('ex_bench_press','ex_barbell_row','ex_squat')
ORIGINAL = base.artwork
COLORS = dict(skin='#A8B1BB',skinShade='#78838F',skinLight='#DFE4E9',
  kit='#A8B1BB',kitShade='#78838F',shorts='#30363F',ink='#303946',
  hair='#56616D',seam='#697888',shoe='#6A737D',metal='#727E8C',
  metalLight='#C5CCD4',plate='#303742',floor='#8994A0',
  muscleLight='#E1E6EB',muscleDeep='#65717D',
  targetPrimary='#2962FF',targetSecondary='#7DA0FF')

def muscle(name, shape, color, stroke=0.5):
    return dict(name=name,path=shape,color=color,stroke=stroke)

def artwork(exercise, frame):
    parts=ORIGINAL(exercise,frame)
    for item in parts:
        n=item['name']
        if n=='tank':item['color']='skin'
        elif n=='tank_side_shade':item['color']='skinShade'
        elif n=='tank_chest_detail':item['color']='muscleDeep'
        elif n=='waist_band':item['color']='muscleDeep'
        elif n.endswith('_shoe_accent'):item['color']='shoe'
    p=base.pose(exercise,frame)
    h,s,k,e=(p[v] for v in ('hip','shoulder','knee','elbow'))
    axis=base.unit(base.sub(s,h));side=base.perp(axis)
    def loc(x,y):
        return base.add(base.add(s,base.mul(side,x)),base.mul(axis,y))
    def patch(name,points,color):
        return muscle(name,base.path(points,.38),color)
    torso=[
      patch('external_oblique',[loc(-16,-65),loc(-6,-55),loc(10,-66),
                                loc(17,-83),loc(3,-93),loc(-15,-85)],'muscleDeep'),
      patch('rib_volume',[loc(-11,-39),loc(6,-36),loc(16,-48),
                          loc(8,-62),loc(-11,-58)],'muscleLight'),
      patch('pectoral_plane',[loc(-14,-9),loc(6,-7),loc(22,-19),
                              loc(17,-37),loc(2,-47),loc(-15,-31)],'muscleLight')]
    if exercise==IDS[0]:
        torso += [
          patch('pectoralis_major',[loc(-12,-11),loc(5,-10),loc(21,-21),
                                    loc(16,-36),loc(0,-43),loc(-12,-31)],'targetPrimary'),
          muscle('pectoral_inferior_contour',
                 base.segment(loc(-5,-43),loc(15,-37),2,1),'targetSecondary',0)]
    elif exercise==IDS[1]:
        torso += [
          patch('latissimus_dorsi',[loc(-21,-31),loc(-17,-63),loc(-8,-98),
                                     loc(11,-83),loc(14,-58),loc(-3,-38)],'targetPrimary'),
          patch('middle_trapezius',[loc(-19,-4),loc(5,-12),loc(15,-34),
                                    loc(-10,-33)],'targetPrimary'),
          patch('rhomboids',[loc(-11,-23),loc(2,-24),loc(9,-43),
                             loc(-12,-46)],'targetSecondary')]
    else:
        torso.append(patch('rectus_abdominis',[loc(-6,-52),loc(9,-53),
                     loc(12,-91),loc(-4,-93)],'muscleLight'))
    leg=[
      muscle('vastus_lateralis',base.segment(base.lerp(h,k,.19),
                  base.lerp(h,k,.83),11,6),
                  'targetPrimary' if exercise==IDS[2] else 'muscleLight'),
      muscle('rectus_femoris',base.segment(base.lerp(h,k,.17),
                 base.lerp(h,k,.78),4,3),
                 'targetSecondary' if exercise==IDS[2] else 'muscleDeep',0)]
    if exercise==IDS[2]:
        leg += [
          muscle('gluteus_maximus',base.oval(base.lerp(h,k,.06),17,18),
                 'targetPrimary'),
          muscle('adductor_magnus',base.segment(base.lerp(h,k,.26),
                 base.lerp(h,k,.78),3,2),'targetSecondary',0)]
    arm=[]
    if exercise!=IDS[2]:
        arm=[
          muscle('brachialis',base.segment(base.lerp(s,e,.27),
                 base.lerp(s,e,.8),7,4),'muscleLight',0),
          muscle('deltoid_anterior' if exercise==IDS[0] else 'deltoid_posterior',
                 base.oval(s,13,12),'targetSecondary',0),
          muscle('triceps_brachii' if exercise==IDS[0] else 'elbow_flexors',
                 base.segment(base.lerp(s,e,.21),base.lerp(s,e,.67),7,4),
                 'targetSecondary',0)]
    additions={'quadriceps_light':leg,'tank_chest_detail':torso,'biceps_light':arm}
    out=[]
    for item in parts:
        out.append(item)
        out.extend(additions.get(item['name'],()))
    return out

def build(output=OUTPUT):
    output=Path(output)
    output.mkdir(parents=True,exist_ok=True)
    old_artwork,old_frames=base.artwork,base.FRAMES
    old_colors=dict(base.COLORS)
    base.artwork=artwork
    base.FRAMES=tuple(range(0,121,15))
    base.COLORS.update(COLORS)
    manifest={'version':2,'status':'visual_candidate_2_5d_not_3d',
       'approved':False,'enabled':False,'visualDirectionApproved':True,
       'disclaimer':'Vector proof of concept, not 3D reference-quality artwork',
       'items':[]}
    try:
        for exercise,title in zip(IDS,base.TITLES):
            doc=base.composition(exercise)
            doc['nm']='STK Haven / '+exercise+' / anatomical v2 / UNAPPROVED'
            payload=json.dumps(doc,separators=(',',':'),ensure_ascii=False)+'\n'
            (output/(exercise+'.json')).write_text(payload,encoding='utf8')
            (output/(exercise+'.svg')).write_text(base.svg(exercise,60),encoding='utf8')
            manifest['items'].append({'id':exercise,'name':title,
              'bytes':len(payload.encode()),'layers':len(doc['layers']),
              'approved':False,'enabled':False})
        (output/'manifest.json').write_text(
             json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
    finally:
        base.artwork,base.FRAMES=old_artwork,old_frames
        base.COLORS.clear()
        base.COLORS.update(old_colors)
    return manifest

if __name__=='__main__':
    arg=argparse.ArgumentParser()
    arg.add_argument('--output',type=Path,default=OUTPUT)
    args=arg.parse_args()
    print(json.dumps(build(args.output),indent=2))
