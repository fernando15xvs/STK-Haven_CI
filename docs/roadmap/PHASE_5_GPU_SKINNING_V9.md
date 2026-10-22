# STK Haven — v9: skinning de 55 articulaciones en shaders GPU (piloto interno)

## Alcance y seguridad

**iOS/Android Flutter únicamente.** Sin cambios a la web, Supabase, pubspec,
rutas del catálogo, ni historial de entrenamiento. Las **229** animaciones
siguen sin aprobación ni habilitación; `0/229` publicadas.

Se conserva el motor v8 GLES2/Metal para capturas y la ruta segura Flutter
Canvas. El nuevo piloto se crea **solamente** con la opción explícita
`AnatomicalGlbPreview(experimentalGpuSkinning: true)` y solo al pausar,
mostrar una pose fija o activar la preferencia del SO de movimiento reducido.

## Arquitectura funcional implementada

1. `GlbSkinnedScene.shaderSkinSource(...)` muestrea los **8 morphs** de glTF
   en CPU y prepara los vértices locales (posición, normal, JOINTS_0,
   WEIGHTS_0, color semántico). Calcula 55 matrices de skinning a partir
   de jerarquía de rig + matrices bind inversas. Para un fotograma exporta
   hasta 25.000 triángulos y una cámara de 5 vec4 para vista/zoom/orbita.
2. `native_gpu_skinning_review.dart`: contrato tipado de **18 Float32 por
   vértice**, 55×16 float de matrices y 20 float de cámara. Valida límites,
   pesos, índices, no finitos y colores antes de pasarlos mediante
   `MethodChannel` a la plataforma; el fallback ante error conserva Canvas.
3. **Android**: PlatformView nuevo `stk_haven/anatomy_gpu_skinning` usa
   **OpenGL ES 3.0** y shader GLSL ES3. Multiplica cuatro matrices de huesos
   por sus pesos en cada vértice; calcula normal transformada, color,
   proyección y prueba de profundidad. Separa esta implementación del
   rasterizador GLES2 de v8 para no dejar de funcionar en dispositivos sin
   ES3. Incluye comprobación de 55 matrices/5 uniformes de cámara.
4. **iOS**: PlatformView distinto en `StkAnatomyGpuSkinned.swift`,
   shader Metal con `constant float4x4* bones` que efectúa skinning y
   proyección en el vertex stage con `MTKView` y `depth32Float`.
5. **Paridad:** `native_gpu_skinning_review_test.dart` reconstruye en
   Dart la multiplicación de matrices GPU y la proyección y las compara
   frente al cálculo CPU existente en los 7 clips y dos tiempos de pose.
   El CI público compila Flutter, Android y iOS.

## Limitaciones honestas de la versión 9

- **Solo se traslada el skinning de las articulaciones a GPU.**
  Las 8 deformaciones de morph aún se aplican en CPU y la CPU prepara
  las posiciones antes de enviarlas. La malla de triángulos expandida
  (~18×4 bytes por vértice) sigue copiándose por canal nativo al cambiar
  de pose: NO se ha conseguido reutilizar buffers persistentes entre
  fotogramas ni una tasa sostenida de 24/30/60 FPS.
- El piloto es **estático/pausado**: no se habilita para reproducir
  continuamente una rutina. Antes de hacerlo se requieren buffers GPU
  persistentes, morphs en shader/compute, rasterización estable en
  platform views, y gestión de errores de compilación shader.
- No confundir `flutter test` y builds CI con validación de metal/GLES
  en un teléfono real: faltan mediciones físicas de FPS, memoria, batería,
  comportamiento al cambiar de pantalla/fondo y revisión de oclusiones.
- El relieve procedural v7 continúa siendo de revisión interna, no un
  modelo muscular anatómico profesional ni biomecánicamente certificado.

## Gates posteriores

1. CI público 6/6 verde con compilación iOS/Android y tests de paridad.
2. Comprobar shaders y capturas en dispositivos compatibles ES3 y Metal.
3. Sustituir el transporte expandido por buffers indexados persistentes
   y envío incremental de matrices/8 pesos morfológicos.
4. Sólo entonces activar reproducción GPU continua (24 o más FPS) con
   mediciones térmicas y de batería; después avanzar a ejercicios.

## v9.1 — defensas de inicialización y fallback del visor

- La vista de Android confirma la preparación del shader GLES3 **después**
  de `onSurfaceCreated`, no apenas recibe el método de Flutter. De otro modo
  un evento encolado antes de la creación de EGL podría marcar hardware
  compatible como no soportado. Si la compilación del shader falla, responde
  con error, no propaga la excepción desde el hilo GL.
- Flutter impone un máximo de **5 segundos** a la respuesta nativa; ante
  error, rechazo explícito o timeout vuelve a la representación Canvas.
- Prueba Flutter adicional: cuando el piloto está desactivado, utiliza
  `GlbSkinnedPainter` y nunca crea `AndroidView` ni `UiKitView`.
- Esta medida es una defensa de QA: **no equivale a garantizar** continuidad
  de contextos EGL/Metal durante cambios de fondo ni estabilidad térmica.
