# STK Haven — Roadmap 5: biblioteca anatómica, ejercicios guiados y animaciones

**Fecha:** 2026-10-17 · **Estado:** Fase 1, catálogo anatómico de lectura y pruebas integrado. Navegación visual y migración pendientes.
**Documentos:** [Taxonomía detallada (obligatoria)](EXERCISE_MUSCLE_TAXONOMY_V1.md) · [Progreso 2.0](PROGRESS_2_UNIFICATION_AND_MUSCLE_BALANCE.md).

> **Regla de los repositorios:** `fernando15xvs/STK-Haven` = **fuente de verdad**, sin workflows/GitHub Actions. `fernando15xvs/STK-Haven_CI` = **espejo** para Actions, pruebas y artefactos de iOS/Android. Mantener igualdad de código/datos/documentos salvo workflow y metadatos exclusivos del espejo. No iniciar acciones en original.
>
> **Checklist real:** marcar `[x]` solo cuando la tarea haya sido implementada, probada o verificada según su redacción. Nunca confundir «documentado» con «entregado». Guardar evidencia en la bitácora de cada fase (PR, commit, run y resultado).

## 0. Auditoría inicial de código y capturas

- [x] Revisado `packages/core/lib/core/constants/preset_exercises.dart`: actualmente **49 ejercicios de catálogo** y **11 etiquetas principales distintas**, varias demasiado generales («Espalda», «Hombros», «Piernas», «Abdomen»).
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
- [ ] Añadir navegación jerárquica (por ejemplo: `Piernas > Isquiotibiales > Semitendinoso`) con **categorías generales no contables**.
- [x] Pruebas de unicidad de IDs, alias, tildes, mayúsculas, plurales, sinónimos y pertenencia a categorías; manejo de regiones funcionales con evidencia insuficiente.

**Criterio no negociable:** «pecho superior/medio/inferior», cabeza del bíceps y «abdomen superior/inferior» no significan aislamiento anatómico garantizado. Registrar músculo y, cuando corresponda, **énfasis** separado. Una serie no cuenta tres veces al agregar al pecho completo.

## 2. Migración segura y corrección de estadísticas/planes

- [x] Implementar resolutor puro `MuscleTaxonomyV1.resolveLegacy` (versión de taxonomía) con resultado `exact`, `byExerciseContext`, `ambiguous` o `unknown`.
- [ ] Mantener estables `exercise.id`, IDs de rutinas, entrenamiento, series, PRs, favoritos, referencias de Coach Pro y backups. **No reescribir a ciegas** `WorkoutExercise.muscleGroupSnapshot`.
- [ ] Mapear «Hombro/Hombros» solo a categoría general cuando se ignore el movimiento; «Hombro anterior» sí a deltoide anterior; diferenciar dorsal de espalda y no convertir «Piernas» en cuádriceps.
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
- [ ] Cubrir variantes relevantes de pecho: barra/mancuernas/máquina, plano/inclinado/declinado, aperturas y poleas, identificando porciones enfatizadas.
- [ ] Cubrir espalda: dominadas, jalones, remos por agarre/soporte, trapecio, romboides, retractores escapulares, extensores y estabilización lumbar.
- [ ] Cubrir hombro: presses, elevaciones laterales, frontales, deltoide posterior, rotaciones interna/externa y control escapular.
- [ ] Cubrir bíceps, braquial, tríceps y antebrazo; variantes de cable, polea, barra, mancuernas y máquinas.
- [ ] Cubrir piernas: cuádriceps, isquiosurales, glúteo mayor/medio/menor, aductores, abductores, pantorrillas, tibial anterior, bisagras y patrones de sentadilla.
- [ ] Cubrir abdomen/core: crunch, flexión de tronco, elevaciones de pelvis/piernas según técnica, oblicuos, rotación/anti-rotación, anti-extensión, flexión lateral, control del serrato anterior, respiración/estabilidad sin atribución muscular exagerada.
- [ ] Filtros combinados por músculo específico/énfasis, región general, equipo, unilateral/bilateral, compuesto/aislado, patrón, dificultad y sin equipamiento.
- [ ] Búsqueda sin tildes, por sinónimos, nombres técnicos y comunes (`isquios`, `isquiotibiales`, `deltoide posterior`, `romboides`, `oblicuos`, `serrato`).
- [ ] Auditoría de IDs duplicados, alias conflictivos, instrucciones vacías, variantes realmente distintas, clasificación muscular y disponibilidad de media para cada preset.
- [ ] Pruebas de rendimiento con 250+ ejercicios, planes grandes, modo ahorro, filtrado combinado y uso sin conexión.

