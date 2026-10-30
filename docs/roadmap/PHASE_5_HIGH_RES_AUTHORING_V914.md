# STK Haven — Fase 5, v9.14: malla de autoría de alta resolución

**Estado: revisión offline, NO producción.** Solo el personaje Flutter iOS/Android. No se modifica `main`, `apps/app_web`, Supabase, datos/historial, IDs, assets de catálogo ni `pubspec.yaml`. Rama: `feat/mobile-lottie-batch1-drafts-20261018`.

## Qué cambia realmente

Se añade `apps/app_mobile/tool/anatomical_3d/build_master_high_res_v914.py`. Consume el master anatómico **v9.13** (55 huesos, ocho correctivos morfológicos, once regiones semánticas y cuerpo neutro) y las tres demostraciones del mismo master para press banca, remo y sentadilla. Crea **cuatro GLB NUEVOS**, solo para autoría/artistas y QA.

La malla v9.13 de 4.727 vértices / 9.843 triángulos pasa a 19.004 vértices / 39.372 triángulos. Cada cara se subdivide en cuatro usando índices soldados en bordes comunes, también entre las once regiones anatómicas; NO genera once mallas superpuestas ni abre costuras en los límites.

Los vértices nuevos interpolan normales, posiciones y los **ocho morph targets**. Se interpolan los pesos de skinning de los dos extremos del borde y conservan las cuatro influencias más relevantes, renormalizadas. La pérdida máxima observada localmente es ~0,033 de masa normalizada, con una puerta que rechaza discontinuidades mayores de 0,26. Los originales se preservan como primeras 4.727 entradas de los buffers nuevos.

Se añade una curvatura de Hermite pequeña a puntos intermedios, con **límite absoluto 1,4 mm**, como base para esculpido artístico posterior, no anatomía aprobada. Los triángulos diminutos se comprueban de nuevo para evitar caras invertidas: se eliminan offsets donde la curvatura provocaría pliegues. En la prueba local se corrigieron 39 aristas y quedaron cero triángulos invertidos. Nada de esto demuestra biomecánica humana correcta.

El archivo master completo original de v8 y los tres modelos móviles anteriores **se conservan byte a byte**; únicamente se agregan salidas de revisión. Ningún hueso, nodo, clip, matriz inversa, material o barra/banco cambia.

## Tamaños y flujo

| Métrica | v9.13 móvil | v9.14 autoría |
|---|---:|---:|
| Vértices de piel | 4.727 | 19.004 |
| Triángulos de piel | 9.843 | 39.372 |
| Rig | 55 | 55 |
| Morphs | 8 | 8 |
| Regiones anatómicas | 11 | 11 |
| Master GLB, aproximado | 830 KiB | 3,63 MiB |
| Aprobado/habilitado | No | No |

La malla de autoría está deliberadamente **por encima de los límites de Flutter** (850 KiB master genérico y 1,4 MiB piloto de revisión). `high_res_v914_quarantine_test.dart` verifica que el reproductor rechace esos archivos y siga abriendo las versiones v8 optimizadas. Nunca elevar límites de producción solo para pasar una prueba.

Las nuevas salidas viven en:
`apps/app_mobile/build/cc0_master_surface_v7/v8_authoring/high_res_v914/`

- `stk_master_v914_high_res_authoring.glb`
- `ex_bench_press_master55_v914_high_res_qa.glb`
- `ex_barbell_row_master55_v914_high_res_qa.glb`
- `ex_squat_master55_v914_high_res_qa.glb`
- `high_res_authoring_v914_report.json` — hashes de origen/destino, tamaño, articulaciones, regiones, triángulos y calidad de plegado.

Se construyen y prueban en `test_cc0_interpolated_motion.py`, paso existente del CI público. El artefacto público `stk-haven-visual-pilots` ya incluye todo el árbol `build/cc0_master_surface_v7/`, de manera que no hace falta un nuevo workflow, y no se ejecutan Actions privados.

## Limitaciones y siguiente puerta

**Subdivisión no crea inserciones musculares, tendones o fascia de calidad profesional.** Las once regiones proceden de la segmentación aproximada CC0 existente. Hace falta esculpido guiado por artista con mapas normales y referencias anatómicas, retopología para codos, escápulas, manos, serrato, oblicuos y abdomen, y después *bake* al LOD ligero de Flutter.

Tampoco se certifican los movimientos, contacto piel/barra/banco, ni la fluidez real del GPU en teléfonos iOS/Android. Se requieren revisión biomecánica independiente y fotos/video reales de ambos sistemas para autorizar una demostración.

**Reglas invariantes:** 229 borradores, **0/229 aprobados**, **0/229 habilitados**. No producir animaciones de los otros 226 ejercicios hasta validar los tres pilotos y la anatomía.
