# STK Haven — Taxonomía anatómica muscular v1 (especificación, no código)

**Estado:** propuesta para implementar. **Creado:** 2026-10-17. **Roadmap:** [ROADMAP_5_EXERCISE_ANATOMY_LIBRARY_MEDIA.md](ROADMAP_5_EXERCISE_ANATOMY_LIBRARY_MEDIA.md).

## Propósito y criterios

Una sola fuente de verdad para grupos, músculos y regiones funcionales en **Ejercicios**, **Plan de entrenamiento**, **Progreso > Músculos**, Coach Pro y ejercicios personalizados. Las categorías generales solo organizan la UI; las estadísticas usan identificadores anatómicos estables. El nivel de precisión depende de la evidencia del ejercicio. No se le atribuye aislamiento a un músculo cuando un movimiento implica varios.

Se emplean tres niveles distintos:

1. **Categoría/padre:** navegación agregada: pecho, espalda, hombros, brazos, glúteos, muslos, piernas inferiores y complejo abdominopélvico. **No se cuenta como un músculo adicional**.
2. **Músculo anatómico o cabeza/porción validada:** entidad de seguimiento con `id` permanente. Algunos elementos son regiones de un músculo, no músculos separados.
3. **Participación:** `principal`, `secundario`, `énfasis_regional`, `estabilizador` o `no_atribuible` (por ejemplo, respiración/estabilización). Mostrar la confianza y la naturaleza estimada; no duplicar series para cada hijo y su padre.

## 1. Ontología propuesta y nombres estables

**Convención:** IDs ASCII inmutables con prefijos `mg_` (grupo/padre), `m_` (músculo), `reg_` (porción/región). Nombre canónico en español + nombre anatómico en UI secundaria, alias español/inglés para búsqueda. No usar `Hombro`, `Piernas`, `Core`, `Tríceps y hombro` como ID muscular detallado.

### Pecho / cintura pectoral

| ID propuesto | Nombre visible | Detalle |
|---|---|---|
| `reg_pec_clavicular` | Pectoral superior · porción clavicular | Fascículos claviculares del pectoral mayor; **región**, no músculo independiente |
| `reg_pec_esternocostal` | Pectoral medio · porción esternocostal | Región esternocostal del pectoral mayor; uso descriptivo |
| `reg_pec_inferior` | Pectoral inferior · fascículos inferiores | Fibras esternocostales inferiores/porción abdominal del pectoral mayor; **énfasis regional**, no aislamiento |
| `m_pectoralis_major` | Pectoral mayor · general | Agrupación cuando no es justificable repartir el énfasis |
| `m_pectoralis_minor` | Pectoral menor | Relación con movilidad/estabilización escapular; no contarlo automáticamente en presses |
| `m_serratus_anterior` | Serrato anterior | Músculo torácico de la cintura escapular, no uno de los abdominales, aunque esté junto a las costillas |

**Nota científica:** «pecho superior/medio/inferior» no equivale a tres músculos anatómicos independientes. Registrar `pectoralis_major` como objetivo principal y, cuando proceda, *énfasis* clavicular/esternocostal/inferior. En agregados de pecho, una serie de press es una serie, no tres.

### Hombros y rotadores del hombro

| ID | Nombre |
|---|---|
| `reg_deltoid_anterior` | Deltoides anterior |
| `reg_deltoid_lateral` | Deltoides lateral o medio |
| `reg_deltoid_posterior` | Deltoides posterior |
| `m_deltoid` | Deltoides general (solo legado/no especificado) |
| `m_supraspinatus` | Supraespinoso |
| `m_infraspinatus` | Infraespinoso |
| `m_teres_minor` | Redondo menor |
| `m_subscapularis` | Subescapular |
| `m_teres_major` | Redondo mayor (acción sinérgica con dorsal, no manguito rotador) |

Las tres porciones del deltoides se muestran **separadas**. El manguito rotador se identifica por sus cuatro músculos; la estabilización no debe inflar series directas.

