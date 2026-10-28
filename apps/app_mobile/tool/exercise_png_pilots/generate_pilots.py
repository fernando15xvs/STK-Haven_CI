#!/usr/bin/env python3
"""STK Haven: twelve transparent illustrated PNG exercise frames, QA pilot.

The drawings are ORIGINAL simplified teaching illustrations, not medical
anatomical plates, photographs or approved biomechanics. Three exact IDs.
Run from anywhere. No remote image downloads or GIFs.
"""
from __future__ import annotations
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

IDS=("ex_bench_press","ex_barbell_row","ex_squat")
PHASES=("01_inicio","02_ejecucion","03_contraccion","04_retorno")
W,H,S=480,500,2
RED=(239,67,68,255)
BLUE=(43,115,246,255)
SKIN=(183,194,205,255)
LIGHT=(227,231,237,255)
SHADE=(115,130,147,255)
INK=(57,67,82,255)
METAL=(86,96,109,255)

def pt(p):
    return tuple(round(v*S) for v in p)

def ellipse(d,p,rad,fill,stroke=INK,thick=2):
    x,y=pt(p); rx,ry=pt(rad)
    d.ellipse((x-rx,y-ry,x+rx,y+ry),fill=fill,
              outline=stroke,width=thick*S)

def capsule(d,a,b,width,fill=SKIN):
    d.line([pt(a),pt(b)],fill=INK,width=(width+4)*S,joint="curve")
    d.line([pt(a),pt(b)],fill=fill,width=width*S,joint="curve")
    for p in (a,b):
        ellipse(d,p,(width/2,width/2),fill,stroke=None)

def limb(d,points,w,fill=SKIN):
    for a,b in zip(points,points[1:]):
        capsule(d,a,b,w,fill)

def patch(d,polygon,fill):
    pts=[pt(x) for x in polygon]
    d.polygon(pts,fill=fill)
    d.line(pts+[pts[0]],fill=INK,width=S,joint="curve")

def muscle(d,spots,color):
    for x,y,rx,ry in spots:
        ellipse(d,(x,y),(rx,ry),color,stroke=(255,255,255,145),thick=1)
        ellipse(d,(x-rx*.25,y-ry*.28),(rx*.16,ry*.35),
                (*color[:3],165),stroke=None)

def head(d,x,y,r=25):
    capsule(d,(x-12,y+29),(x-7,y+14),13)
    ellipse(d,(x,y),(r*.76,r),LIGHT)
    # A minimally stylized face/hair: not a monster placeholder.
    ellipse(d,(x+2,y-14),(r*.65,r*.34),INK,stroke=None)
    d.line([pt((x+r*.40,y+2)),pt((x+r*.60,y+9))],fill=SHADE,width=S)

def bar(d,x,y,length=270):
    capsule(d,(x-length/2,y),(x+length/2,y),6,LIGHT)
    for dx in (-length*.39,length*.39):
        ellipse(d,(x+dx,y),(8,30),METAL)
        ellipse(d,(x+dx-3,y),(3,22),SHADE,stroke=None)

def floor(d):
    d.line([pt((15,458)),pt((462,458))],
           fill=(128,147,167,95),width=2*S)

def torso(d,shoulder,hip,half=38):
    sx,sy=shoulder; hx,hy=hip
    patch(d,[(sx-half,sy-8),(sx+half,sy-8),
             (hx+half*.65,hy+13),(hx-half*.65,hy+13)],SKIN)

def bench(d,t):
    floor(d); height=(121,158,112,144)[t]
    # Freestanding bench, stable feet.
    d.rounded_rectangle((*pt((84,291)),*pt((378,305))),radius=5*S,
                        fill=METAL,outline=INK,width=2*S)
    for x in (124,332): capsule(d,(x,304),(x-7,442),12,METAL)
    limb(d,[(165,274),(134,353),(142,428)],26)
    limb(d,[(201,274),(223,350),(221,428)],25)
    ellipse(d,(144,430),(27,10),LIGHT)
    ellipse(d,(221,430),(27,10),LIGHT)
    torso(d,(267,205),(181,263),42)
    ellipse(d,(184,265),(38,22),SKIN)
    head(d,333,178,23)
    muscle(d,[(278,207,30,20),(248,211,27,17)],RED)
    muscle(d,[(301,193,14,16),(219,206,12,15),
              (281,151,9,13)],BLUE)
    limb(d,[(293,200),(306,height+21),(313,height)],17)
    limb(d,[(233,204),(230,height+20),(228,height)],16)
    bar(d,270,height,263)
    for x in (228,313): ellipse(d,(x,height),(8,8),LIGHT)