## 4. Animaciones y fichas técnicas auténticas

**Objetivo:** al seleccionar un ejercicio —desde biblioteca, rutina y sesión— mostrar una demostración **que se mueva**, con nota técnica clara, sin obligar a buscar fuera de la app.

- [ ] Elegir tecnología final entre video corto MP4/WebM/HEVC según plataforma, Lottie/vector o secuencia optimizada; medir tamaño, calidad, CPU, baterías y soporte iOS/Android. No usar GIF pesado por defecto.
- [ ] Definir manifiesto `exerciseMedia` con `exerciseId`, licencia verificable, atribución, fuente, versión, vista anterior/lateral, poster offline, duración y peso.
- [ ] Obtener o producir demostraciones **originales o licenciadas con derechos compatibles**, documentando permisos de distribución. La captura de referencia **no concede permiso** para copiar su animación.
- [ ] Primera tanda de **30–40 ejercicios comunes** con animación validada (press banca, jalón, remo, elevaciones, sentadilla, RDL, curl femoral, hip thrust, crunch, etc.).
- [ ] Expandir progresivamente; **no** mostrar animaciones equivocadas a ejercicios no cubiertos. Si falta video, usar imagen/poster + instrucciones honestas.
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
| 0. Auditoría preliminar y documentos | **Parcial** | Auditoría de fuentes actuales; esta especificación y taxonomía creadas |
| 1. Taxonomía anatómica | **Núcleo implementado** | 98 nodos y pruebas Core; UI jerárquica y revisión anatómica final pendientes |
| 2. Migración/estadísticas/planes | **Parcial** | Resolutor puro implementado; ninguna migración ni actualización de estadísticas aplicada |
| 3. Biblioteca ampliada | **Pendiente** | Se mantienen los 49 presets actuales |
| 4. Animaciones y ficha | **Pendiente** | No se ha distribuido nuevo media |
| 5. Editor personalizado guiado | **Pendiente** | No modificado |
| 6. Integración visual | **Pendiente** | No modificado |
| 7. CI y pruebas físicas | **Pendiente** | No iniciadas para este roadmap |

**Próximo paso recomendado:** Fase 0 (inventario completo y clasificador seguro) → Fase 1 (IDs/alias canónicos). No empezar a poblar cientos de ejercicios ni medios hasta asegurar que la clasificación y el historial son seguros.

### Entrega 1 — Catálogo anatómico base y compatibilidad (17–18 oct 2026)

- [x] 98 nodos con IDs estables: 32 categorías, 46 músculos, 20 regiones, 390 claves de búsqueda/alias sin colisiones, incluido serrato anterior y complejo abdominal.
- [x] 49 ejercicios preinstalados validados frente a la resolución conservadora de etiquetas primarias y secundarias.
- [x] Nombres ambiguos como «Hombros», «Espalda», «Piernas» y etiquetas combinadas permanecen sin asignación muscular específica hasta revisión.
- [x] Pruebas del paquete Core, análisis Flutter, móvil, iOS, Android, Supabase/Edge en [CI #39095901308](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/39095901308), **6/6 trabajos exitosos**. [PR #32](https://github.com/fernando15xvs/STK-Haven_CI/pull/32) fusionado.
- [x] `STK-Haven` original conserva su función de fuente de verdad y carece de workflows; cambios replicados en el espejo.
- [ ] Integración en Plan/Progreso, selección visual, migración con respaldo y pruebas físicas; no se ha alterado el historial existente ni generado una copia de seguridad del teléfono.

**Siguiente tarea:** conectar un lector de IDs canónicos, sin escritura destructiva, al cálculo de frecuencias y volumen de Plan de entrenamiento, probar datos ambiguos antes de cambiar su interfaz y mantener snapshots originales.
