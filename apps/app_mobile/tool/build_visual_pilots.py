#!/usr/bin/env python3
"""Original editable vector artwork. Review candidates, never approved media.

Only Python stdlib. Lottie and SVG review use the same cubic paths and timeline.
The SVG viewer is an editorial aid, not a Flutter rendering certification.
"""
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tool/visual_pilots'
IDS = ('ex_bench_press', 'ex_barbell_row', 'ex_squat')
TITLES = ('Press de banca', 'Remo con barra', 'Sentadilla libre')
FRAMES = tuple(range(0, 121, 10))
COLORS = dict(skin='#C99170', skinShade='#A56B50', skinLight='#E6B595',
              ink='#263345', hair='#25303E', kit='#2962FF', kitShade='#203A7A',
              shorts='#263345', seam='#8CA5BD', shoe='#E5EBF2',
              metal='#708197', metalLight='#CDD8E6', plate='#34445A', floor='#8895A6')
ACCENTS = dict(blue='#2962FF', violet='#7C3AED', emerald='#047857',
               teal='#007C91', rose='#BE185D', amber='#9A6700',
               coral='#C2410C', slate='#52647C')

def add(a, b): return (a[0]+b[0], a[1]+b[1])
def sub(a, b): return (a[0]-b[0], a[1]-b[1])
def mul(a, k): return (a[0]*k, a[1]*k)
def lerp(a, b, t): return add(a, mul(sub(b, a), t))
def unit(a): return mul(a, 1/math.hypot(*a))
def perp(a): return (-a[1], a[0])
def rounded(p): return [round(p[0], 2), round(p[1], 2)]

def ik(a, b, first, second, side=1):
    d = math.dist(a, b)
    if not abs(first-second) < d <= first+second:
        raise ValueError(('unreachable joint', a, b, d))
    u = unit(sub(b, a))
    x = (first*first-second*second+d*d)/(2*d)
    h = math.sqrt(max(0, first*first-x*x))
    return add(add(a, mul(u, x)), mul(perp(u), h*side))

def phase(frame):
    # Brief setup, controlled descent, brief reversal, deliberate return, settle.
    if frame <= 10 or frame >= 110: return 0.0
    if frame <= 55: return (1-math.cos(math.pi*(frame-10)/45))/2
    if frame <= 65: return 1.0
    return (1+math.cos(math.pi*(frame-65)/45))/2

def pose(exercise, frame):
    q = phase(frame)
    if exercise == IDS[0]:
        hip, shoulder = (302, 319), (193, 303)
        ankle, knee = (385, 428), (366, 355)
        wrist = lerp((195, 185), (230, 286), q)
        elbow = ik(shoulder, wrist, 60, 59, 1)
        head, neck = (151, 307), (172, 303)
        bar = wrist
    elif exercise == IDS[1]:
        hip, shoulder = (216, 317), (305, 252)
        ankle, knee = (268, 428), (281, 349)
        wrist = lerp((315, 370), (263, 296), q)
        elbow = ik(shoulder, wrist, 61, 59, 1)
        neck, head = (323, 238), (341, 218)
        bar = wrist
    else:
        hip = lerp((273, 249), (218, 351), q)
        ankle = (281, 428)
        knee = ik(hip, ankle, 90, 90, -1)
        shoulder = (280, hip[1]-math.sqrt(102**2-(280-hip[0])**2))
        axis = unit(sub(shoulder, hip))
        neck, head = add(shoulder, mul(axis, 22)), add(shoulder, mul(axis, 48))
        bar = add(shoulder, (-12, -8))
        wrist = add(bar, (7, 5))
        elbow = add(shoulder, (-24, 57))
    return dict(hip=hip, shoulder=shoulder, ankle=ankle, knee=knee,
                wrist=wrist, elbow=elbow, head=head, neck=neck, bar=bar)

