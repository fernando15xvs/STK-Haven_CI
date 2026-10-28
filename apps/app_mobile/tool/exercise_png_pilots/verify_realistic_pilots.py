#!/usr/bin/env python3
"""Verify 12 original AI illustrated mobile images (no procedural stick figures).
Requires Pillow. Fail closed on changed artwork, missing transparency or anatomy
highlight colors; the images remain UNAPPROVED until artistic/biomechanical QA.
"""
from __future__ import annotations
import hashlib
from pathlib import Path
from PIL import Image
EXPECTED={
  'ex_barbell_row/01_inicio.png': 'd5d7cbccc83b4a317a0e1b6f8ebd3f36202316a99513dc7f4394c55d0688cbc2',
  'ex_barbell_row/02_ejecucion.png': '8dd94e226821e19d9a941558ef2fb31859fb97c8449334023752f5b0d46e17af',
  'ex_barbell_row/03_contraccion.png': 'cc3da61c00ca99c1e7a557a16cb5c5cfe970efee281a9272034d083356aebbed',
  'ex_barbell_row/04_retorno.png': '5100ed93143fd936e6a277662809eafcdfe947e5a1bb6591916eb853eb92e884',
  'ex_bench_press/01_inicio.png': '5fc79cbffc931c39adff9b3a95072d35de069526730b365b8e5cb6fedbf2ac19',
  'ex_bench_press/02_ejecucion.png': '7596eb3d32ea23062e70276baf6f6b897fb9c82c5c7f5245fc84432f268daada',
  'ex_bench_press/03_contraccion.png': '7e2878f056fc5095550512cc2d56c7a86ab850e5e4a18a7e47189c17be275523',
  'ex_bench_press/04_retorno.png': 'd68ad81d99f388da95b1270e4bf436f798ec64cb252102aa62d5f1cd9ebb35c6',
  'ex_squat/01_inicio.png': '3a624ac40b7efca0a3e109bbe42055aeb988a2c509881a3d890462b9cb01f1e8',
  'ex_squat/02_ejecucion.png': '79001d3281561fa9bf478e9951ed048811f3a196ad9fb3d86579208ec5bb4d66',
  'ex_squat/03_contraccion.png': '39ef24e1fd23461e6c0abbfec8b14e39146d3ee6f7ffc2a838c90d2bffbb4d24',
  'ex_squat/04_retorno.png': '89c5663e2b02bd92b7df216fbf3f68c9a3e89d1c4564d7285cd7d87753c92712'
}
ROOT=Path(__file__).resolve().parents[2]/'assets/exercise_media/png_pilots'

def verify(root=ROOT):
    actual={str(x.relative_to(root)) for x in root.glob('ex_*/*.png')}
    if actual != set(EXPECTED):
        raise ValueError('PNG pilot set differs from exactly twelve approved-source QA references')
    for relative,sha in EXPECTED.items():
        path=root/relative
        if hashlib.sha256(path.read_bytes()).hexdigest()!=sha:
            raise ValueError('Unexpected artwork or procedural substitute: '+relative)
        with Image.open(path) as source:
            if source.format!='PNG' or source.size!=(480,500):
                raise ValueError('Not a 480x500 PNG: '+relative)
            im=source.convert('RGBA')
            if im.getpixel((0,0))[3] or im.getpixel((479,499))[3]:
                raise ValueError('Opaque studio background: '+relative)
            pixels=list(im.getdata())
            mask=[p for p in pixels if p[3]>150]
            if len(mask)<30000:
                raise ValueError('Insufficient real visible anatomy: '+relative)
            red=sum(1 for r,g,b,a in mask if r>115 and r>g*1.27 and r>b*1.1)
            blue=sum(1 for r,g,b,a in mask if b>100 and b>r*1.22 and b>g*1.05)
            if red<100 or blue<100:
                raise ValueError('Missing main/secondary red-blue muscle highlighting: '+relative)
    return {'exerciseCount':3,'framesPerExercise':4,'verifiedPngs':12,
            'source':'original AI generated illustration (not web stock)',
            'anatomicalProfessionalApproval':False,'enabledByDefault':False}

if __name__=='__main__':
    print(verify())