### Espalda y músculos escapulares

| ID | Nombre |
|---|---|
| `m_latissimus_dorsi` | Dorsal ancho |
| `m_rhomboid_major` | Romboides mayor |
| `m_rhomboid_minor` | Romboides menor |
| `reg_trapezius_upper` | Trapecio superior |
| `reg_trapezius_middle` | Trapecio medio |
| `reg_trapezius_lower` | Trapecio inferior |
| `m_levator_scapulae` | Elevador de la escápula |
| `m_erector_spinae` | Erectores espinales (iliocostal, longísimo, espinoso agrupables) |
| `m_multifidus` | Multífidos · musculatura profunda |
| `m_quadratus_lumborum` | Cuadrado lumbar |

**No confundir:** `Dorsal` (latissimus dorsi) y `Espalda` (categoría). Romboides, trapecio, dorsal y erectores son entidades distintas. Para porcentajes de región escapular/espalda alta evitar contar dos veces un mismo `setId` por pertenencias superpuestas.

### Brazos, codos y antebrazo

| ID | Nombre |
|---|---|
| `reg_biceps_long_head` | Bíceps braquial · cabeza larga |
| `reg_biceps_short_head` | Bíceps braquial · cabeza corta |
| `m_brachialis` | Braquial anterior |
| `m_brachioradialis` | Braquiorradial |
| `reg_triceps_long_head` | Tríceps braquial · cabeza larga |
| `reg_triceps_lateral_head` | Tríceps braquial · cabeza lateral |
| `reg_triceps_medial_head` | Tríceps braquial · cabeza medial |
| `mg_forearm_flexors` | Flexores/pronadores de muñeca y dedos (grupo) |
| `mg_forearm_extensors` | Extensores/supinadores de muñeca y dedos (grupo) |

Para curls y extensiones normales, mostrar cabeza *enfatizada* si hay justificación biomecánica; no prometer aislamiento de una sola cabeza.

### Glúteos, cadera, abductores y aductores

| ID | Nombre |
|---|---|
| `m_gluteus_maximus` | Glúteo mayor |
| `m_gluteus_medius` | Glúteo medio |
| `m_gluteus_minimus` | Glúteo menor |
| `m_tensor_fasciae_latae` | Tensor de la fascia lata |
| `m_adductor_magnus` | Aductor mayor |
| `m_adductor_longus` | Aductor largo |
| `m_adductor_brevis` | Aductor corto |
| `m_gracilis` | Grácil |
| `m_pectineus` | Pectíneo |
| `m_iliopsoas` | Iliopsoas · flexores profundos de cadera |
| `mg_deep_hip_rotators` | Rotadores profundos de cadera (incluye piriforme, obturadores, gemelos y cuadrado femoral) |

**Regla:** `glúteos y isquios` son dos grupos de músculos; jamás crear un «músculo combinado». Una bisagra de cadera puede involucrar ambos con distinto papel.

### Muslo: cuádriceps, isquiotibiales y región medial

| ID | Nombre |
|---|---|
| `m_rectus_femoris` | Recto femoral |
| `m_vastus_lateralis` | Vasto lateral |
| `m_vastus_medialis` | Vasto medial |
| `m_vastus_intermedius` | Vasto intermedio |
| `reg_biceps_femoris_long` | Bíceps femoral · cabeza larga |
| `reg_biceps_femoris_short` | Bíceps femoral · cabeza corta |
| `m_semitendinosus` | Semitendinoso |
| `m_semimembranosus` | Semimembranoso |
| `m_sartorius` | Sartorio |

**Importante:** la cabeza corta del bíceps femoral no es extensora de cadera; no atribuirla automáticamente a bisagras de cadera. `Piernas` es categoría de navegación, nunca músculo individual. Los músculos aductores están detallados en el bloque anterior.

### Pierna inferior y pie

