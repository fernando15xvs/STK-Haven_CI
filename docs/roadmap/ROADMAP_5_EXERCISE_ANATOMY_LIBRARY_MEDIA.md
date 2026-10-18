# STK Haven — Roadmap 5: biblioteca anatómica, ejercicios guiados y animaciones

**Fecha:** 2026-10-17 · **Estado:** Fases 1 y 2 (informes y auditoría no destructiva) integradas parcialmente; Fase 3: **229 presets (49 originales + 180 nuevos)**, anatomía/búsqueda y filtros avanzados de patrón, nivel, tipo y peso corporal. Restan curaduría biomecánica experta y animaciones Lottie originales o licenciadas; la Fase 4 ya dispone de guías, vista previa y contrato de medios con fallback seguro, y el QA físico permanece al final.
**Documentos:** [Taxonomía detallada (obligatoria)](EXERCISE_MUSCLE_TAXONOMY_V1.md) · [Progreso 2.0](PROGRESS_2_UNIFICATION_AND_MUSCLE_BALANCE.md).

> **Regla de los repositorios:** `fernando15xvs/STK-Haven` = **fuente de verdad**, sin workflows/GitHub Actions. `fernando15xvs/STK-Haven_CI` = **espejo** para Actions, pruebas y artefactos de iOS/Android. Mantener igualdad de código/datos/documentos salvo workflow y metadatos exclusivos del espejo. No iniciar acciones en original.
>
> **Checklist real:** marcar `[x]` solo cuando la tarea haya sido implementada, probada o verificada según su redacción. Nunca confundir «documentado» con «entregado». Guardar evidencia en la bitácora de cada fase (PR, commit, run y resultado).

## 0. Auditoría inicial de código y capturas

- [x] Auditoría inicial: había **49 ejercicios de catálogo** y **11 etiquetas principales**. En Fase 3 se añaden 180 ejercicios con nuevos IDs (total **229**); los 49 originales y sus etiquetas se conservan sin cambios.
- [x] Revisados `Exercise` y `HiveExercise`: `muscleGroup` y `secondaryMuscles` son texto libre; existe `media` como string, pero no constituye una biblioteca multimedia auditada.
- [x] Revisados `ProgramMuscleFrequencyPlanner` y `ProgramVolumePlanner`: agregan por nombre textual; actualmente la frecuencia puede separar «Hombro» de «Hombros», y el volumen no tiene un identificador anatómico común.
- [x] Revisado `CustomExerciseService`: permite escribir músculos, por lo que pueden aparecer combinaciones como «glúteos y isquios».
- [x] Redactada taxonomía anatómica de hombro, pecho, espalda, brazos, glúteos, muslos, pierna inferior, abdomen y serrato anterior en documento separado.
- [ ] Inventario de **todos** los nombres encontrados en las rutinas preinstaladas, datos históricos/Hive, favoritos y programas Coach Pro, con fixtures anonimizados.
- [ ] Revisar rigurosamente aportes anatómicos de cada ejercicio antes de publicar el catálogo (especialmente énfasis vs trabajo real).

## 1. Catálogo muscular canónico y estable — prioridad máxima

- [x] Crear `MuscleTaxonomyV1` con IDs estables, alias en español/inglés, parentesco, tipo (`group/muscle/region`), nombre técnico y traducciones.
- [x] Cubrir **pecho**: porción clavicular (superior), esternocostal (medio) y fascículos inferiores/abdominales (inferior) del pectoral mayor; pectoral menor; serrato anterior con rol de cintura escapular.
- [x] Cubrir **hombro**: deltoide anterior, lateral y posterior individualizados; supraespinoso, infraespinoso, redondo menor, subescapular, redondo mayor.
- [x] Cubrir **espalda**: dorsal ancho, romboides mayor/menor, trapecio superior/medio/inferior, elevador de la escápula, erectores espinales, multífidos, cuadrado lumbar.
- [x] Cubrir **brazos**: bíceps cabeza larga/corta, braquial, braquiorradial; tríceps cabeza larga/lateral/medial; flexores y extensores/pronadores del antebrazo.
- [x] Cubrir **glúteos y cadera**: glúteo mayor/medio/menor, tensor de la fascia lata, flexores de cadera, aductores mayor/largo/corto, grácil, pectíneo y rotadores profundos.
- [x] Cubrir **cuádriceps**: recto femoral, vasto lateral, medial e intermedio.
- [x] Cubrir **isquiotibiales**: bíceps femoral cabeza larga/corta, semitendinoso, semimembranoso; diferenciar funciones de cada cabeza.
- [x] Cubrir **pierna inferior**: gastrocnemio cabeza medial/lateral, sóleo, tibial anterior y otros grupos de tobillo/pie definidos en taxonomía.
- [x] Cubrir **abdomen completo**: recto abdominal (énfasis superior/inferior), oblicuo externo, oblicuo interno, transverso abdominal, musculatura profunda del tronco, diafragma y suelo pélvico como función, sin inventar series de hipertrofia.
- [x] Añadir navegación jerárquica móvil (por ejemplo: `Piernas > Isquiotibiales > Semitendinoso`) con **categorías generales no contables**, selección de ID y filtrado no destructivo.
- [x] Pruebas de unicidad de IDs, alias, tildes, mayúsculas, plurales, sinónimos y pertenencia a categorías; manejo de regiones funcionales con evidencia insuficiente.

