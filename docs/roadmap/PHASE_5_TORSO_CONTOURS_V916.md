# STK Haven — Fase 5 v9.16: paredes abdominales y serratos (QA)

**Solo Flutter iOS/Android.** La animación 3D profesional continúa en desarrollo, **no se activa ni se integra en el catálogo**. No modifica `main`, web, Supabase, historial ni los 229 ejercicios.

## Motivación

La malla v9.15 ya tenía once máscaras musculares para pectoral/deltoides/espalda/brazos/piernas, pero **carecía de tratamientos separados** de recto abdominal, oblicuo externo y serrato anterior, exigidos en el plan anatómico original. No se alteran las doce primitivas existentes ni se inventan regiones de malla fisiológicamente exactas.

## Implementación v9.16

`apps/app_mobile/tool/anatomical_3d/build_torso_contours_v916.py` toma los ocho GLB **no aprobados** de v9.15 (cuatro de alta resolución, cuatro LOD móvil) y añade tres **campos volumétricos bilaterales de revisión artística** sobre la superficie ventral:

- `rectus_abdominis`: tres pares de relieves limitados, con espacio medial para la línea alba. No se presenta como un recto abdominal completo con inserciones médicamente exactas.
- `obliquus_externus_abdominis`: sombreado diagonal de la pared anterolateral del abdomen.
- `serratus_anterior`: cuatro relieves oblicuos acotados en la caja torácica lateral, por debajo del hombro.

Se exige la escala y orientación exactas del maestro **CC0/Y-up v9.15**, verificada por la procedencia. El campo no se aplica a la espalda, las piernas ni fuera de la zona ventral. El relieve total **nunca puede superar 1,85 mm** por vértice, se comprueba que no haya triángulos invertidos y se rebaja la intensidad si se detecta alguno. Se recalculan las normales de la versión high-poly con 19.004 vértices.

En el master móvil y cada ejercicio piloto se conservan exactamente **4.727 posiciones**, **9.843 triángulos**, **55 articulaciones**, las **8 morph targets**, sus pesos, matrices, movimientos y nodos de barra/banco. Solo se transfiere una parte de las normales en las tres zonas del torso, con **desviación máxima de 10°**. Las nuevas salidas no añaden polígonos móviles, no añaden texturas y mantienen presupuesto de 850 KiB (master) y 1,4 MiB (pilotos). Se generan otros ocho GLB **solo de laboratorio** en `build/cc0_master_surface_v7/v8_authoring/detail_bake_v915/torso_v916/` y `torso_contours_v916_report.json` con SHA-256, contadores, límites y estado sin aprobación.

El test Python `test_cc0_interpolated_motion.py` audita los ocho archivos reales, compatibilidad con rig y morphs, aislamiento de campos bilaterales, regiones de prueba, integridad de malla y rechazo de entradas aprobadas. `torso_contours_v916_visual_test.dart` prueba reproducción Flutter de tres pilotos más el master, ambos modos y ocho acentos, y produce capturas en el artefacto visual ya existente del CI.

## Restricciones y próximos pasos

Estos tres nuevos campos son **aproximaciones de arte procedural**, no un atlas segmentado exacto ni un modelo validado por anatomista. No contienen fibras, tendones, fascia, piel PBR, múltiples capas musculares ni UV/texturas finales. Aunque las normales modifican la iluminación, no se ve la nueva geometría high-poly directamente en la app: queda para autoría. Los GLB de pruebas **permanecen deshabilitados** y no se prometen FPS ni precisión biomecánica sin medir en dispositivos físicos.

Para mejorar significativamente el aspecto visual aún es imprescindible una escultura profesional con referencias, retopología de torso/manos y baking de texturas tangenciales en un renderer nativo que admita mapas PBR. Revisión de técnica y hardware antes de aprobar press banca, remo y sentadilla y, después, las demás 226 animaciones.

**Inventario: 229 borradores; 0 aprobados, 0 habilitados.** Código fuente privado: `fernando15xvs/STK-Haven`. Espejo y Actions únicamente en `fernando15xvs/STK-Haven_CI`; PR #43 sin fusionar.
