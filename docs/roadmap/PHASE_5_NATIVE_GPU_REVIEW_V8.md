# STK Haven — fase GPU nativa v8 (candidato **experimental**)

## Estado y alcance

Desarrollo exclusivo de la aplicación Flutter móvil (Android e iOS).
**No se habilita ninguna animación para el catálogo de 229 ejercicios.**
No cambian pubspec, la web, Supabase, usuarios, rutinas ni historial.
Los 229 borradores permanecen **0 aprobados / 0 habilitados**.

Esta fase introduce un **rasterizador GPU real con prueba de profundidad**, sin
afirmar que exista todavía un *skinning* acelerado. Es un paso de integración
nativa y revisión de poses **estáticas**, no el motor 3D definitivo.

## Arquitectura actual

1. **CPU Flutter**: `GlbSkinnedScene.frame(... poseNormals:true)` resuelve las
   55 articulaciones, siete clips, 8 morphs y colores de 11 regiones.
   Su resultado tiene vértices 2D y profundidad de cámara por vértice.
2. **Contrato entre plataformas**: `native_gpu_glb_review.dart` expande
   triángulos a vértices intercalados de 7 floats
   (`clipX,clipY,depth,r,g,b,a`). Valida geometría y presupuestos:
   como máximo 25.000 triángulos, todos los números finitos.
   `MethodChannel(stk_haven/anatomy_gpu_static/{viewId})` lleva el
   `Float32List` solo al solicitar una pose estática.
3. **Android (API >= 23)**: vista `GLSurfaceView`, GLES 2.0, shaders
   de color por vértice, prueba de profundidad real (`GL_DEPTH_TEST`),
   depthbuffer de 16 bits. Se registra en el MainActivity ya existente.
4. **iOS (15+)**: `MTKView` con render pipeline de Metal, shaders MSL
   y `depth32Float` con comparación `less`. Registro desde AppDelegate y
   archivo Swift incluido en el target Runner de Xcode.
5. **Fallback**: si el motor nativo falla o el hardware no es compatible,
   `NativeGpuGlbReview` vuelve al `GlbSkinnedPainter` de Flutter.
   `AnatomicalGlbPreview(experimentalNativeGpuStatic:true)` permite
   evaluarlo solamente cuando el movimiento está pausado o fijado.
   El valor por defecto es **false**.
6. **Pruebas**: validación Dart de los siete GLB y del wire-format,
   comprobación del análisis Flutter y compilación Android/iOS en el
   **repositorio público de CI**, nunca en el privado.

## Qué mejora y qué NO

- **Sí**: oclusión GPU con Z-buffer, dibujo nativo interpolado,
  integración Android/iOS y reversión segura.
- **Todavía NO**: cálculos de articulaciones y morphs en shader,
  *vertex skinning* GPU, iluminación físicamente basada, tejidos y
  músculos esculpidos individualmente, anatomía revisada por expertos,
  reproducción animada de 229 ejercicios y mediciones reales de FPS/batería.
- Transferir triángulos por MethodChannel tiene costo de memoria y copia.
  El modo **estático** evita hacerlo 24 veces/segundo; antes de producción
  el transporte debe cambiar a buffers persistentes/compartidos y shaders
  de skinning GPU con matrices de huesos + pesos en el dispositivo.
- Vistas nativas Flutter (especialmente Android SurfaceView) tienen
  compromisos de composición, accesibilidad y desplazamiento. No se
  activa en pantallas de entrenamiento ni en listados.

## Criterios para fase 8.1

Compilación pública verde en iOS/Android, revisión visual en teléfonos,
comparación de profundidad GPU vs CPU, pruebas de abandono/reanudación
de vista y métricas **físicas** de fotogramas, memoria y batería. Sin
aprobar estos gates, debe continuar la ruta Flutter Canvas.

Referencias: guías oficiales Flutter de Android/iOS Platform Views y
Apple MetalKit MTKView.