**Criterio no negociable:** «pecho superior/medio/inferior», cabeza del bíceps y «abdomen superior/inferior» no significan aislamiento anatómico garantizado. Registrar músculo y, cuando corresponda, **énfasis** separado. Una serie no cuenta tres veces al agregar al pecho completo.

## 2. Migración segura y corrección de estadísticas/planes

- [x] Implementar resolutor puro `MuscleTaxonomyV1.resolveLegacy` (versión de taxonomía) con resultado `exact`, `byExerciseContext`, `ambiguous` o `unknown`.
- [x] Mantener estables `exercise.id`, IDs de rutinas, entrenamiento, series, PRs, favoritos, referencias de Coach Pro y backups **durante esta proyección en memoria**. No se reescribe `WorkoutExercise.muscleGroupSnapshot` ni se realiza una migración persistente.
- [x] En la proyección de informes, «Hombro/Hombros» queda como categoría general, «Hombro anterior» conserva ID de región sin multiplicar series; dorsal se distingue anatómicamente de espalda y «Piernas» no se convierte en cuádriceps.
- [ ] Dividir etiquetas combinadas («tríceps y hombro», «glúteos y isquios») en participaciones **solo cuando el ejercicio permita determinar los roles**; caso ambiguo queda como «por clasificar» sin datos inventados.
- [ ] Adoptar IDs anatómicos en biblioteca, filtros, `MuscleBalanceCalculator`, `ProgramMuscleFrequencyPlanner`, `ProgramVolumePlanner` y Progreso 2.0. Agregar con `distinct setId/sessionId` sin doble conteo.
- [ ] Distinguir trabajo directo, secundario estimado, énfasis regional y estabilizador; indicar método y confianza; no mostrar un porcentaje de crecimiento muscular a partir de `kg·rep`.
- [ ] En Plan de entrenamiento, usar etiquetas coherentes: **sesiones/semana** vs **series efectivas/semana** vs **volumen externo kg·reps**. Resumen por categorías, detalle técnico expandible.
- [ ] Corregir `Nuevo plan` flotante para no ocultar «Volumen de esta semana» en pantallas pequeñas; probar SafeArea y último elemento visible.
- [ ] Probar migración **idempotente**, rollback de clasificación, legado desconocido, historial creado antes/después del catálogo, copias de seguridad y preferencias de entrenamiento.
- [ ] Verificar que un registro antiguo con nombre ambiguo permanece visible y no cambia artificialmente sus estadísticas ni su progreso.

## 3. Biblioteca base amplia y utilizable sin crear ejercicios

**Meta orientativa:** pasar de **49** a **180–250 ejercicios curados**, ampliables por entregas. Priorizar cobertura y precisión; no inflar el número duplicando nombres idénticos.

- [ ] Diseñar `ExerciseDefinitionV2` (IDs inmutables) con alias, equipo, patrón, dificultad, principal/secundarios/énfasis/estabilizadores, lateralidad, instrucciones, errores comunes, contraindicaciones generales prudentemente redactadas y media manifest.
- [x] Cubrir variantes relevantes de pecho: barra/mancuernas/máquina, plano/inclinado/declinado, aperturas y poleas, identificando porciones enfatizadas.
- [x] Cubrir espalda: dominadas, jalones, remos por agarre/soporte, trapecio, romboides, retractores escapulares, extensores y estabilización lumbar.
- [x] Cubrir hombro: presses, elevaciones laterales, frontales, deltoide posterior, rotaciones interna/externa y control escapular.
- [x] Cubrir bíceps, braquial, tríceps y antebrazo; variantes de cable, polea, barra, mancuernas y máquinas.
- [x] Cubrir piernas: cuádriceps, isquiosurales, glúteo mayor/medio/menor, aductores, abductores, pantorrillas, tibial anterior, bisagras y patrones de sentadilla.
- [ ] Cubrir abdomen/core: crunch, flexión de tronco, elevaciones de pelvis/piernas según técnica, oblicuos, rotación/anti-rotación, anti-extensión, flexión lateral, control del serrato anterior, respiración/estabilidad sin atribución muscular exagerada.
- [x] Filtros combinados por músculo específico/énfasis, región general, equipo, unilateral/bilateral, compuesto/aislado, patrón, dificultad y sin equipamiento **para las 180 definiciones con metadatos**. Los ejercicios sin clasificación avanzada continúan visibles en la biblioteca general y se excluyen únicamente si el filtro requiere datos que no poseen.
- [x] Búsqueda sin tildes, por sinónimos, nombres técnicos y comunes (`isquios`, `isquiotibiales`, `deltoide posterior`, `romboides`, `oblicuos`, `serrato`).
- [ ] Auditoría de IDs duplicados, alias conflictivos, instrucciones vacías, variantes realmente distintas, clasificación muscular y disponibilidad de media para cada preset.
- [ ] Pruebas de rendimiento con 250+ ejercicios, planes grandes, modo ahorro, filtrado combinado y uso sin conexión.