def path(points, smooth=.7):
    n = len(points)
    incoming, outgoing = [], []
    for i in range(n):
        tangent = mul(sub(points[(i+1)%n], points[(i-1)%n]), smooth/6)
        incoming.append(rounded(mul(tangent, -1)))
        outgoing.append(rounded(tangent))
    return dict(v=[rounded(p) for p in points], i=incoming, o=outgoing, c=True)

def oval(center, rx, ry):
    return path([add(center, (rx*math.cos(i*math.pi/4), ry*math.sin(i*math.pi/4)))
                 for i in range(8)], 1.05)

def segment(a, b, width_a, width_b):
    u=unit(sub(b,a)); n=perp(u)
    return path([add(a,mul(n,width_a*.75)),
                 add(lerp(a,b,.28),mul(n,width_a)),
                 add(lerp(a,b,.72),mul(n,width_b*1.12)),
                 add(b,mul(n,width_b)), add(b,mul(u,width_b*.45)),
                 add(b,mul(n,-width_b)),
                 add(lerp(a,b,.45),mul(n,-width_a*.8)),
                 add(a,mul(n,-width_a*.75)), add(a,mul(u,-width_a*.4))])

def rect(x,y,w,h): return path([(x,y),(x+w,y),(x+w,y+h),(x,y+h)],0)

