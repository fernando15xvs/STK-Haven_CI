#!/usr/bin/env python3
"""Create honest rendered before/after contact sheets for v10.3.

Uses identical cameras, resolution, materials and authoring pitch.
Pictures come directly from v10.2 and v10.3 GLB raster exports.
"""
from pathlib import Path
import json

from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT=Path(__file__).parent
OUT=ROOT/'build'
OLD=OUT/'baseline_v102_same_pitch'/'renders'
NEW=OUT/'renders'

try:
    big=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',25)
    small=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',19)
except OSError:
    big=ImageFont.load_default();small=big


def views():
    sheet=Image.new('RGB',(1450,1940),'#e9edf2');draw=ImageDraw.Draw(sheet)
    for row,view in enumerate(('front','back','profile','three_quarter')):
        for col,folder in enumerate((OLD,NEW)):
            src=Image.open(folder/(view+'.png')).convert('RGB')
            image=src.resize((700,420))
            sheet.paste(image,(20+col*720,60+row*470))
            draw.text((22+col*720,25+row*470),
                      ('ANTES v10.2' if col==0 else 'AHORA v10.3')+' / '+view,
                      fill='#111827',font=big)
    sheet.save(OUT/'STK_Master_V103_4_Vistas_Comparadas.png')


def arms():
    sheet=Image.new('RGB',(1440,1080),'#e9edf2');draw=ImageDraw.Draw(sheet)
    for row,view in enumerate(('front','three_quarter')):
        for col,folder in enumerate((OLD,NEW)):
            src=Image.open(folder/(view+'.png')).convert('RGB')
            # Arms/hands: same full-frame crop; no artificial scaling difference.
            crop=src.crop((0,110,700,620))
            sheet.paste(crop,(20+col*720,30+row*540))
            draw.text((22+col*720,row*540+4),
                      ('ANTES v10.2' if col==0 else 'AHORA v10.3')+' / '+view,
                      fill='#111827',font=small)
    sheet.save(OUT/'STK_Master_V103_Brazos_Manos_Detalle.png')


def score():
    rows=[]
    for view in ('front','back','profile','three_quarter'):
        a=np.asarray(Image.open(OLD/(view+'.png')).convert('RGB'),dtype=np.int16)
        b=np.asarray(Image.open(NEW/(view+'.png')).convert('RGB'),dtype=np.int16)
        diff=np.max(np.abs(a-b),axis=2)
        changed=diff>=8
        rows.append({'view':view,'pixelsTotal':int(diff.size),
            'changedPixelsAtLeast8':int(changed.sum()),
            'changedPercent':round(float(changed.mean()*100),3),
            'note':'Fixed VTK camera, same pitch and color material.'})
    doc={'schema':'stk_v103_rendered_same_camera_silhouette_comparison_QA',
         'metrics':rows,'automatedArtSignoff':False,
         'professionalAnatomyReviewComplete':False,
         'approved':False,'enabled':False}
    (OUT/'visual_delta_v103.json').write_text(json.dumps(doc,indent=2)+'\n')
    return doc

if __name__=='__main__':
    views();arms();print(json.dumps(score(),indent=2))