## 4. Animaciones y fichas técnicas auténticas

**Objetivo:** al seleccionar un ejercicio —desde biblioteca, rutina y sesión— mostrar una demostración **que se mueva**, con nota técnica clara, sin obligar a buscar fuera de la app.

- [ ] Tecnología acordada: **Lottie JSON vectorial como opción principal**; PNG/WebP para poster sin movimiento y solo evaluar vídeo corto optimizado cuando Lottie no pueda representar la técnica con exactitud. **No usar GIFs.** Medir peso, CPU, batería y soporte iOS/Android.
- [ ] Definir manifiesto `exerciseMedia` con `exerciseId`, licencia verificable, atribución, fuente, versión, vista anterior/lateral, poster offline, duración y peso.
- [ ] Obtener o producir demostraciones **originales o licenciadas con derechos compatibles**, documentando permisos de distribución. La captura de referencia **no concede permiso** para copiar su animación.
- [ ] Primera tanda de **30–40 ejercicios comunes** con animación validada (press banca, jalón, remo, elevaciones, sentadilla, RDL, curl femoral, hip thrust, crunch, etc.).
- [x] Evitar recursos equivocados mediante registro por ID y fallback honesto a instrucciones cuando falta Lottie. La ampliación de animaciones reales continúa pendiente.
- [ ] En detalle: loop automático **silencioso**, pausar/reanudar, velocidad razonable, vistas disponibles, zoom si tiene sentido, descripción breve por pasos, colocación, rango, respiración opcional y errores frecuentes.
- [ ] Mostrar músculo principal, secundarios, énfasis y estabilizadores con nombre técnico/coloquial; explicar por qué el movimiento se etiqueta así.
- [ ] Garantizar `reducir animaciones`, modo ahorro y reproducción sin conexión para recursos empaquetados; cargas diferidas, caché acotada y textos accesibles.
- [ ] Acceso a la ficha durante selección **antes** de añadir el ejercicio, así como durante el entrenamiento sin perder el progreso.
- [ ] Pruebas 320 px, texto grande, VoiceOver/TalkBack, app en segundo plano, modo avión, fallos de decodificación y recursos ausentes.

## 5. Ejercicios personalizados guiados y sin duplicados

- [ ] Sustituir músculos libres por selectores de catálogo de primer nivel + subgrupo, con alias y búsqueda; permitir nombres libres del ejercicio pero ID anatómico validado.
- [ ] Detectar nombres/alias parecidos a presets y ofrecer el ejercicio existente en vez de crear duplicados innecesarios.
- [ ] Elegir unilateral/bilateral **explícitamente**, no deducirlo solo del texto del nombre; conservar configuración de calentamiento bilateral y series efectivas unilaterales.
- [ ] Permitir músculos principal y secundarios diferenciados, y énfasis opcional; no aceptar «Tríceps y hombro» como un músculo.
- [ ] Equipo, patrón, instrucciones, errores frecuentes, enlace o recurso propio opcional con autorización; privacidad local y media ausente seguros.
- [ ] Compatibilidad con ejercicios personalizados ya creados, notas personales, pesos, descansos y backups.

## 6. Integración y recepción visual

- [ ] `Entrenar > elegir ejercicio`: miniatura/preview (si hay), nombre, equipo, músculo específico, etiquetas; detalle técnico previo a elegir.
- [ ] `Plan de entrenamiento`: resumen por grupos generales *únicos* y detalle anatómico expandible; frecuencia directa/secundaria sin «Hombros» y «Hombro anterior» como filas redundantes del mismo nivel.
- [ ] `Progreso > Músculos`: balance muscular consistente con el mismo catálogo, sin repetir e1RM/PR de Ejercicios.
- [ ] `Progreso > Ejercicios`: navegación a ficha técnica animada sin crear un segundo tablero estadístico.
- [ ] Sin conflictos con Coach Pro (planes, ejercicios, asignaciones y revisiones), Supabase, modo invitado o respaldo/restauración.
- [ ] Validación por revisión visual comparando los casos reportados: `Hombro/Hombros/Hombro anterior`, `Piernas/Cuádriceps`, `Dorsal/Espalda`, `Glúteos e isquios` y toda la musculatura abdominal.

