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

## v9.2 — buffers de malla retenidos y transporte compacto (solo QA)

- Flutter `GpuSkinningMeshCache` compara todos los floats de vértices con **la última malla que confirmó el motor nativo**. Cuando la geometría deformada por los 8 morphs no cambia, el siguiente `drawSkinned` omite `vertices` y envía `reuseMesh=true` más matrices/cámara/fondo. No se usa únicamente igualdad de tamaño o ID; una modificación de cualquier float obliga a un paquete completo.
- Los envíos Flutter quedan serializados por vista. Se descartan las solicitudes obsoletas aún no enviadas, pero una confirmación anterior se registra antes de generar el paquete siguiente. La caché se reinicia al recrear la vista. Un rechazo, timeout o ausencia de malla provoca el fallback Canvas ya existente.
- Android conserva la copia CPU para reconstrucción EGL y sube geometría a un **VBO real** de GLES3: `glBufferData` al cambiar el tamaño y `glBufferSubData` cuando cambia el contenido conservando su capacidad. Las actualizaciones de pose que reutilizan la malla no la reenvían ni resuben a GPU. Los atributos leen offsets de ese VBO, no un `FloatBuffer` de cliente.
- iOS conserva el `MTLBuffer` de vértices para actualizaciones compactas. Cuando la geometría cambia se asigna un buffer nuevo, evitando sobrescribir el anterior mientras puede estar siendo usado por Metal. Las matrices de huesos y cámara siguen enviándose en cada solicitud.
- La prueba Dart `native_gpu_skinning_review_test.dart` verifica paquete completo inicial, imposibilidad de omitir la malla antes del ACK, paquete compacto, invalidación por cambios, aislamiento frente a mutaciones del buffer original y reinicio al recrear el visor.

**Límite fundamental:** es una optimización de **poses estáticas y cámara**. Una pose animada cuyas deformaciones morfológicas cambian continúa calculando y transportando vértices completos desde CPU; el comparador también recorre todo el arreglo. No representa buffers indexados compartidos de geometría base, morphs GPU, triple buffering integral, ni reproducción continua 24/30/60 FPS. El visor sigue opt-in y pausado; **0/229** animaciones aprobadas o habilitadas. Pruebas y compilaciones CI no reemplazan perfiles físicos Android/iOS. El siguiente escalón es separar geometría inmutable y morph targets para enviar únicamente pesos y matrices, medir uso de memoria por dispositivo y verificar superficie/oclusiones antes de autorizar playback continuo.

## v9.3 — morph targets en shader y poses de transporte compacto (piloto bloqueado)

- `GlbSkinnedScene.shaderMorphSource(...,includeMesh:true)` exporta una vez la geometría base de 18 floats por vértice y **ocho correctivos de posición** (24 floats por vértice expandido). `includeMesh:false` obtiene exclusivamente 8 pesos de morph, las 55 matrices de huesos y los 20 floats de cámara; no recorre los triángulos ni aplica morphs en CPU.
- `GpuMorphPacket` verifica integridad finita y límites, separa el primer envío `vertices+morphDeltas` de las poses siguientes (`reuseMorphMesh=true`, `morphWeights`, `bones`, `camera`, `background`). La caché de Flutter es por vista, escena y colores semánticos efectivos, se confirma **después del ACK** y se invalida en recreación o al alternar modos. Las peticiones son secuenciales y mantienen timeout de 5 segundos y fallback Canvas.
- Android GLES3 mantiene un VBO de vértices expandido con *stride* 42 floats; el shader opcional cuenta con 13 atributos (5 de base, 8 correctivos) y combina cada morfología **antes** del skinning de 55 huesos. En poses compactas solo actualiza matrices, pesos y cámara. Si faltan atributos o falla la compilación del shader v9.3, rechaza la vista experimental sin deshabilitar el antiguo shader v9.2.
- iOS Metal introduce una segunda función de vértices y segundo pipeline: un `MTLBuffer` base con 42 floats por vértice queda retenido, mientras dos `float4` de pesos de morph, huesos y cámara se envían por pose. Las solicitudes sin malla inicial se rechazan; el pipeline anterior sigue disponible.
- Tests Flutter reconstruyen los vértices morfados usando los 8 deltas × pesos, los comparan con la CPU previa en **siete clips** y cuatro instantes, verifican mensajes iniciales/compactos y descarte de caché al cambiar escena/paleta.
- Acceso manual de QA: `AnatomicalGlbPreview(experimentalGpuMorphs:true)`. Default `false`. La vista se activa únicamente al pausar o fijar una pose, nunca durante reproducción continua ni en el catálogo. La versión v9.2 queda intacta como alternativa de inspección.

