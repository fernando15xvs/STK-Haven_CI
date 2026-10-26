# STK Haven — Maestro anatómico v10.3 · Fase 1 / Bloque 3

**Estado:** escultura preliminar de brazos/manos construida; **no aprobada**. No hay rig ni reproducción Flutter. Fuente anatómica nueva v10; no retoca la antigua malla v9 de ejercicios.

## Cambios reales

- Se han reesculpido **32 volúmenes bilaterales** de hombro, brazo, codo, antebrazo, muñeca, palma y dedos respecto a los parámetros v10.2, conservando los **35 surcos geométricos** frontales y dorsales del torso v10.2.
- Se han agregado prominencias tenares/hipotenares, un segundo segmento del pulgar y cuatro zonas metacarpianas en cada mano. La superficie final es una **sola malla cerrada**, no dedos dibujados mediante color.
- Se han grabado ocho surcos suaves alrededor de bíceps, tríceps y braquiorradial. Esto NO implica una anatomía profesional ni una malla apta para agarres articulados.
- Las cuatro vistas se renderizan directamente del GLB usando la misma cámara/material y **pitch 12 mm** en ambas versiones. La comparación de frente difiere un **4,496 %** de píxeles (delta máximo de canal ≥8); espalda 4,446 %, perfil 1,597 %, 3/4 4,117 %. Son cambios **visibles en superficie** pero NO pruebas de calidad estética.
- Se conserva el volumen y la malla del torso: el 95 % de vértices muestreados de la superficie central coincidieron con el baseline al mismo pitch.

## Construcción reproducible

```bash
cd apps/app_mobile/tool/anatomical_3d/master_v10
python -m pip install -r requirements-authoring.txt
python -m unittest test_arms_hands_v103.py -v
python sculpt_arms_hands_v103.py --output build/master-v103-review --pitch .012
# Las capturas requieren además requirements-render.txt y VTK:
python render_master_v10.py --glb build/master-v103-review/stk_master_v103_arms_hands_unapproved.glb --output build/master-v103-review/renders
```

Artefactos de QA: `stk_master_v103_arms_hands_unapproved.glb` y `stk_master_v103_arms_hands_report.json`. El GLB es PBR arcilla gris; no tiene UV artística, piel, peso de huesos, clips, equipamiento o aprobación manual.

## Puerta de aceptación

La geometría actual todavía presenta dedos demasiado sencillos y cabeza/rostro provisionales; tampoco hay huesos de manos para flexión natural. **No dar por finalizado el personaje ni habilitar ejercicios.** La siguiente revisión debe corregir manos/rostro y articulaciones antes de entrenamiento.

**Restricciones:** exclusivamente `apps/app_mobile/tool/anatomical_3d/master_v10`, documentación y pruebas en espejo público. No tocar web, Supabase, `main`, historial, catálogo ni producción. 229 ejercicios existentes: 0 aprobados / 0 habilitados para el maestro v10.