## 7. CI, distribución y control de calidad

- [ ] Tests Core: ontología, alias, clasificador y migración no destructiva, grupos ambiguos, validación de IDs, agregación sin doble conteo.
- [ ] Tests móviles: biblioteca/selector/ficha, loop + modo ahorro/reducir movimiento, plan semanal sin duplicados, tarjetas de 320 px, accesibilidad y estados vacíos.
- [ ] Tests de regresión: progreso histórico, rutinas/programas, pesos kg/lb, descansos, unilateral, favoritos, Coach Pro, backups y rendimiento.
- [ ] Flutter analyze y todas las comprobaciones del flujo CI **solo en STK-Haven_CI**; evitar lanzar Actions en STK-Haven original.
- [ ] Compilar iOS profile/release sin firma y Android debug/profile/release/AAB/split ABI en el espejo. Medir peso de media/IPA/APK y consumo de recursos.
- [ ] Exigir 6/6 (o cantidad real del workflow vigente) en verde en PR del espejo, luego integrar original y sincronizar espejo sin borrar código nuevo.
- [ ] Verificar paridad SHA de blobs entre repos salvo workflows/metadatos del CI.
- [ ] Pruebas **físicas** en iPhone y Android antes de anunciar que funciona en dispositivos. La firma gratuita de Sideloadly puede seguir limitando el widget iOS y es un problema separado.

## Criterios finales de aceptación

- El usuario puede localizar una variante específica de deltoide anterior/lateral/posterior, glúteo mayor/medio/menor, isquiosurales, romboides, dorsal, pectoral clavicular/esternocostal/inferior, oblicuo externo/interno, recto abdominal, transverso y serrato anterior sin inventar ejercicios.
- No existen filas musculares duplicadas por singular/plural, tildes, compuestos o alias; se conservan regiones correctamente diferenciadas.
- No se multiplica el conteo de series al mostrar categorías padre e hijos ni se presenta `kg·rep` como porcentaje de crecimiento muscular.
- Las animaciones representan **ese ejercicio específico**, muestran ejecución y precauciones, respetan accesibilidad/licencias, y tienen fallback si faltan.
- No hay pérdida ni modificación silenciosa de historial, rutinas, ejercicios personalizados, Coach Pro o backups.
- Catálogo disponible offline, selección comprensible y navegación sin bloqueo por el botón flotante.
- CI aprobado en espejo y recepción manual documentada antes de declarar el módulo terminado.

## Bitácora de ejecución

| Fase | Estado | Evidencia |
|---|---|---|
| 0. Auditoría preliminar y documentos | **Parcial** | Inventario de 49 presets/11 grupos principales; herramienta local de auditoría lista, sin datos reales del teléfono |
| 1. Taxonomía anatómica | **Núcleo + navegación móvil implementados** | 98 nodos, pruebas Core y selector jerárquico; revisión anatómica de cada ejercicio y prueba física pendientes |
| 2. Migración/estadísticas/planes | **Parcial: auditoría real disponible en UI** | Reportes canónicos y pantalla local leyendo catálogo, rutinas e historial; no se ejecutó migración persistente ni se creó/validó copia del teléfono |
| 3. Biblioteca ampliada | **Base y filtros avanzados integrados; cierre parcial** | 229 presets; 180 con patrón/nivel/mecánica, 13 categorías; falta revisión biomecánica externa, manifest multimedia y QA física |
| 4. Animaciones y ficha | **Parcial: guías y reproductor preparados** | 43 guías detalladas, vista previa de selección y componente de medios; 0 Lotties aprobados/distribuidos hasta verificar derechos y técnica |
| 5. Editor personalizado guiado | **Pendiente** | No modificado |
| 6. Integración visual | **Parcial** | Plan y Progreso aclaran unidades; Revisión anatómica accesible desde Balance muscular. Ficha técnica y atribuciones específicas pendientes |
| 7. CI y pruebas físicas | **Parcial** | PR #35 con pruebas automáticas y layout 320 px; pruebas físicas/manuales pendientes |

**Próximo paso recomendado:** inventario anonimizado de datos reales, respaldo comprobado y diseño de migración reversible; revisar roles biomecánicos de cada ejercicio antes de poblar cientos de ejercicios o sus medios.

### Entrega 1 — Catálogo anatómico base y compatibilidad (17–18 oct 2026)