**Precauciones:** la primera carga incrementa la geometría de transporte de 18 a 42 floats por vértice expandido (×2,33, antes de matrices), y exige que el dispositivo soporte suficientes atributos/recursos GPU. La geometría sigue expandida por triángulo (todavía NO indexada), la capa nativa aún copia buffers de pose y el render carece de ensayo físico de memoria, batería, gestión de interrupciones y fotogramas. Solo se separaron morphs y articulaciones para envíos posteriores, **no se autoriza playback 24/30/60 FPS ni producción**. Todas las 229 demostraciones continúan **0 aprobadas / 0 habilitadas**.

**Siguientes puertas de calidad:** compilar CI público Android/iOS, inspeccionar capturas reales y restauración de contexto, medir la memoria extra del buffer base y revisar técnicamente los 7 patrones; después estudiar índices/vertex sharing, amortización del primer envío y una prueba temporal controlada en teléfono antes de considerar las 229 animaciones.

## v9.4 — malla indexada + presupuestos de memoria + sonda de poses (QA interno)

**Solo iOS/Android.** Se añade `AnatomicalGlbPreview(experimentalIndexedGpu:true)` como tercera ruta nativa experimental, inicialmente `false`. El catálogo, las 229 animaciones, `pubspec.yaml`, la web, Supabase y los historiales no cambian. `drawSkinned` (v9.2), `drawMorphed` (v9.3) y Canvas siguen disponibles como alternativas. Ninguna ruta se habilita para reproducción continua o para usuarios.

### Contrato v9.4

- Flutter reutiliza `GpuMorphPacket.fromScene` una sola vez para la carga inicial y construye `GpuIndexedMorphPacket`. Cada entrada de 42 floats representa posición/normal, cuatro articulaciones, cuatro pesos, RGBA y 8 deltas de posición. Se deduplica por **los 42 valores completos**, sin fusionar regiones que tengan distinto color, huesos o morphs. La tabla hash verifica la igualdad completa ante colisiones. Índices **Uint32** explícitos, sin suponer que caben en 16 bits.
- Transferencia inicial: `drawIndexedMorph` recibe `indexedVertices: Float32List`, `indices: Uint32List`, pesos morfológicos, 55 matrices, cámara y fondo. Las poses posteriores reciben `reuseIndexedMesh:true` y únicamente 8 pesos, matrices, cámara y fondo; la geometría solo se confirma como reutilizable **después de ACK nativo**. Si cambia la escena, paleta o la PlatformView, se exige una carga completa nueva.
- Android GLES3: `glDrawElements(GL_UNSIGNED_INT)`, VBO de 42 floats y EBO de 32 bits; cargas iniciales acotadas, datos persistentes en la vista, recuperación al recrear EGL, rechazo a referencias fuera de rango. Los parámetros por pose no suben malla.
- iOS Metal: `MTLBuffer` de vértices e índices reutilizados por vista; `drawIndexedPrimitives(indexType:.uint32)`, protección de índices y 12 MiB para ambos buffers transferidos. Los pesos, articulaciones y cámara sí se renuevan por pose.
- Presupuesto estático antes de aceptar malla: **12 MiB** (interleaved + índices). Los vértices e índices no deben contener números inválidos; los índices deben estar dentro de 0..<uniqueVertexCount, el conteo de triángulos no puede pasar 25.000. El presupuesto se aplica también en los dos puentes nativos. Este límite **no mide la memoria total de la app** ni el coste de Flutter/MethodChannel/copias de staging/Metal/EGL.
- QA de siete patrones: reconstruye de modo determinista posiciones, normales, influencias, materiales y 8 deltas; coteja muestras de cada triángulo contra el stream expandido v9.3. Produce `build/cc0_master_v7_flutter_qa/indexed_morph_memory_v94.json` con bytes y ratio por clip. Otras pruebas rechazan índices inválidos, validan reinicio de caché y muestrean **24 poses compactas** sin arrancar una reproducción real.

### Condiciones antes de v9.5