def row(d,t):
    floor(d); lifted=(0,27,54,9)[t]
    bar_y=357-lifted
    # Bent-over hips and torso, fixed lumbar posture.
    limb(d,[(290,277),(269,352),(278,432)],30)
    limb(d,[(252,266),(230,345),(219,435)],28)
    for x in (219,279): ellipse(d,(x,436),(25,12),LIGHT)
    torso(d,(196,194),(259,267),40)
    ellipse(d,(264,266),(34,26),SKIN)
    head(d,175,145,25)
    # Long red lat region; red middle traps/rhomboids for this row variant.
    muscle(d,[(227,222,27,22),(210,204,23,18),
              (196,189,12,12)],RED)
    # Posterior deltoid, elbow flexors.
    muscle(d,[(164,193,18,16),(179,262,9,19),
              (252,192,13,15)],BLUE)
    limb(d,[(179,194),(167,272),(155,bar_y)],16)
    limb(d,[(238,195),(232,272),(227,bar_y)],16)
    bar(d,190,bar_y,306)
    for x in (155,227): ellipse(d,(x,bar_y),(8,8),LIGHT)

def squat(d,t):
    floor(d); drop=(0,48,105,32)[t]
    yhip=245+drop
    yshoulder=154+drop*.59
    # Depth changes joint angles, while heels stay down.
    kneeY=343+drop*.55
    kneeL=165-drop*.26
    kneeR=305+drop*.26
    limb(d,[(212,yhip),(kneeL,kneeY),(166,431)],30)
    limb(d,[(275,yhip),(kneeR,kneeY),(313,431)],31)
    for x in (163,316): ellipse(d,(x,440),(24,10),LIGHT)
    torso(d,(244,yshoulder),(243,yhip),48)
    head(d,246,yshoulder-48,25)
    muscle(d,[(209,yhip+2,24,25),(276,yhip+4,24,24),
              (kneeL+21,kneeY-29,15,27),
              (kneeR-20,kneeY-30,15,27)],RED)
    muscle(d,[(244,yshoulder+32,15,22),
              (181,kneeY+35,10,20),
              (287,kneeY+33,10,20)],BLUE)
    # Grip and bar across upper back, elbows under the bar.
    capsule(d,(191,yshoulder+13),(174,yshoulder+48),15)
    capsule(d,(297,yshoulder+13),(315,yshoulder+48),15)
    bar(d,245,yshoulder-4,326)
    ellipse(d,(178,yshoulder-4),(10,9),LIGHT)
    ellipse(d,(310,yshoulder-4),(10,9),LIGHT)

def one(exercise,index):
    im=Image.new("RGBA",(W*S,H*S),(0,0,0,0))
    d=ImageDraw.Draw(im,"RGBA")
    {"ex_bench_press":bench,"ex_barbell_row":row,"ex_squat":squat}[exercise](d,index)
    # Preserve transparency; transparent regions need to remain transparent
    # under both light and dark themes. Do NOT flatten to white/black.
    return im.resize((W,H),Image.Resampling.LANCZOS)

def build(root):
    root=Path(root)
    summary={}
    for exercise in IDS:
        folder=root/exercise
        folder.mkdir(parents=True,exist_ok=True)
        counts=[]
        for phase in range(4):
            img=one(exercise,phase)
            out=folder/(PHASES[phase]+".png")
            img.save(out,optimize=True)
            assert img.mode=="RGBA" and img.getpixel((0,0))[3]==0
            counts.append(out.stat().st_size)
        summary[exercise]=counts
    return summary

if __name__=="__main__":
    arg=argparse.ArgumentParser()
    arg.add_argument("--output",type=Path,
        default=Path("assets/exercise_media/png_pilots"))
    opts=arg.parse_args()
    for name,sizes in build(opts.output).items():
        print(name, len(sizes),"RGBA PNG",sum(sizes),"bytes")