| ID | Nombre |
|---|---|
| `reg_gastrocnemius_medial` | Gastrocnemio · cabeza medial |
| `reg_gastrocnemius_lateral` | Gastrocnemio · cabeza lateral |
| `m_soleus` | Sóleo |
| `m_tibialis_anterior` | Tibial anterior |
| `mg_fibularis` | Fibulares/peroneos |
| `mg_deep_calf_flexors` | Flexores profundos de pie y dedos |
| `mg_foot_intrinsics` | Musculatura intrínseca del pie (si se incorpora rehabilitación/movilidad) |

`Pantorrillas` agrupa gastrocnemio y sóleo; contabilizar como agregado sin multiplicar las series registradas.

### Abdomen y complejo abdominopélvico — **obligatorio y completo**

| ID | Nombre | Uso en STK Haven |
|---|---|---|
| `m_rectus_abdominis` | Recto abdominal | Músculo anterior; crunches, flexión de tronco, anti-extensión según movimiento |
| `reg_rectus_abdominis_upper` | Recto abdominal · énfasis superior | Etiqueta regional de ejercicio, **no músculo aislado** |
| `reg_rectus_abdominis_lower` | Recto abdominal · énfasis inferior | Etiqueta regional de ejercicio, **no músculo aislado** |
| `m_external_oblique` | Oblicuo externo | Rotación, anti-rotación y flexión lateral |
| `m_internal_oblique` | Oblicuo interno | Estabilización, rotación, anti-rotación |
| `m_transversus_abdominis` | Transverso del abdomen | Pared abdominal profunda; no atribuir series de hipertrofia sin evidencia |
| `m_quadratus_lumborum` | Cuadrado lumbar | Estabilidad lateral (referenciar el mismo ID de espalda; sin duplicarlo) |
| `m_multifidus` | Multífidos | Estabilidad segmentaria (mismo ID que espalda; sin duplicar) |
| `m_erector_spinae` | Erectores espinales | Extensión/estabilización del tronco (mismo ID; sin duplicar) |
| `m_diaphragm` | Diafragma | Función respiratoria/estabilidad; **no** volumen muscular convencional |
| `mg_pelvic_floor` | Suelo pélvico | Funcional; **no** inferir series directas de ejercicios genéricos |

**Serrato anterior** (`m_serratus_anterior`) debe ser visible al consultar «Costillas y cintura escapular» y opcionalmente «Core/estabilización», **sin duplicar el músculo ni atribuirle volumen abdominal**. El «six-pack» es el recto abdominal, y sus porciones superior/inferior no son músculos separados. Para «oblicuos» diferenciar externos e internos aunque la evidencia del ejercicio muchas veces solo permita `obliques_general` no especificado. Añadir en futuro `m_pyramidalis` si hay necesidad clínica real; no es un objetivo estándar de ejercicios.

## 2. Contrato de clasificación y agregación

- `MuscleNode(id, parentId, displayNameEs, anatomicalName, nodeType, aliases, active)` con taxonomía versionada `muscle_taxonomy_v1`. Cada ID estable tiene un solo registro y puede mostrarse en varias categorías *sin contarse dos veces*.
- `ExerciseTarget(muscleId, role, confidence, rationale)`; `role`: `primary`, `secondary`, `regionalEmphasis`, `stabilizer`. Evitar porcentajes universales de activación muscular; no extrapolar EMG directamente a hipertrofia.
- `general_unspecified` / `legacy_unresolved` para `Pecho`, `Espalda`, `Piernas`, `Hombros` o etiquetas ambiguas que no puedan mapearse a una porción. Nunca decidir «anterior» o «cuádriceps» únicamente por el texto general.
- Si un ejercicio apunta a varias estructuras, mantener un **conteo entero de series de trabajo completadas a nivel ejercicio** y exposiciones musculares estimadas claramente separadas (directa/indirecta/estabilizadora). Un set no se transforma en tres sets al expandir una categoría.
- Frecuencia: día/sesión distinta, separado por trabajo principal, secundario y estabilización; no confundir frecuencia con total de series. `kg·rep` es volumen externo, no medida directa de estímulo de hipertrofia.
- Antes de personalizar, una taxonomía/catálogo pueden sugerir atributos, pero el usuario conserva la capacidad de corregir la variante y el objetivo.

