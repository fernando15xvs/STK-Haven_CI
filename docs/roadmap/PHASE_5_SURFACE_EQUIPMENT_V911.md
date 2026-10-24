# STK Haven — v9.11, tres ejercicios en escena mixta (solo QA)

Rama: feat/mobile-lottie-batch1-drafts-20261018. Alcance: Flutter iOS/Android y scripts de prueba; no web, Supabase, historiales, catálogo ni main.

## Auditoría de proximidad corporal

`exercise_surface_collision_v911.py` toma los tres GLB v9.10 del master con 55 articulaciones y 8 correctivos; evalúa hasta 384 vértices corporales en cada uno de los 121 instantes a 30 muestras/segundo. Para reconstruir superficies usa matrices inversas del bind pose, pesos de las articulaciones, rotaciones y traslaciones animadas y los ocho pesos morfológicos. Calcula distancias firmadas a los siete elementos cilíndricos de barra, mangas y discos, cajas del banco y plano de suelo.

Registra muestras próximas a la barra, penetraciones posibles alejadas del agarre, penetraciones posibles del banco y puntos por debajo del suelo. Estas métricas **no certifican ausencia de colisiones**: se muestrean vértices dispersos, no todos los triángulos ni contactos entre dedos y barra; tampoco se modela compresión corporal o mecánica de cargas. Los casos observados exigen inspección.

Salida de CI: `build/cc0_master_surface_v7/three_exercise_pilots_v99/scapular_v910/surface_v911/surface_collision_v911.json`. El informe mantiene `approved:false`, `enabled:false` y `collisionFreeCertified:false`.

## Visualización de equipo y cuerpo

`GlbSkinnedScene.decodeMasterExercise` acepta exclusivamente los IDs históricos de press banca, remo con barra y sentadilla, con rig de 55 articulaciones, versión experimental v9.10, una animación, una piel con doce regiones y barra/banco como nodos rígidos independientes. Límite de archivo de revisión de 1,4 MiB; el decodificador del master genérico sigue limitado a 850 KiB.

`AnatomicalGlbPreview` usa Canvas y composición por profundidad para las escenas que incluyen equipamiento. La ruta nativa Metal/GLES3 todavía solo sabe representar la malla skinned; se bloquea explícitamente para estos tres modelos para evitar que barra y banco desaparezcan. Se añaden pruebas Flutter que verifican lectura, geometría de equipamiento y fallback.

## Puertas todavía pendientes

No hay render GPU nativo mixto con Z-buffer único, prueba de presentación de FPS en teléfonos físicos, detección exhaustiva de colisiones, escultura muscular profesional ni aprobación biomecánica. Se mantienen **229 borradores, 0 aprobados y 0 habilitados**. El PR #43 continúa abierto; acciones únicamente en el repositorio público STK-Haven_CI.