1. Verificar CI público con Android/iOS y pruebas de los siete clips; arreglar regresiones de Kotlin, Swift y Dart antes de afirmar «verde».
2. Revisar artefactos, capturas y **medir memoria física**, FPS, consumo térmico/batería en iPhone y Android; el ratio de transporte es **estimación estática**, no un resultado físico.
3. La deduplicación corre en CPU al construir la malla inicial (incluye el stream temporal v9.3). Medir ese pico antes de permitir animación continua. Considerar extracción indexada directa desde accesores glTF, límites de memoria y eliminación de buffers transitorios.
4. Implementar un reproductor con cadencia limitada y backpressure solamente después de la validación física, y manteniendo `reduceMotion`, fallback Canvas y control opt-in.

**Publicación: 229 borradores / 0 aprobados / 0 habilitados.** El PR experimental permanece sin fusionar a `main`.

## v9.5 — índice directo y sonda nativa a 12 Hz (solo pruebas)

**Objetivo:** reducir las asignaciones transitorias de la primera carga y ensayar una cadencia **limitada** en el visor interno, sin activar las 229 animaciones en el catálogo.

- `GlbSkinnedScene.shaderIndexedMorphSource` construye **directamente** un stream indexado desde los `_Primitive` glTF ya decodificados. Se evita la creación de los dos arrays de triángulos expandidos que utilizaba v9.4 (`vertices` 18 floats + `deltas` 24 floats por referencia). Se mantiene la comparación de los 42 floats de atributos entre candidatos de una misma tabla hash, con índice `Uint32`; regiones de color diferente siguen sin mezclarse. Se conservan el orden de triángulos, el límite de 25.000 triángulos y la barrera de **12 MiB para malla + índices**.
- `includeMesh:false` continúa usando el camino compacto de muestreo sin recorrer los vértices; devuelve 8 pesos, 55 matrices y cámara. Las comprobaciones nuevas comparan el nuevo camino directamente indexado contra la transferencia previa v9.3 (muestras de 42 atributos en los siete clips, estados en cuatro tiempos, cámara, pesos y huesos).
- `AnatomicalGlbPreview(experimentalIndexedGpu:true,experimentalIndexedGpuPlayback:true)` habilita **únicamente para laboratorio** el envío de fotogramas al renderer nativo con tope de **12 Hz**. `GpuProbeFrameGate` descarta ticks repetidos; cualquier giro/cambio de cámara, tema o escena puede forzar un nuevo envío. El puente MethodChannel mantiene máximo una solicitud en vuelo, y los ticks antiguos son descartados antes de enviarse. El renderer nativo sigue operando con `RENDERMODE_WHEN_DIRTY` o `MTKView.isPaused` y dibuja solo por solicitud; no se abre un bucle nativo libre.
- Al usar ese modo QA nativo ya **no se calcula previamente el Canvas CPU descartado** en cada tick. Si el usuario pausa, solicita movimiento reducido o la aplicación pierde el primer plano, se detiene el reloj; con GPU no disponible/timeout/mensaje nativo inválido, se mantiene el fallback de la versión anterior.
- `GpuProbeFrameGate` se valida contra entrada de 120 Hz durante dos segundos (solo 24 ticks permitidos), reseteo, cambios forzados de cámara y tiempos fuera del contrato.
- CI genera `build/cc0_master_v7_flutter_qa/indexed_morph_memory_v95.json` con el tamaño del stream indexado y la comparación de bytes estáticos; es diagnóstico de transferencia y **no mide RAM pico real, FPS reales, termales o energía**.

**Límites todavía vigentes:** la primera carga crea un `List<double>` temporal de vértices únicos, una tabla hash y la versión `Float32List` definitiva; sigue existiendo duplicación transitoria de **vértices únicos**, aunque ya no de *todos los triángulos expandidos*. La prueba de 12 Hz es un piloto opt-in que **no** acredita cadencia sostenida en dispositivos físicos. Sin aprobación biomecánica/anatómica y QA en iPhone y Android, el catálogo conserva **229 borradores, 0 aprobados y 0 habilitados**.

**Próximo hito v9.6:** estudiar el coste de la primera carga en dispositivos y eliminar estructuras temporales de malla si el benchmark revela picos de memoria; introducir control explícito de máximos de renders en vuelo, telemetría de ACK/drop/timing y capturas de oclusiones en equipamiento real antes de contemplar 24/30 FPS. Mantener intacta la separación privado = fuente, público = CI, sin acciones en privado ni cambios web.

