# STK Haven — reproducción de GLB animado en Flutter (candidato)

## Implementación
- Código exclusivo de apps/app_mobile, fuera del catálogo y de pubspec assets.
- anatomical_glb_runtime.dart decodifica GLB glTF 2.0, posiciones, normales, triángulos, JOINTS_0, WEIGHTS_0, materiales, inverseBindMatrices, jerarquía ósea y fotogramas.
- Reproduce los tres GLB existentes con deformación esquelética CPU, perspectiva y drawVertices en Flutter. Los materiales STK_PRIMARY/STK_SECONDARY usan AppColors para 8 temas de color × claro/oscuro.
- anatomical_glb_preview.dart admite reproducir, pausar, inspección por progreso, cámara orbital y accesibilidad para movimiento reducido; cachea geometría por fotograma de 24 fps.
- anatomical_glb_runtime_test.dart analiza poses, bucle, tamaño, 16 temas y capturas PNG reales de Flutter en 2 modos.
- Los PNG y métricas de decodificación del test runner se adjuntan al artefacto visual de CI público.

## Pendientes y límites
Esta ruta no es aceleración GPU integral: la GPU compone/rasteriza drawVertices, pero el skinning, las transformaciones y la perspectiva todavía corren en CPU Dart. No hay z-buffer verdadero y se pueden observar defectos de oclusión. Estas pruebas NO garantizan FPS ni batería de teléfonos reales.

Antes de producción, evaluar render nativo de GLB con GPU skinning/z-buffer en Android e iOS, y modelos anatómicos esculpidos profesionalmente; validar técnica con especialista, memoria, jank y batería en ambos dispositivos.

229 borradores permanecen sin aprobar ni habilitar. No tocar apps/app_web, Supabase o historial; no usar GIF.
