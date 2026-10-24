# STK Haven — Fase 5, v9.15: detalle muscular de autoría y bake al modelo móvil

**Exclusivamente GLB de revisión de Flutter Android/iOS, SIN aprobación clínica ni publicación.** Conserva intactos 229 ejercicios, los 229 borradores Lottie, el historial, Supabase, `main`, `apps/app_web`, `pubspec.yaml` y la app instalada.

## Resultado técnico

`apps/app_mobile/tool/anatomical_3d/bake_master_detail_v915.py` parte de los cuatro GLB v9.14 de **19.004 vértices, 39.372 triángulos**, 55 huesos y ocho correctivos. Ajusta de forma limitada el relieve de once regiones musculares con perfiles volumétricos bilaterales individuales: pectoral mayor, deltoides anteriores/posteriores, tríceps, dorsal ancho, romboides, trapecio medio, cuádriceps, glúteos, isquiotibiales y aductores.

La superficie experimental utiliza máscaras del atlas de las doce submallas, perfiles anisotrópicos y un descenso suave de relieve hacia los límites. El desplazamiento máximo permitido es **2,4 mm** y la operación reduce automáticamente su magnitud si detecta triángulos invertidos; no acepta casos irresolubles. Recalcula normales de la geometría de autoría.

A continuación **transfiere exclusivamente orientación de las normales** a los 4.727 vértices existentes del modelo móvil v8, con una desviación máxima de 12° respecto al sombreado anterior y mezcla acotada. Esto puede aportar matices de iluminación sin aumentar su geometría, cambiar su silueta o necesitar nuevas texturas. Es un bake de *vertex normals*, **no un normal map UV ni un texture bake de alta frecuencia**.

Produce ocho GLB nuevos dentro de `build/cc0_master_surface_v7/v8_authoring/detail_bake_v915/`:
- Cuatro `*_v915_high_detail_authoring.glb` con relieve de autoría.
- Cuatro `*_v915_mobile_normal_bake_qa.glb` con igual malla y animaciones de bajo peso, pero normales de revisión.
- `normal_bake_v915_report.json` con métricas y SHA-256.

La geometría de la malla móvil, sus 55 joints, skin weights, ocho morph targets, matrices inversas de bind, clips de movimiento, nombres de regiones y nodos de barra/banco deben permanecer **exactamente iguales**. El generador bloquea fuentes desconocidas o aprobadas y archivos fuera de presupuesto: 850 KiB para master v8 móvil, 1,4 MiB para pilotos y 6 MiB para autoría.

`test_cc0_interpolated_motion.py` ejecuta pruebas sobre los ocho archivos reales, confirma hashes/procedencia y sus límites de tamaño, que las posiciones móviles no se muevan y que sus normales sí cambien. `normal_bake_v915_visual_test.dart` valida lectura de los tres pilotos con equipo, animación y capturas en temas claro/oscuro. Los archivos se almacenan **solo como artefactos experimentales del CI público**, no en el paquete de ejercicios.

## Limitaciones pendientes

**Una malla subdividida con relieves heurísticos no se convierte automáticamente en un personaje anatómico profesional.** Este trabajo no crea inserciones tendinosas, fibras de serrato, oblicuos, recto abdominal independiente, materiales PBR de calidad artística, músculos laterales separados ni manos humanas convincentes. Tampoco corrige por sí solo el balance biomecánico, contacto dedos/barra, colisiones o anatomía clínicamente exacta.

Siguiente fase real: integrar escultura y retopología de un artista anatómico, preservar rig/UV/topología a través de LOD, evaluar *normal map* cuando exista soporte de texturas en shaders Metal/GLES y medir la apariencia/rendimiento en iPhone y Android físicos. Es imprescindible una revisión independiente antes de activar cualquiera de las 229 animaciones.

**Estado:** 229 borradores; **0 aprobados, 0 habilitados**. PR #43 permanece sin fusionar. Acciones únicamente en `fernando15xvs/STK-Haven_CI`.
