# STK Haven — modelo CC0 53 huesos, motion retarget y LOD móvil

Se generan por primera vez 3 GLB de ejercicios utilizando **la malla humana real**
del proveedor CC0 previamente verificada por SHA256, no otro humano de óvalos.
La fuente Innerscene consta de 70.985 vértices, 53 huesos y skin weights.
https://www.innerscene.com/tools/library/3d-parts/human-base-mesh-with-editable-53-bone-rig-8e7c8ab1

## Implementación
- retarget_cc0_glb.py toma la jerarquía del rig y genera 41 keyframes
  durante 4 segundos para bench press, barbell row y squat.
- IK analítico de 2 segmentos para codos y rodillas, manos ligadas a barra,
  pies fijos en keyframes, y raíz corporal según patrón de movimiento.
- GLB completo CC0 con 53 huesos y malla de alta resolución (~6,30 MB).
  Materiales STK_BODY/STK_PRIMARY/STK_SECONDARY en triángulos reales del
  cuerpo (por zonas aproximadas) y STK_EQUIPMENT para barra con discos.
- Versión móvil derivada a voxel de 0,017m, skin-aware con 4 pesos por
  vértice: 6.620 vértices, 13.570 triángulos y menos de 450 KB por ejercicio.
  El original no se descarta: es recurso fuente, no asset empaquetado.
- Prueba Python de hash/licencia, IDs, topología, animación y contactos.
  Prueba de widget Flutter decodifica y pinta realmente los LOD, modo claro
  y oscuro, continuidad y reducción de movimiento.
- Artefactos exclusivamente de GitHub Actions **público**, PR #43.

## Seguridad y calidad
El color se segmenta por regiones de coordenadas aproximadas, NO como
anatomía profesional. El LOD voxel puede originar bordes o deformaciones
antiestéticas. El skinning Flutter sigue calculándose en CPU Dart; son
imágenes de QA, sin FPS ni batería certificados en móviles reales.
Errores de agarre en keyframes no prueban interpolaciones ni cinemática
aprobada por entrenador. Se necesita validación visual y biomecánica
para habilitar los movimientos.

Los 229 ejercicios originales permanecen draft; 0 approved, 0 enabled.
Sin cambios en apps/app_web, historial, Supabase ni pubspec/asset bundle.
Siguiente paso: comparar MP4 con este mismo cuerpo de 53 huesos y evaluar
renderer GPU para producción, sin confundirlo con los MP4 antiguos.
