# STK Haven — master GLB v6: continuidad de malla articular

**Alcance:** solo revisión interna de Flutter móvil iOS/Android. No se habilitan los 229 borradores de animación ni se modifica la web, Supabase, la biblioteca o el historial de entrenamiento.

## Implementación

- Entrada: archivo GLB **v5.2** de 55 articulaciones, 7 patrones, 8 *shape keys* correctivos y 12 grupos de malla, con `approved=false` y `enabled=false`.
- El script `tool/anatomical_3d/build_master_surface_v6.py` crea un grafo de aristas cortas trianguladas y une vértices con posición coincidente de costuras UV.
- Suaviza de forma leve los **desplazamientos de los correctivos existentes** (hombro, codo, cadera, rodilla × izquierda/derecha), ponderando proximidad y mezcla de pesos óseos. No mueve posiciones base, no elimina triángulos y no cambia rig, animación, índices, normales ni pesos de piel.
- Limita cambios adicionales a **1,5 mm por vértice**, sin mezclar lados del cuerpo; solo 2 pasadas de suavizado. Sigue siendo una corrección visual experimental, no un modelo musculoesquelético anatómicamente certificado.
- Reescribe los 8 buffers morfológicos existentes, evita duplicaciones y rechaza salidas de más de 850 KiB, con gradiente de aristas peor de lo permitido o con metadatos inesperados. Las pruebas del GLB evalúan preservación y límites.

## Construcción offline en apps/app_mobile

```bash
python3 tool/anatomical_3d/build_master_surface_v6.py \
  --input build/cc0_master_contacts_v5/stk_master_v5_contact_review.glb \
  --output build/cc0_master_surface_v6
python3 -m unittest discover -s tool/anatomical_3d -p 'test_master_surface_v6.py'
```

Genera `stk_master_v6_joint_surface_review.glb` y `joint_surface_v6_report.json`. El GLB v6 no está incluido en los assets de Flutter, su renderer GPU aún no existe y faltan ejecución CI pública, inspección visual, rendimiento de dispositivos y revisión anatómica por especialistas. **0/229 animaciones aprobadas; 0/229 habilitadas.**


## v6.1 — render estático con capas de profundidad (QA móvil, 21 oct 2026)

- `GlbSkinnedScene.frame(depthSlices: 1..8)` permite separar cada primitiva ya proyectada por profundidad media **del triángulo**, en lugar de ordenar una región muscular entera por su única profundidad promedio. Todas las capas conservan la misma lista de vértices proyectados y colores: el skinning e IK no se recalculan por capa, los índices y recuento de triángulos siguen intactos.
- `AnatomicalGlbPreview` habilita **6 capas solo al pausar, mostrar un fotograma fijo o con movimiento reducido**. Mientras el personaje está animándose usa `depthSlices:1`: evita multiplicar llamadas de dibujo por cada actualización. El modo visual es experimental y no es un renderizador GPU glTF ni un búfer Z por píxel.
- Validaciones nuevas en `test/features/exercises/glb_depth_slicer_test.dart`: profundidad, orden de capas, cobertura de índices, buffers compartidos y entradas inválidas. La prueba v6 sobre GLB real comprueba los siete patrones y produce capturas claras/oscuras con seis capas.
- El catálogo de **229 ejercicios continúa sin medios anatómicos aprobados**. La versión 6.1 no añade `pubspec.yaml`, no crea pantallas de producción, no modifica `apps/app_web`, Supabase, Coach Pro ni historial. Antes de activar un motor definitivo deben medirse FPS, memoria, batería, oclusión real y calidad muscular en dispositivos físicos.

## v6.2 — resaltado muscular basado en los ocho acentos

- `AnatomicalGlbStaging.masterRegionNames` restringe los materiales a **11 regiones documentadas** del CC0 master, sin inventar mapas anatómicos ni aceptar nombres desconocidos.
- `AnatomicalGlbStaging.themeMasterRegions()` asigna colores atenuados a las regiones no seleccionadas y el acento temático a las seleccionadas, conservando `STK_BODY` y la paleta Flutter. `AnatomicalGlbPreview(highlightRegions: ...)` es un control **opt-in** de revisión offline; el modo animado conserva el camino rápido.
- La prueba `master_muscle_palette_test.dart` recorre las **8 variantes AppAccent × 2 brillos** y verifica 11 nombres, identidad del color de selección, separación visual entre regiones y rechazo de etiquetas desconocidas. Esto no significa que 229 movimientos tengan clasificación de músculo activo o modelo final.
- En el CI del repositorio público se ejecutan automáticamente estos tests Flutter por el paso ya existente `flutter test`. La anotación anatómica experta, render GPU, evaluación térmica y rendimiento en teléfonos físicos siguen pendientes.