- [x] 98 nodos con IDs estables: 32 categorías, 46 músculos, 20 regiones, 390 claves de búsqueda/alias sin colisiones, incluido serrato anterior y complejo abdominal.
- [x] 49 ejercicios preinstalados validados frente a la resolución conservadora de etiquetas primarias y secundarias.
- [x] Nombres ambiguos como «Hombros», «Espalda», «Piernas» y etiquetas combinadas permanecen sin asignación muscular específica hasta revisión.
- [x] Pruebas del paquete Core, análisis Flutter, móvil, iOS, Android, Supabase/Edge en [CI #39095901308](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39095901308), **6/6 trabajos exitosos**. [PR #32](https://github.com/fernando15xvs/STK-Haven_CI/pull/32) fusionado.
- [x] `STK-Haven` original conserva su función de fuente de verdad y carece de workflows; cambios replicados en el espejo.
- [ ] Integración en Plan/Progreso, migración con respaldo y pruebas físicas; la selección visual móvil básica está disponible. No se ha alterado el historial existente ni generado una copia de seguridad del teléfono.

**Siguiente tarea:** inventariar etiquetas y respaldos reales, mostrar categorías «por revisar» e información técnica en la interfaz, corregir espacios del Plan y completar pruebas de reversibilidad y equipos físicos. Los cálculos ya utilizan una proyección canónica sin persistir cambios.

### Entrega 2 — Selector jerárquico móvil (18 oct 2026)

- [x] Navegación de tres raíces (Tren superior, Tren inferior y Core) hacia grupos, músculos y regiones con ID estable; distingue categoría y énfasis regional.
- [x] Desde Biblioteca y selección de ejercicios, explorar la jerarquía por niveles, seleccionar un músculo, ver el filtro activo y limpiarlo.
- [x] Filtrado de lectura conservador por etiquetas primarias/secundarias; nombres generales o combinados no se convierten en una estructura anatómica arbitraria.
- [x] Pruebas Core: rutas y cross-listing de serrato, exclusión de ambiguos, filtros combinados y conservación inmutable de etiquetas.
- [x] Pruebas móviles: navegación y selección modal por identificador, separación de deltoide anterior/lateral/posterior.
- [x] CI en espejo: [run #365, 6/6](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39143311681), [PR #33](https://github.com/fernando15xvs/STK-Haven_CI/pull/33), integrado y sincronizado con repositorio original.
- [ ] Revisión biomecánica por ejercicio, pruebas físicas, integración Plan/Progreso y migración de datos; tareas posteriores a la base de Fase 1.

**Límite de esta entrega:** navegar toda la anatomía no implica que los 49 presets históricos estén clasificados a nivel de fascículos. El filtro no inventa objetivos de un movimiento y puede mostrar vacío para porciones que aún no tienen ejercicios revisados. Esto se resolverá en fases 2–3.

### Entrega 3 — Fase 2 / proyección de informes sin escrituras (18 oct 2026)

- [x] `CanonicalMuscleProjector`: agrupa etiquetas históricas mediante `MuscleTaxonomyV1` con IDs de categoría para informes, conserva la etiqueta exacta y el ID anatómico original cuando se conoce; expresiones ambiguas o desconocidas quedan en bucket `legacy:` no atribuido.
- [x] `ProgramMuscleFrequencyPlanner`: una categoría única por sesión programada, trabajo principal separado de secundario. «Hombro»/«Hombros»/«Deltoides lateral» se agregan sin afirmar que una porción se aisló.
- [x] `ProgramVolumePlanner`: agrupa series efectivas previstas y ejecutadas usando claves comunes aun si `WorkoutExercise.muscleGroupSnapshot` es antiguo. El `kg·rep` continúa siendo volumen **externo**, nunca porcentaje de crecimiento muscular.
- [x] `MuscleBalanceCalculator`: agrupa nombres equivalentes, contabiliza series efectivas completadas una sola vez, excluye calentamiento/aproximación y conserva secundarios estimados por separado. La presencia de datos unilaterales no duplica una serie.
- [x] Regresiones automatizadas con catálogo sintético e historial inmutable, alias, énfasis, etiquetas compuestas, ponderación secundaria y deduplicación de sesiones.
- [x] [PR #34](https://github.com/fernando15xvs/STK-Haven_CI/pull/34) fusionado; [CI #369](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39150946650): **6/6 exitosos**, con análisis Flutter, Core, móvil, iOS, Android, Supabase y Edge.
- [x] Fuente original y espejo CI sincronizados por SHA de archivos compartidos, sin workflows en original.
- [ ] Auditoría con fixture anonimizado procedente de los datos históricos reales del dispositivo; respaldo verificado y restore/rollback antes de cualquier migración persistente.
- [ ] Completar atribuciones de participantes por ejercicio (principal, secundario, énfasis, estabilizador, confianza) e integrar detalle técnico en Plan y Progreso; no asumir que el catálogo histórico tiene especificidad que todavía no se ha curado.
- [x] Aclarar rótulos visuales de sesiones/semana vs series efectivas/semana vs volumen externo; trasladar `Nuevo plan` al AppBar para que no tape el volumen.
- [ ] Pruebas físicas Android/iPhone, tamaños pequeños, contrastes y accesibilidad.

**Decisión de seguridad:** no se limpiaron entrenamientos, no se ejecutó migración sobre Hive o Supabase, no se reescribieron snapshots y no se creó respaldo del teléfono. La equivalencia por categorías en reportes es una vista reversible; los valores crudos históricos se preservan tal cual.

### Entrega 4 — Fase 2 / auditoría local y comunicación visual (18 oct 2026)

- [x] `ExerciseAnatomyAudit.inspect` examina **sin modificar** etiquetas principales, secundarias, snapshots históricos y referencias de rutina, incluso cuando el catálogo ya no contiene el ejercicio.
- [x] Cada hallazgo conserva etiqueta original, fuente, número de apariciones y categoría segura si existe. Las etiquetas compuestas sin atribución verificable quedan separadas de las categorías generales.
- [x] Inventario de código actual: **49 presets**, **11 etiquetas primarias** principales; no equivale a inventario de entrenamientos reales del dispositivo.
- [x] En Plan: acción `Nuevo plan` movida al AppBar, evitando superposición de la tarjeta de volumen a 320 px; explicación de sesiones/semana vs. series efectivas/semana vs. volumen externo kg·rep. Porcentajes de volumen no representan ganancia muscular.
- [x] En Progreso: categorías históricas no resolubles indican `por clasificar`, permanecen visibles y no se mezclan artificialmente con un músculo concreto.
- [x] Tests automatizados de auditoría y widgets a 320 px, incluyendo ejercicios eliminados y etiquetas compuestas.
- [x] [PR #35](https://github.com/fernando15xvs/STK-Haven_CI/pull/35); [CI #373](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39155435681) **6/6 exitosos**, fusionado en el espejo y archivos compartidos sincronizados por SHA con el original.
- [x] La pantalla de auditoría **puede leer en la app** los providers reales de catálogo, rutinas e historial en el dispositivo, sin escribir cambios.
- [ ] Falta ejecutar/verificar esa auditoría en el teléfono real del usuario, obtener un fixture anonimizado desde un respaldo real, verificar restauración y diseñar una migración opcional idempotente/reversible.
- [ ] La clasificación biomecánica fina de cada ejercicio y el detalle de participación anatómica individual continúan pendientes; no inferir que una categoría general equivale a una porción.
- [ ] Pruebas de Android/iPhone físico, tamaños de fuente ampliados, VoiceOver/TalkBack y contraste antes de declarar validación para producción.

**Garantía de alcance:** esta entrega no borra, resetea, exporta ni modifica Hive, Supabase, rutinas, entrenamientos, series, PRs o favoritos. La auditoría solo produce un reporte en memoria de los datos que se le entreguen.

### Entrega 5 — Fase 2 / auditoría conectada al dispositivo (18 oct 2026)

- [x] Añadida pantalla `Revisión anatómica` desde `Progreso > Balance muscular > Revisar clasificación del historial`.
- [x] La pantalla invoca `ExerciseAnatomyAudit.inspect` con `exerciseListProvider`, `routineListProvider` y `workoutHistoryProvider`. Analiza el catálogo, las referencias en rutinas y los snapshots cargados de sesiones históricas **solo al abrir la pantalla**.
- [x] Vista legible a 320 px con total de ejercicios, referencias, entradas históricas y ocurrencias sin asignar, además de etiquetas originales agrupadas por fuente. Distingue correctamente etiquetas generales válidas de combinaciones irresolubles, sin atribuir automáticamente series a una porción.
- [x] Se señalan **cantidades**, no identificadores internos, de referencias históricas a ejercicios que el catálogo actual no contiene. No se asume pérdida de un entrenamiento.
- [x] Acceso directo a `Datos y sincronización` para **crear una copia local manual**, con advertencia explícita de que restaurar reemplaza datos. Esta pantalla no crea ni verifica respaldos ni realiza restauraciones.
- [x] Pruebas móviles 320 px con datos simulados: apertura desde Progreso, secuencias históricas, secundarios ambiguos, explicación y acceso a datos y sincronización.
- [x] [PR #36](https://github.com/fernando15xvs/STK-Haven_CI/pull/36) fusionado; [CI #377](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39159169981) **6/6 verde**, con Core, móvil, Android, iOS, Supabase y Edge. Cambios replicados a `STK-Haven` y paridad SHA comprobada.
- [ ] La app del usuario aún debe instalar esta versión y ejecutar la auditoría local; no hay acceso remoto en este proyecto al historial de su teléfono y no se puede declarar que esté limpio.
- [ ] Validación de exportación/restauración de una copia real y rollback, revisión biomecánica específica de los presets, pruebas físicas de accesibilidad y tamaño de letra.

**No se modificaron datos persistentes ni se ejecutó código de migración.** La lectura anatómica no convierte etiquetas antiguas, no cambia IDs, favoritos, peso/repeticiones, PRs ni snapshots.

### Entrega 6 — Fase 3 / biblioteca base amplia (18 oct 2026)

- [x] 180 nuevos presets con IDs estables `exv2_*` (total **229**, junto a los 49 `ex_*` preexistentes), técnica textual breve, equipo, patrón de movimiento, lateralidad, errores comunes y metadatos anatómicos. El repositorio guarda el contenido offline; la siembra solo añade IDs faltantes en Hive.
- [x] `ExerciseDefinitionV2` y `PresetAnatomyProfile`: principal, secundarios y **énfasis regional** separados; las porciones no crean series adicionales. Metadatos documentales de los 49 originales por ID, sin modificar sus nombres, etiquetas, rutinas, registros o PRs.
- [x] Cobertura extendida de pectoral (clavicular, esternocostal, fibras inferiores), deltoides anterior/lateral/posterior, manguito rotador, dorsal/romboides/trapecios, bíceps/braquial/tríceps/antebrazo, cuádriceps, isquiotibiales, glúteo mayor/medio, aductores, pantorrilla/gastrocnemio/sóleo/tibial, abdomen/oblicuos/serrato.
- [x] Selector de músculos y filtro de Biblioteca usan los IDs revisados y campos de énfasis para los presets nuevos y anteriores; búsqueda contempla nombres técnicos y alias de la taxonomía. La lateralidad de los nuevos se decide por metadatos, no por buscar palabras del título.
- [x] Tests: cardinalidad total, unicidad de IDs/variantes, inmutabilidad de 49 anteriores, validez de nodos y énfasis, técnica no vacía, filtros compuestos y búsqueda offline. [PR #37](https://github.com/fernando15xvs/STK-Haven_CI/pull/37); [CI #378](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39161322606) con comprobación de seis trabajos.
- [ ] Completar revisión externa de niveles y seguridad, estabilizadores y advertencias verificadas, curaduría de posibles variantes duplicadas entre los 49 y auditoría biomecánica experta. Los filtros por patrón/nivel ya están implementados; con 229 entradas todavía no se ha realizado una prueba de carga de 250+.
- [ ] No hay animaciones Lottie nuevas: los campos `media` permanecen vacíos hasta disponer de material auténtico autorizado, correctamente vinculado y accesible en la **Fase 4**. Nunca usar animaciones genéricas para simular un ejercicio concreto.
- [ ] QA de dispositivo físico, restauración de copia de seguridad y validación end-to-end continúan programados para el final del roadmap, antes de producción.

**Protección histórica:** los IDs y etiquetas de los 49 presets originales se mantienen; los 180 nuevos tienen IDs diferentes. No se renombraron ni borraron sesiones, récords, favoritos o copias del usuario; tampoco se lanzaron migraciones persistentes de anatomía. La instalación incorporará las entradas nuevas sin reescribir IDs existentes.

### Entrega 7 — Fase 3 / filtros avanzados combinables (18 oct 2026)

- [x] Clasificación explícita de las **180 definiciones nuevas** en 13 familias de patrones, mecánica `compuesto/aislado/estabilidad` y 3 niveles de complejidad técnica orientativa (60 principiantes, 105 intermedios, 15 avanzados). No es una prescripción clínica ni determina cargas adecuadas.
- [x] `ExerciseLibraryFilter.apply` admite **filtros simultáneos** de patrón, tipo, dificultad y solo peso corporal, junto con equipo, región/músculo, lateridad, favoritos y consulta textual. No usa heurísticas para inferir filtros avanzados de ejercicios antiguos/personalizados sin metadata; se conservan sin filtros activos.
- [x] `AdvancedExerciseFilterSheet`: controles adaptados a pantallas pequeñas, botón `Aplicar` y `Limpiar`, con explicación de por qué los ejercicios históricos sin metadata avanzada no aparecen al activar facetas específicas.
- [x] `ExerciseDetailPage`: información de patrón, tipo y nivel de las definiciones modernas; muestra explícitamente los `énfasis, no aislamientos` del pectoral/deltoide/abdominal sin multiplicar series.
- [x] Pruebas Core de totalidad y cobertura de facetas, combinaciones con equipo/anatomía/favoritos, exclusión segura de desconocidos, determinismo y no mutación; prueba widget a 320 px de filtros y restauración de estado.
- [x] [PR #38](https://github.com/fernando15xvs/STK-Haven_CI/pull/38) fusionado; [CI #379](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39164164569) **6/6 verde** (Flutter Analyze/Core, móvil, Android, iOS, Supabase y Edge); fuente original y CI idénticos por SHA en los archivos compartidos.
- [ ] Validación de accesibilidad en dispositivos reales y curaduría biomecánica independiente; queda para QA final previo a producción, como se acordó.

**Sin alteración histórica:** no se renombran ni eliminan presets originales, sesiones, PRs, favoritos, rutinas, respaldos ni snapshots; esta entrega modifica únicamente metadatos de consulta y presentación.

### Entrega 8 — Fase 4 / guías específicas y reproducción segura (18 oct 2026)

- [x] Nueva `ExerciseDemonstrationLibrary`: **43 guías específicas** de preparación, ejecución y precauciones. Para otros presets se conserva el texto técnico propio del catálogo, nunca se deduce una técnica concreta de un grupo ambiguo. Los ejercicios personalizados mantienen íntegramente sus instrucciones.
- [x] `ExerciseDemonstrationCard` situado antes de las estadísticas de `ExerciseDetailPage`: espacio de media, guía paso a paso y fallback offline claro cuando falta Lottie/poster; el recurso es exclusivamente del ID verificado.
- [x] En `ExerciseLibraryPage` modo selección: ventana previa a añadir a la rutina, `Volver` cancela y `Añadir` confirma. La selección deja intactos los registros anteriores.
- [x] Preferencia de movimiento reducido, modo ahorro y `MediaQuery.disableAnimationsOf`: se suprime animación vectorial; el botón pausar/reproducir solo se presenta si realmente existe Lottie aprobado.
- [x] `VerifiedExerciseMedia` necesita ID exacto, ruta de asset, titular, permiso y atribución. `approvedMedia` continúa **vacío**: no se han adquirido permisos ni se incluyen GIFs o fotos ajenos.
- [x] Política en `docs/roadmap/PHASE_4_MEDIA_POLICY_AND_GUIDES.md`: licencia de reproducción/redistribución comercial, correspondencia biomecánica por variante, revisión técnica, pruebas offline, respeto a preferencias y tamaño binario.
- [x] Tests automatizados: guías para 229 presets, no uso de media falsa, custom/historial intactos, vista previa de selección a 320px, reducción de movimiento y fallback. [PR #39](https://github.com/fernando15xvs/STK-Haven_CI/pull/39), [CI #383](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39166541049), 6/6 aprobados tras correcciones en pantallas estrechas.
- [ ] Obtener/producir y revisar una primera tanda de **30–40 Lotties JSON reales y autorizados**, optimizarlos y asociarlos a sus IDs. No generar movimiento genérico que pretenda representar una variante distinta.
- [ ] Probar la reproducción real, pausas, resolución, tamaño APK, modo ahorro, lectores de pantalla y equipos físicos en el QA final.

**Garantía histórica:** no se cambió el modelo persistido `Exercise`, no se reescribieron datos Hive/Supabase, sesiones, rutinas, récords ni favoritos. No se agregaron medios de terceros con licencias inciertas.

### Corrección de formato — Lottie antes que GIF (18 oct 2026)

- [x] Se corrigió un desvío de la entrega 8: **Lottie JSON vectorial** es el formato prioritario de animación en la Fase 4, por eficiencia y reproducción controlable. El roadmap original ya advertía `No usar GIF pesado por defecto`. GIF queda excluido del registro de medios.
- [x] `ExerciseMediaFormat` y `ExerciseDemonstrationCard` dejan de admitir/reproducir GIFs; se prepara `Lottie.asset` y posters PNG/WebP con control de pausa, `FrameRate.composition`, fallback offline y reducción de movimiento.
- [x] Dependencia compatible con SDK fijada en `lottie: 3.3.3`. No se reintroducen recursos de celebración de autoría incierta eliminados previamente durante la auditoría de licencias del Roadmap 3.
- [x] Se revisó `docs/roadmap/PHASE_4_MEDIA_POLICY_AND_GUIDES.md` y la cobertura de pruebas para la decisión Lottie-first.
- [ ] Los recursos Lottie del catálogo siguen **sin entregar**: producirlos/licenciarlos, validar correspondencia biomecánica por ID, medir RAM/CPU/APK/IPA y agregarlos en una etapa de assets posterior. Un vector tampoco es automáticamente liviano si incorpora imágenes grandes.
- [ ] Usar solo vídeos comprimidos en casos justificados cuando la fidelidad del movimiento humano no se logre con Lottie. No presentar GIFs como alternativa.
