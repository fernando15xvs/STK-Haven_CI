# STK Haven — Fase 5 v9.41: volumen real de torso sobre piel skinned (QA)

Se continúa desde v9.40 y **no** se reinicia el modelo. La v9.16 ya había
diseñado tres relieves de torso sobre GLB de autoría, pero en el LOD móvil
solo se había transferido parte del sombreado. Este bloque aplica
desplazamientos **reales de vértices POSITION**, y recalcula NORMAL, sobre
la malla de cuerpo ya skinned de los pilotos de press banca, remo con barra
y sentadilla derivados de v9.40.

## Implementación

- `tool/anatomical_3d/sculpt_torso_volume_v941.py` reaprovecha los campos
  aproximados de `build_torso_contours_v916.py` (recto abdominal,
  oblicuo externo y serrato anterior).
- Limita el efecto a vértices influenciados por los huesos auténticos
  `spine_01`, `spine_02`, `spine_03` del rig CC0 de 55 articulaciones;
  exige muestras a ambos lados para las tres regiones.
- Desplazamiento total limitado a **1,20 mm**; protección contra inversión
  de triángulos; cambio de normal limitado a **9°**. Solo se editan los
  atributos `POSITION`/`NORMAL` de la malla de piel existente.
- Se preservan los nodos de equipo, 12 regiones, 55 articulaciones,
  8 morph targets, pesos de skin, jerarquía, movimientos y materiales.
- Tres archivos `*_v941_torso_volume_mobile_qa.glb` y
  `torso_volume_v941_report.json` en
  `build/.../cuticles_v939/lower_leg_v940/torso_v941`.
- `test_torso_volume_v941.py` valida geometría verdadera, cuantías,
  bilateralidad, roundtrip, conservación del equipo y rechazo explícito
  de fuentes aprobadas, desconocidas o procesadas dos veces.

## Estado y límites

El efecto es un **contorno artístico de baja amplitud**, no retopología
manual anatómica, músculos con inserciones reales, UV/texturas PBR,
física de tejidos, reparación de IK ni acreditación biomecánica.
El CI no demuestra FPS, temperatura, batería o calidad de Metal/GLES en
dispositivos físicos; seguirán necesarias revisión artística y técnica.

**229 drafts / 0 approved / 0 enabled.** No se distribuyen estos GLB en
`pubspec.yaml` ni se publican en la app. No se modifica `apps/app_web`,
Supabase, datos, historial, IDs ni producción. Privado
`fernando15xvs/STK-Haven` es la fuente; el espejo público
`fernando15xvs/STK-Haven_CI` solo ejecuta CI, rama
`feat/mobile-lottie-batch1-drafts-20261018`, PR #43 aún sin fusionar.

Siguiente puerta: CI público verde, inspección real de las capturas de
los tres pilotos, retopología profesional del torso/manos, integración
del renderizador GPU con equipo e IK, y benchmarks físicos iOS/Android.
