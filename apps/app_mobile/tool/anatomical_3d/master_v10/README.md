# STK Haven — Fase 1, Bloque 1 (v10): nuevo personaje maestro

**Implementación real, NO personaje final aprobado.** La fuente no
reutiliza ni modifica ninguna malla del modelo v9; construye una superficie
maestra nueva de 92 volúmenes anatómicos conectados, proporciones medidas,
pose A neutral y material arcilla PBR. El master obtenido es un GLB real,
triangulado, con normales consistentes y geometría cerrada. No hay todavía
rig, skinning, animación, UV artística, textura de piel o aprobación profesional.

## Crear la malla

```bash
cd apps/app_mobile/tool/anatomical_3d/master_v10
python3 -m pip install -r requirements-authoring.txt
python3 build_master_silhouette_v10.py --output build/master-v10-review --pitch .008
python3 -m unittest test_master_silhouette_v10.py
```

Para generar las vistas de la **malla real** (no imágenes conceptuales):

```bash
python3 -m pip install -r requirements-render.txt
python3 render_master_v10.py \
  --glb build/master-v10-review/stk_master_v10_silhouette_unapproved.glb \
  --output build/master-v10-review/visual
```

Archivos reproducibles: `stk_master_v10_silhouette_unapproved.glb`,
`stk_master_v10_silhouette_report.json`, y `front.png`, `back.png`,
`profile.png`, `three_quarter.png`. Los archivos generados van en `build/`,
no se registran como assets del catálogo, y no deben publicarse en producción.

## Criterio de calidad / riesgos

- Las 4 vistas se generan del **mismo** master GLB con cámara ortográfica.
- Criterio de primera silueta: hombro/hip anatómico ~2.21 usando landmarks;
  torso, cabeza, brazos, glúteos y piernas presentes en una malla cerrada.
- **Importante:** la construcción volumétrica es una primera maqueta
  anatómica; su aspecto aún es voluminoso y estilizado. No es escultura de
  estudio, no contiene musculatura manualmente retopologizada ni facciones
  detalladas. No debe presentarse como personaje profesional.
- Las capturas de v9.x muestran personajes **animados en otras posturas**;
  no son comparación controlada "misma pose". Para completar la aceptación
  visual hay que crear una escena nueva equivalente de ambos modelos.
- Siguiente trabajo artístico antes de aprobación: revisión de proporciones,
  refinamiento manual del pecho y abdomen, cabeza anatómica, manos y pies,
  retopología, UV/PBR, y revisión humana de cuatro vistas.
- **NO** se activan ejercicios, no se edita Flutter/web/Supabase/historial,
  no se altera ningún ID. 229 ejercicios sin aprobación ni habilitación.
- Fuente: repo privado `fernando15xvs/STK-Haven`; espejo CI público
  `fernando15xvs/STK-Haven_CI`. PR #43 abierto; nunca merge automático.