def artwork(exercise, frame):
    p=pose(exercise,frame); s,h,k,a,e,w=[p[x] for x in ('shoulder','hip','knee','ankle','elbow','wrist')]
    parts=[]
    def shape(name, geometry, color, stroke=1.4):
        parts.append(dict(name=name, path=geometry, color=color, stroke=stroke))
    shape('floor',rect(70,446,372,2),'floor',0)
    # Equipment behind the person, with frame and padding as separate materials.
    if exercise == IDS[0]:
        for x in (157,310):
            shape('bench_leg_'+str(x),rect(x,342,11,97),'metal')
            shape('bench_foot_'+str(x),rect(x-15,437,42,7),'metalLight')
        shape('bench_frame',rect(128,338,211,10),'metal')
        shape('bench_cushion',rect(120,324,225,15),'plate',2)
        shape('bench_piping',rect(122,325,221,3),'metalLight',0)
    # Subtle lateral offset separates far limb without mixing camera angles.
    offset=(-19,-3) if exercise != IDS[0] else (-16,-2)
    fa,fk,fh=[add(x,offset) for x in (a,k,h)]
    shape('far_thigh',segment(fh,fk,23,15),'skinShade')
    shape('far_calf',segment(fk,fa,15,9),'skinShade')
    def shoe(name,ankle):
        x,y=ankle
        shape(name,path([(x-10,y-8),(x+7,y-8),(x+13,y+3),(x+33,y+9),
                         (x+34,y+16),(x-13,y+16),(x-14,y+7)],.35),'shoe')
        shape(name+'_sole',rect(x-13,y+13,46,4),'metal',0)
        shape(name+'_accent',path([(x+4,y+1),(x+17,y+6),(x+11,y+10),(x,y+6)],.15),'kit',0)
    shoe('far_shoe',fa)
    shape('far_upper_arm',segment(add(s,(-9,-4)),add(e,(-11,-4)),19,11),'skinShade')
    shape('far_forearm',segment(add(e,(-11,-4)),add(w,(-7,-3)),13,7),'skinShade')
    shape('near_thigh',segment(h,k,25,16),'skin')
    shape('quadriceps_light',segment(lerp(h,k,.2),lerp(h,k,.76),10,6),'skinLight',0)
    shape('near_calf',segment(k,a,15,8),'skin')
    shape('calf_shadow',segment(lerp(k,a,.22),lerp(k,a,.77),7,4),'skinShade',0)
    shape('knee_cap',oval(k,12,10),'skin',0)
    shoe('near_shoe',a)
    # Pelvis and tank follow the torso axis as a rigid volume.
    u=unit(sub(s,h)); n=perp(u)
    def local(origin,x,y): return add(add(origin,mul(n,x)),mul(u,y))
    shape('shorts',path([local(h,-22,16),local(h,22,16),local(h,26,-24),
                        local(h,5,-32),local(h,-24,-22)],.35),'shorts')
    shape('shorts_seam',segment(local(h,18,9),local(h,18,-20),2,2),'seam',0)
    shape('waist_band',segment(local(h,-22,13),local(h,22,13),3,3),'kit',0)
    shape('neck',segment(p['neck'],s,11,17),'skin')
    shape('tank',path([local(s,-22,-2),local(s,-24,-25),local(h,-18,12),
                       local(h,21,12),local(s,24,-25),local(s,21,4),local(s,8,12)],.5),'kit')
    shape('tank_side_shade',path([local(s,-22,-9),local(s,-15,-27),local(h,-10,14),
                                  local(h,-18,12),local(s,-24,-25)],.3),'kitShade',0)
    shape('tank_chest_detail',segment(local(s,8,-14),local(s,15,-36),2,1),'seam',0)
    # Anatomical profile with forehead, nose, lips, chin and ear; same character.
    cx,cy=p['head']
    head_start=len(parts)
    shape('head',path([(cx-16,cy-14),(cx-8,cy-23),(cx+7,cy-22),(cx+14,cy-13),
                      (cx+15,cy-4),(cx+21,cy+2),(cx+16,cy+5),(cx+16,cy+12),
                      (cx+7,cy+20),(cx-5,cy+18),(cx-16,cy+7)],.45),'skin')
    shape('hair',path([(cx-17,cy+1),(cx-19,cy-13),(cx-11,cy-24),(cx+4,cy-26),
                      (cx+14,cy-19),(cx+14,cy-12),(cx+1,cy-14),(cx-8,cy-7),(cx-9,cy+3)],.5),'hair',0)
    shape('ear',oval((cx-6,cy+2),4,6),'skinLight',.7)
    shape('eye',oval((cx+11,cy-5),1.5,1.5),'ink',0)
    shape('jaw_shadow',path([(cx-3,cy+12),(cx+13,cy+11),(cx+7,cy+18),(cx-3,cy+16)],.3),'skinShade',0)
    if exercise == IDS[0]:
        # Supine profile: face toward ceiling, occiput supported by the cushion.
        for part in parts[head_start:]:
            geo=part['path']
            geo['v']=[rounded((cx+v[1]-cy,cy-v[0]+cx)) for v in geo['v']]
            for key in ('i','o'):
                geo[key]=[rounded((v[1],-v[0])) for v in geo[key]]
    shape('deltoid',oval(s,21,20),'skin',0)
    shape('upper_arm',segment(s,e,19,11),'skin')
    shape('biceps_light',segment(lerp(s,e,.23),lerp(s,e,.72),7,5),'skinLight',0)
    shape('forearm',segment(e,w,13,7),'skin')
    shape('forearm_shade',segment(lerp(e,w,.2),lerp(e,w,.72),4,2),'skinShade',0)
    # Lateral projected bar: short shaft plus circular plate, not a bar in the sagittal plane.
    bx,by=p['bar']
    shape('bar_shaft',rect(bx-27,by-4,54,8),'metalLight')
    shape('far_plate',oval((bx-14,by-3),25,28),'plate',2)
    shape('near_plate',oval((bx+17,by+1),27,30),'plate',2)
    shape('plate_inset',oval((bx+17,by+1),20,23),'metal',1)
    shape('plate_hub',oval((bx+17,by+1),7,8),'metalLight',1)
    shape('plate_hole',oval((bx+17,by+1),3,4),'ink',0)
    shape('gripping_hand',oval(w,8,10),'skin',1)
    shape('thumb',segment(add(w,(-4,-4)),add(w,(3,1)),3,3),'skinLight',0)
    return parts