## 3. Alias históricos y migración sin pérdida

| Etiqueta actual o heredada | Normalización permitida | Ambigüedad |
|---|---|---|
| Hombro / Hombros | Grupo general `m_deltoid` | Resolver anterior/lateral/posterior por **ID del ejercicio**, si es inequívoco |
| Hombro anterior | `reg_deltoid_anterior` | Alias |
| Hombros posteriores | `reg_deltoid_posterior` | Alias |
| Espalda | `mg_back` (padre) / `legacy_unresolved` | **No** convertir todo en dorsal |
| Dorsal | `m_latissimus_dorsi` | Exacto si el contexto lo confirma |
| Espalda baja | `m_erector_spinae` **solo si el ejercicio lo verifica** | De otro modo etiqueta lumbar general |
| Piernas | `mg_lower_body` y marcador no especificado | No asignar arbitrariamente a cuádriceps |
| Isquios / Isquiosurales / Isquiotibiales | Categoría isquiotibiales | Porción específica solo con evidencia |
| Glúteos | Grupo glúteos | Porción mayor/medio/menor solo con evidencia |
| glúteos y isquios | Dos etiquetas de participación pendientes de resolución | No inventar un músculo |
| Tríceps y hombro | Dos participaciones separadas sujetas al ejercicio | No asignar ambas como principales sin evidencia |
| Abdomen / Core | Grupo abdominal/estabilidad | No convertir en recto abdominal automáticamente |
| Oblicuos | Oblicuos generales no especificados | Separar interno/externo **solo con evidencia** |
| Serratos | `m_serratus_anterior` si se confirma | No confundir serratos posteriores |
| Cuádriceps / cuádriceps | Categoría canónica cuádriceps | Normalización de mayúsculas/acentos |

El proceso debe ser **idempotente**: usar `exercise.id` y `taxonomyVersion`, conservar valores de origen, no sobrescribir `WorkoutExercise.muscleGroupSnapshot` ni IDs/series/PRs/rutinas/Coach Pro/backups. Calcular *vistas normalizadas derivadas* y mostrar un reporte de ambiguos para elección del usuario. Habilitar rollback por alias/reporte si la clasificación es cuestionable.

## 4. Casos de aceptación obligatorios

- [ ] «Hombro», «Hombros», «Deltoides anterior» no generan tres grupos de hombro para el mismo ejercicio.
- [ ] «Pecho superior/medio/inferior» se filtra por énfasis, sin inventar tres músculos pectorales ni triplicar series.
- [ ] Un press de banca muestra pectoral mayor, tríceps y deltoide anterior con roles explicados; no se afirma aislamiento del pecho medio.
- [ ] Espalda diferencia dorsal, romboides, trapecios y erectores; «Espalda» general no se asigna a dorsal automáticamente.
- [ ] Glúteo mayor/medio/menor, cuádriceps (cuatro porciones) e isquiotibiales (incluida cabeza corta) se encuentran por nombre y alias.
- [ ] Abdomen diferencia recto, oblicuo interno/externo, transverso, oblicuos generales, estabilidad profunda; serrato anterior no se contabiliza dos veces.
- [ ] Filtrar «Piernas» incluye cuádriceps, isquiotibiales, glúteos, aductores y pantorrillas, sin «Piernas» como músculo duplicado.
- [ ] Datos ambiguos e históricos preservan sus valores y pueden mostrarse como «sin región determinada».
- [ ] Conteos directos, indirectos, énfasis regional y estabilidad aparecen diferenciados con explicación visible.
- [ ] Pasan pruebas de catálogo, migración, filtros, frecuencia, volumen, historiales, backups y Coach Pro.

**Nota:** los nodos y su presentación necesitan revisión anatómica/técnica documentada antes de incorporarse al código. Esta especificación no equivale a migración realizada.