## v9.6 — datos tipados con crecimiento acotado y métricas de solicitudes nativas

**Estado: experimental, NO integrado al catálogo.**

1. El constructor `GlbSkinnedScene.shaderIndexedMorphSource` mantiene el orden de 42 atributos por vértice y la deduplicación conservadora de v9.5, pero sustituye el `List<double>` temporal por `Float32List` de capacidad geométrica (inicial hasta 2048 vértices, duplicación limitada por el número de referencias). Los índices se escriben directamente en un `Uint32List` del tamaño exacto de `triangleCount*3`. Al finalizar se entrega `Float32List.sublistView`: evita **una segunda copia completa de los vértices únicos**. El backing de la última capacidad puede ser mayor que los bytes efectivamente transferidos; los crecimientos anteriores pueden convivir brevemente hasta recolección de memoria. La barrera de 12 MiB continúa sobre los bytes efectivos de vértices+índices, sin asumir que equivale a memoria real de proceso.
2. `NativeGpuSkinnedGlbReview` reemplaza el encadenamiento potencialmente ilimitado de `Future` por un *pump* con **una llamada MethodChannel en vuelo y un solo estado pendiente**. Si llega una pose más nueva mientras hay otra pendiente, sobreescribe la pendiente anterior; se vuelve a muestrear únicamente la pose más reciente una vez que vuelve el ACK. Se conserva el límite de 12 Hz, pausa y opciones de movimiento reducido.
3. Se añade `GpuQaMetrics` / `GpuQaMetricsSnapshot` para contar solicitudes recibidas, envíos, confirmaciones, poses reemplazadas, ticks bloqueados por la cadencia, errores, máximos de envíos simultáneos, bytes enviados y latencia hasta el ACK. La vista experimental admite `onMetrics`. `AnatomicalGlbPreview(experimentalGpuTelemetry:true,experimentalIndexedGpu:true)` muestra un texto QA opcional, **desactivado de forma predeterminada**.
4. Al recrear PlatformView o cambiar el tipo de shader, un número de época invalida confirmaciones tardías anteriores para que **no se reconozca una malla ajena** ni se active por error la caché nueva. Los errores de la vista vigente conservan la recuperación en Canvas.
5. Las pruebas unitarias comprueban los contadores y errores, estabilidad de los 7 clips frente al indexado, capacidad y longitud exacta de los búferes tipados, y generan `build/cc0_master_v7_flutter_qa/indexed_morph_memory_v96.json` con tamaño de los buffers de Dart por clip.

**Interpretación de métricas:** el tiempo `lastAckMs` representa preparación+transferencia hasta respuesta del canal nativo; en Android la respuesta puede llegar **antes** de que el frame se haya dibujado. No es GPU frame time, no demuestra FPS en pantalla, jank, RAM total ni energía. Tampoco se envían los datos a una analítica externa. El QA real del iPhone/Android y aprobación anatómica/biomecánica de los 229 ejercicios siguen pendientes. No activar estos flags en entrenamiento o web ni fusionar el PR experimental a `main` hasta las validaciones exigidas.

**Próximo bloque tentativo v9.7:** ensayos en teléfonos físicos con memoria total, tiempo de presentación efectivo, artefactos visuales (oclusiones, contactos), restauración del contexto y batería; ajustar topes según evidencia y preparar una herramienta para seleccionar movimientos especializados con rig de 55 articulaciones. **229 borradores / 0 aprobados / 0 habilitados.**

## v9.7 — QA físico preparado (sin resultados físicos aún)

- El visor móvil de laboratorio incorpora `GlbDeviceQaSession`: escucha `SchedulerBinding.addTimingsCallback` solo con `experimentalGpuTelemetry:true` y `experimentalIndexedGpu:true`, conserva a lo sumo 240 `FrameTiming`, observa RSS del proceso en iOS/Android y permite copiar un JSON offline con métricas y restricciones. Son tiempos de Flutter y memoria RSS muestreada, **no** tiempos aislados Metal/GLES, FPS de pantalla, batería ni evaluación térmica.
- Para `ex_bench_press`, `ex_barbell_row` y `ex_squat` se crean planes de QA que describen contacto con barras, banco, suelo, articulaciones y músculos primarios/secundarios. `AnatomicalGlbStaging.themeMasterRegions` añade un resaltado secundario de menor intensidad, respetando los temas y los ocho acentos. En el visor puede mostrarse el checklist pasando `reviewPilotId`; ningún check equivale a aprobación.
- Nuevas pruebas validan histogramas acotados, reportes nunca aprobados, los tres ID históricos y la existencia de todas las regiones. El checklist íntegro y procedimiento para teléfonos físicos están en `docs/roadmap/PHASE_5_MOBILE_DEVICE_QA_V97.md`.
- **No se han ejecutado aún perfiles, capturas o certificados de biomecánica sobre un teléfono real.** El CC0 procedural v7 continúa siendo un master provisional, no los tres movimientos completos con equipo. No se activan Lottie ni medios GLB de los 229 ejercicios; web y Supabase intactos.