def rgba(code): return [round(int(code[i:i+2],16)/255,5) for i in (1,3,5)]+[1]
def prop(x): return dict(a=0,k=x)

def composition(exercise):
    samples=[artwork(exercise,f) for f in FRAMES]
    layers=[]
    transform=dict(o=prop(100),r=prop(0),p=prop([0,0,0]),a=prop([0,0,0]),s=prop([100,100,100]))
    for index,part in enumerate(samples[0]):
        paths=[parts[index]['path'] for parts in samples]
        if all(v==paths[0] for v in paths): ks=prop(paths[0])
        else:
            keys=[]
            for i,(f,p) in enumerate(zip(FRAMES,paths)):
                key=dict(t=f,s=[p])
                if i+1<len(paths): key.update(o=dict(x=.333,y=.333),i=dict(x=.667,y=.667))
                keys.append(key)
            ks=dict(a=1,k=keys)
        color=part['color']
        items=[dict(ty='sh',nm=part['name']+'_path',ks=ks),
               dict(ty='fl',nm='color_'+color,c=prop(rgba(COLORS[color])),o=prop(100),r=1)]
        if part['stroke']:
            items.append(dict(ty='st',nm='outline',c=prop(rgba(COLORS['ink'])),
                              o=prop(100),w=prop(part['stroke']),lc=2,lj=2,ml=4))
        items.append(dict(ty='tr',p=prop([0,0]),a=prop([0,0]),s=prop([100,100]),r=prop(0),o=prop(100),sk=prop(0),sa=prop(0)))
        layers.append(dict(ddd=0,ind=index+1,ty=4,nm=part['name'],sr=1,ks=transform,ao=0,
                           shapes=[dict(ty='gr',nm=part['name'],it=items)],ip=0,op=120,st=0,bm=0))
    return dict(v='5.7.4',fr=30,ip=0,op=120,w=512,h=512,nm=f'STK Haven / {exercise} / lateral / visual candidate v1',
                ddd=0,assets=[],layers=list(reversed(layers)),markers=[])

def svg_path(p):
    v,i,o=p['v'],p['i'],p['o']
    d=f'M{v[0][0]},{v[0][1]}'
    for j in range(len(v)):
        nxt=(j+1)%len(v)
        c1=add(v[j],o[j]);c2=add(v[nxt],i[nxt])
        d+=f' C{c1[0]:.2f},{c1[1]:.2f} {c2[0]:.2f},{c2[1]:.2f} {v[nxt][0]},{v[nxt][1]}'
    return d+' Z'

def svg(exercise,frame=0,animate=False):
    result=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="'+exercise+' — candidato sin aprobar">']
    for index,part in enumerate(artwork(exercise,frame)):
        name=part['color']; color=COLORS[name]
        result.append(f'<path d="{svg_path(part["path"])}" fill="var(--{name},{color})" stroke="var(--ink,{COLORS["ink"]})" stroke-width="{part["stroke"]}" stroke-linejoin="round">')
        if animate:
            values=';'.join(svg_path(artwork(exercise,f)[index]['path']) for f in FRAMES)
            result.append(f'<animate attributeName="d" dur="4s" repeatCount="indefinite" values="{values}" keyTimes="'+ ';'.join(str(f/120) for f in FRAMES)+'"/>')
        result.append('</path>')
    return ''.join(result)+'</svg>'

