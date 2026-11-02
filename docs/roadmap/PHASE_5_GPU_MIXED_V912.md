# STK Haven — Fase 5 v9.12: render GPU mixto experimental

**Estado: solo laboratorio.** Se conserva el historial, los 229 ejercicios, el catálogo, el modo claro/oscuro, los ocho colores, Supabase, apps/app_web y main. Rama: `feat/mobile-lottie-batch1-drafts-20261018`; fuente privada `STK-Haven`, CI en `STK-Haven_CI`. Sin activar archivos en pubspec.

## Regresión de v9.11 encontrada

CI público #512: los tests móviles y las compilaciones pasaron, pero `flutter analyze` marcó una aserción de no-nulo redundante en el decodificador de ejercicios. Se ha eliminado antes de validar este bloque. No confundir CI #512 con un resultado completamente verde.

## Implementación de v9.12

- `GlbSkinnedScene.shaderIndexedMorphSource(...includeRigid:true)` genera un flujo indexado **único** de 42 floats por vértice para la piel skinned de 55 huesos y el equipo independiente (barra/discos, banco). Los nodos rígidos se transforman con su matriz animada al espacio global para cada pose; sus ocho desplazamientos morfológicos son exactamente cero.
- El flujo usa una marca interna de articulación `joint0=-1` en vertices rígidos con pesos `[1,0,0,0]`. Esa marca está prohibida en los paquetes skinned de producción o en las vías GPU anteriores. La fábrica específica `GpuIndexedMorphPacket.fromMixedScene` comprueba pesos y canales de equipo, presupuesto máximo de 25 mil triángulos y 12 MiB, ocho morph weights y estado de geometría mixta.
- Se corrige un problema de transporte importante: `StandardMessageCodec` admite `Int32List`, pero no `Uint32List`; los índices siguen como uint32 en memoria y se serializan a **Int32List** tras validar que cada índice está dentro del rango pequeño del master.
- OpenGL ES 3.0 (Android) y Metal (iOS) mantienen la **misma prueba de profundidad** para ambos tipos de triángulos. Un shader descarta la multiplicación de huesos para vértices con la marca rígida y los proyecta desde sus coordenadas de mundo. La validación nativa rechaza el sentinel si falta `mixedRigid:true`, el modo no es indexado, faltan vértices de equipo o existen morfos rígidos no nulos. No se cambia la secuencia de dibujado o superficie nativa compartida.
- `AnatomicalGlbPreview(experimentalMixedGpuStatic:true,experimentalIndexedGpu:true)` habilita únicamente la foto estática de laboratorio con equipamiento; ambas banderas son **false por defecto**. `NativeGpuSkinnedGlbReview` rechaza escenas con equipo si faltan sus permisos de QA o se solicita playback; mantiene fallback completo a Canvas ante cualquier fallo nativo. Los ejercicios no entran por ninguna ruta de entrenamiento.
- Test Flutter sobre los tres archivos v9.10, 4 tiempos por ejercicio: comprueba que se compone equipamiento+piel, paridad de proyección 3D con Canvas, existencia de elementos rígidos, serialización `StandardMessageCodec`, bloqueo de paquetes sin bandera y rechazo de morphs espurios de equipo. Un JSON en `build/cc0_master_v7_flutter_qa/native_mixed_indexed_v912.json` registra tamaños y conserva `approved:false`.

## Limitaciones y calidad pendiente

Este pipeline usa un método de **subida total de malla por nueva pose estática**, porque barra y banco se transforman en Dart. No implementar reproducción continua con esta ruta hasta optimizar buffers separados y sincronización temporal. El ACK de la llamada nativa no demuestra que un fotograma se haya presentado. CI compila software, **no compara directamente resultados reales de GPU de iPhone y Android**. Falta capturar imágenes reales, validar profundidad, orientación, color y pérdida/recuperación de contexto, y medir FPS/energía/temperatura en hardware.

La prueba geométrica de la fase anterior encuentra posibles intersecciones en una muestra de piel. No valida contacto real de dedos, ausencia de clipping en toda la superficie o movimiento anatómico correcto. La escultura CC0 muscular sigue siendo provisional; un experto debe aprobar técnica y anatomía antes de publicar. **229 borradores, 0 aprobados, 0 habilitados.**

**Siguiente bloque técnico:** confirmar CI, revisar las grabaciones de los dos dispositivos, corregir cualquier diferencia de Metal/GLES3 vs Canvas y separar malla rígida estática, morfos y poses en GPU sin volver a subir el cuerpo íntegro en cada fotograma.
