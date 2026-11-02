# STK Haven — GLB v3.2: superficies de transición anatómica móvil

Estado: **candidato experimental**, sin aprobación visual ni biomecánica.
Rama: `feat/mobile-lottie-batch1-drafts-20261018` · PR público #43.

## Implementación

`apps/app_mobile/tool/anatomical_3d/build_refined_anatomical_glb.py` extiende el generador GLB v3.1, sin alterar su rig de 19 huesos, los IDs estables, los clips de animación ni las restricciones cinemáticas de manos y pies. Produce GLB glTF 2.0 autónomos para `ex_bench_press`, `ex_barbell_row` y `ex_squat`.

Se añaden **11 mallas por personaje** con secciones elípticas contiguas y pesos suavizados entre huesos:

- Transición cuello–tórax con influencia progresiva de pecho, cuello y cabeza.
- Dos transiciones escápula–húmero, que mezclan pecho, clavícula y brazo superior.
- Dos puentes de trapecio superior hacia clavículas y cuello.
- Dos transiciones pelvis–fémur para evitar volúmenes completamente independientes en la cadera.
- Dos regiones fémur–tibia con mezcla de pesos para acompañar la flexión de rodilla.
- Dos volúmenes tendinosos rotulianos pequeños, ligados a muslo/pierna.

Son **mallas de volumen superpuestas**, no un único cuerpo completamente estanco. Ocultan algunas discontinuidades, pero no sustituyen un modelo muscular profesional con topología única, retopología, UVs y pesos artísticos.

Las mallas se generan de forma reproducible sin descarga de terceros, texturas ni GIF. Se conservan materiales gris/activo del tema y un presupuesto inferior a 850 KiB por GLB. Salida interna en `apps/app_mobile/build/anatomical_3d_glb/`, fuera de `pubspec.yaml` y de las pantallas de usuario.

## Puertas de calidad

La prueba `test_refined_anatomical_glb.py` verifica que los 3 modelos exportan las 11 regiones, incluyen influencias válidas de 1–4 huesos, pesos normalizados, continuidad de anillos, malla válida, tamaño/triángulos acotados, reproducibilidad y estado sin publicar. Se conservan las pruebas de contacto v3.1 y los tests Flutter del lector GLB real, incluida la evidencia PNG con claro/oscuro.

Pendiente de **inspección visual de los fotogramas y deformaciones**, revisión humana de ejecución, rendimiento físico en iOS/Android y renderizado 3D acelerado con profundidad. El visor actual usa skinning CPU Dart y `Canvas.drawVertices`, no un pipeline GPU integral.

**229 borradores, 0 aprobados y 0 habilitados.** No tocar `apps/app_web`, Supabase ni el historial; acciones únicamente en `STK-Haven_CI`.