def build(destination=OUT):
    destination.mkdir(parents=True,exist_ok=True)
    manifest=dict(version=1,status='visual_candidate',approved=False,enabled=False,
                  origin='Original STK Haven vector paths; no third-party media',
                  review=dict(visualApproval=False,biomechanics=False,iosDevice=False,androidDevice=False,devicePerformance=False),
                  items=[])
    for exercise,title in zip(IDS,TITLES):
        data=json.dumps(composition(exercise),separators=(',',':'),ensure_ascii=False)+'\n'
        (destination/(exercise+'.json')).write_text(data,encoding='utf-8')
        (destination/(exercise+'.svg')).write_text(svg(exercise,60),encoding='utf-8')
        manifest['items'].append(dict(id=exercise,name=title,bytes=len(data.encode()),frames=120,fps=30))
    (destination/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    cards=''.join('<article><h2>'+title+'</h2>'+svg(exercise,animate=True)+'<p>'+cue+'</p></article>' for exercise,title,cue in zip(IDS,TITLES,
        ('Apoyos estables · descenso controlado · agarre continuo',
         'Torso estable · barra hacia el abdomen · retorno controlado',
         'Pie apoyado · cadera y rodilla coordinadas · barra estable')))
    html='''<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>STK Haven · Pilotos visuales</title>
<style>*{box-sizing:border-box}body{margin:0;background:#F4F5F8;color:#18202D;font:16px system-ui;padding:32px;--kit:#2962FF;--kitShade:#203A7A}body.dark{background:#090A0C;color:#F0F0F3}header{max-width:1400px;margin:auto}small{letter-spacing:.18em;font-weight:700}h1{font-size:36px;margin:12px 0}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}button,select,input{font:inherit;padding:10px;border-radius:10px;border:1px solid #8895A6}main{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;max-width:1400px;margin:auto}article{background:white;border:1px solid #CCD2DD;border-radius:22px;padding:20px}body.dark{--ink:#9AA9BC;--shorts:#596B83;--hair:#596B83;--plate:#596B83}body.dark article{background:#111318;border-color:#343A48}h2{font-size:20px;margin:0}svg{display:block;width:100%}p{font-size:14px;line-height:1.5}.note{max-width:950px}footer{max-width:1400px;margin:24px auto}input{width:200px}@media(max-width:850px){main{grid-template-columns:1fr}body{padding:16px}}</style>
<header><small>STK HAVEN / MOTION LAB 01</small><h1>Tres movimientos. Un personaje.</h1><p class="note">Candidatos de diseño v1 · sin aprobación visual ni biomecánica. Vista vectorial de revisión; la reproducción Flutter y las pruebas físicas se revisan por separado. No incluidos en la app.</p><nav><button id="mode">Modo oscuro</button><select id="accent" aria-label="Color de STK Haven">'''+''.join('<option value="'+v+'">'+k+'</option>' for k,v in ACCENTS.items())+'''</select><button id="play">Pausar</button><label>Fotograma <input type="range" id="scrub" min="0" max="119" value="0"></label></nav></header><main>'''+cards+'''</main><footer>4 segundos · 30 fps · vectores originales · sin imágenes externas. Pendiente: aprobación de estilo, biomecánica, iPhone, Android y perfil de rendimiento.</footer><script>
const svgs=[...document.querySelectorAll('svg')];let paused=false;
function pause(){paused=true;svgs.forEach(s=>s.pauseAnimations());document.querySelector('#play').textContent='Reproducir'}
document.querySelector('#play').onclick=()=>{if(paused){svgs.forEach(s=>s.unpauseAnimations());paused=false;document.querySelector('#play').textContent='Pausar'}else pause()};
document.querySelector('#scrub').oninput=e=>{pause();svgs.forEach(s=>s.setCurrentTime(+e.target.value/30))};
document.querySelector('#mode').onclick=e=>{document.body.classList.toggle('dark');e.target.textContent=document.body.classList.contains('dark')?'Modo claro':'Modo oscuro'};
document.querySelector('#accent').onchange=e=>{document.body.style.setProperty('--kit',e.target.value);document.body.style.setProperty('--kitShade',e.target.value)};
if(matchMedia('(prefers-reduced-motion: reduce)').matches)pause();
</script></html>'''
    (destination/'review.html').write_text(html,encoding='utf-8')
    return manifest

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=OUT)
    args=parser.parse_args();print(json.dumps(build(args.output),indent=2,ensure_ascii=False))