## v9.8 — verificación concreta de tres GLB de ejercicio (sin activar el catálogo)

Se ha añadido una revisión más estricta de **press banca, remo y sentadilla** sobre los GLB móviles de 53 huesos que ya tienen barra, discos y banco (solo press). `retarget_cc0_glb.py` añade dos collares y dos guías de agarre con tapas a los proxies sin cambiar pesos del cuerpo, licencia, materiales o sus 41 poses. `pilot_motion_quality_v98.py` mide contactos desde los canales glTF interpolados a 30 muestras/s en 121 instantes; guarda métricas y bloqueos profesionales en `build/cc0_53bone_retarget/three_pilot_motion_quality_v98.json`. Las pruebas se ejecutan mediante los pasos de CI públicos existentes, sin tocar los assets de producción.

**Precaución esencial:** estos tres pilotos continúan con el rig de **53 huesos**, separado del master procedural de 55 controles y ocho morphs; el QA matemático no confirma escultura anatómica profesional, agarre real de dedos, ausencia de colisiones ni técnica correcta. No se realizaron pruebas de dispositivos físicos ni se aprobaron ejercicios. Documento técnico completo: `docs/roadmap/PHASE_5_PILOT_CONTACT_V98.md`. Siguen `229/229` borradores y `0/229` aprobados/habilitados.

## v9.9 — ejercicios de barra sobre la geometría master de 55 articulaciones (offline QA)

Se añade `build_master_exercise_pilots_v99.py`, que convierte los tres clips de ejercicio previamente retargeteados (53 huesos, con barra y banco para el press) en tres **derivados** del master anatómico CC0 de v7 (55 huesos, 12 grupos de superficies, ocho morphs). Los canales de ejercicio se trasladan por nombre conservando el rig y morphs originales del master; las ocho deformaciones se remuestrean según ángulos locales. Las dos articulaciones nuevas de la cintura escapular se mantienen **neutrales** hasta recalcular agarres IK de forma específica, por lo que no se atribuye una movilidad escapular que aún no existe.

`test_cc0_interpolated_motion.py` comprueba 121 muestras por ejercicio entre el original 53 y el 55 derivado, con contacto muñeca/barra y pies, y que ninguno de los tres modelos sea aprobado o habilitado. Los GLB generados se quedan en los artefactos de revisión del CI público, fuera del catálogo y fuera del `pubspec.yaml`. **Este generador no convierte aún la escultura procedural en personaje anatómico profesional ni activa la visualización completa del equipo junto a la piel en Flutter**. Requisitos restantes y rutas de salida: `docs/roadmap/PHASE_5_EXERCISE_MASTER_55_V99.md`.

## v9.10 — corrección IK escapular de 3 pilotos

El nuevo `solve_exercise_scapula_v910.py` toma los tres derivados v9.9 de 55 huesos y propone un movimiento leve de los dos controles de cintura escapular **con re-solución del brazo** hacia la posición de muñeca original que mantenía contacto con la barra. Cuando una pose no alcanza el objetivo, reduce el giro o descarta ese cambio. Recalcula ocho pesos morfológicos con las rotaciones corregidas, sin cambiar los valores de skin, las regiones ni la geometría del equipamiento. Los test interpolan 121 instantes por ejercicio y comprueban errores máximos de muñeca/barra y de planta de pie; los resultados son GLB internos y un JSON dentro de los artefactos públicos.

El material sigue sin garantías clínicas y no contempla colisión de dedos, escultura muscular independiente, físico de cargas ni composición de equipamiento rígido en el motor nativo. **0/229 aprobados, 0/229 habilitados**. Detalle: `docs/roadmap/PHASE_5_SCAPULAR_CONTACT_V910.md`.
