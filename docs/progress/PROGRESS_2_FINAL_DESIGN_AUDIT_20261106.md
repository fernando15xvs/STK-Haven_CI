# Progreso 2.0 — auditoría de diseño y seis incidencias originales

**Corte:** 2026-11-06 · **PR única:** #55 · **ámbito:** Inicio,
Resumen, Ejercicios, Músculos, Medidas, ficha técnica, historial y
controles compartidos de Progreso. El documento acredita inspección de
código y regresiones sintéticas; **NO equivale a revisar la app en el
iPhone/Android físico ni a una comparación píxel a píxel de las seis
capturas privadas**.

## Seis incidencias que originaron este roadmap

| # | Síntoma original | Corrección inspeccionada | Prueba automatizada / evidencia |
|---|---|---|---|
| 1 | Tooltip de volumen `15912.0` sin fecha/unidad y poco legible en oscuro | `ProgressChartStyle` formatea `15.912 kg`, fecha española completa, Outfit, fondo/texto semánticos; tooltip confinado horizontal/verticalmente. | `progress_chart_readability_test.dart` y `progress_tooltip_semantics_test.dart` (8 acentos, dark/light/OLED y 320px; >=4,5:1). |
| 2 | e1RM `31 o`, máximo `39,0 kg` o línea de selección cortados | Fechas inicial/final fuera del canvas, dos líneas flexibles; márgenes X/Y dinámicos, máximos/Mín. permanentes; mismo kg/lb para puntos y límites. | `progress_chart_viewport_matrix_test.dart`, `progress_chart_touch_extremes_test.dart` (320/375/390/430px; escala 1/1,3/1,6; kg/lb y pantallas oscuras). |
| 3 | Duplicación de constancia y KPIs entre Inicio/Resumen/calendario | Resumen contiene volumen, gráfico, ritmo, calendario y conclusiones; días activos tienen un solo dueño (calendario); Inicio se enfoca en acción y acceso a Progreso. Indicadores de consistencia reflow 1/2 columnas sin elipsis. | `progress_summary_scope_test.dart`, `progress_consistency_metrics_test.dart`, contratos de período compartido y navegación. |
| 4 | Ejercicio expandido y ficha técnica repiten varias sesiones, e1RM, PR y textos | `ProgressExercisesPanel` concentra comparaciones y tendencia; ficha técnica muestra demostración + accesos «Ver mi rendimiento» / «Ver historial completo» del ID correcto; no reproduce cinco sesiones. | `progress_context_navigation_test.dart`, `progress_unified_exercises_test.dart`, `exercise_detail_page_test.dart` si está presente; propiedad de datos en roadmap. |
| 5 | «252m» de duración media parece anómalo | Duración es tiempo **registrado**, no tiempo activo; no se falsifican ni truncan sesiones. Etiqueta `MEDIA REGISTRADA` y tooltip explicativo; cálculo con parciales y 30/60/252min. Cifras de tendencia con coma española y texto primario contrastado. | `progress_recorded_duration_contract_test.dart`, `progress_consistency_metrics_test.dart`, `progress_summary_scope_test.dart`. |
| 6 | Series con `completed=false` aparecen erróneamente como «Fallida» | `WorkoutSet.recordedOutcome` opcional, Hive `@HiveField(16)` agregado sin reescribir historiales. Pendiente predeterminado; Omitida/Fallida requieren selección explícita; Completada limpia el estado; backup y draft/historial lo conservan. | `workout_set_record_status_test.dart`, `workout_recovery_contract_test.dart`, `backup_backward_compatibility_roadmap2_test.dart`, `exercise_history_set_row_test.dart`. |

**Fixture sintético público:** `docs/progress/PROGRESS_CHART_VISUAL_FIXTURES_20261102.md`;
ninguna imagen o dato personal se publica. Los casos de borde (0, 1,
pico de 15.912, curva constante, 37,7/39, fechas iguales/intermitentes,
kg/lb y períodos 7D/1M/3M/1A) están cubiertos por pruebas Core y UI
que se ejecutan en el espejo.

## Auditoría transversal por pantalla

| Superficie | Consistencia / accesibilidad inspeccionada | Restricción explícita |
|---|---|---|
| Inicio | Resumen compacto; no duplicar cifras detalladas; ruta a progreso, entrenamiento minimizado intacto. | No se rediseñó Motivation/Coach. |
| Resumen | Outfit/\`AppTypography\`, \`AppColors\`, cifras tabulares, \`AppSpacing\` y \`AppRadius\`; trend con coma decimal, icono y voz; KPI y gráfico nunca truncados. | La prueba widget no reemplaza percepción real. |
| Ejercicios | Búsqueda/filtros, métricas veraces y e1RM con estado vacío y límite por período; navegación por ID. | Riesgo de nombres muy largos cubierto en widget, revisar VoiceOver real. |
| Músculos | Balance y distribución explícitos, fechas completas; resumen 1/2/3 columnas, 24 variantes de pantalla/escala/tema. | Confirmar interpretación muscular en dispositivo. |
| Medidas | Perímetros reales, imágenes anatómicas auténticas, fichas sin inferir hipertrofia; fondo/acento/Outfit compartidos. | El historial nunca se reescribe para capturas. |
| Ficha técnica | Técnica/demostración y vínculos al registro propio; sin PR/serie duplicados; \`reduceMotion\` aplicado a demostraciones. | No cambiar IDs estables. |
| Historial | Pendiente distinto de Omitida/Fallida; cifras y estado anunciables. | No clasificar históricos por RIR=0. |

## Criterios DES-01/03/04/05/06/07/08/09

- **DES-01**: familia Outfit a través de `AppTypography` en ejes,
  leyendas, estados, tarjetas y valores; números tabulares en métricas.
- **DES-03/04**: superficies/etiquetas por `AppColors.of(context)`,
  contraste comprobado >=4,5:1 para texto normal en matrices con ocho
  acentos, claro/oscuro/OLED. Textos numéricos de tendencias ya no
  dependen del verde/rojo de fondo para ser interpretados.
- **DES-05/06**: tarjetas/tokens comunes `AppSpacing`, `AppRadius`,
  `AppElevation`, control de período único entre Resumen/Ejercicios/
  Músculos, sin listas históricas duplicadas.
- **DES-07**: 320/375/390/430 px y texto 100/130/160 % probados; gráficos
  con `MediaQuery.disableAnimationsOf(context)` usan duración cero
  ante «Reducir movimiento» del sistema; controles y fechas se
  envuelven/desplazan en vez de recortar números.
- **DES-08**: los seis casos reproducidos con fixtures sintéticos,
  widgets y tests de persistencia. **Inspección de la imagen original
  sobre hardware: NO EJECUTADA**.
- **DES-09**: semántica de fechas, unidades, máximos, controles y
  estados instrumentada/testeada. **VoiceOver y TalkBack físicos:
  NO EJECUTADOS**; no se puede dar por completado el criterio manual.

**Puerta:** no marcar las casillas globales como `[x]` hasta que el
código se integre en el repositorio canónico y el CI final del último
SHA pase 7/7. Las comprobaciones físicas siguen como tareas QA-05/06/07/
09/10 hasta que exista la evidencia pertinente.

## Protección de datos y del resto del producto

Solo modificaciones en Progreso/Entrenar, política de estados, backup
aditivo y regresiones; sin cambiar Supabase remoto, Motivation, playlist,
Coach ni rotación del programa. `GAM-01` acepta un primer PR auténtico
en una sesión parcial **sin** conceder XP por completar entrenamiento o
avanzar una rutina hasta completar las series efectivas.

## Entrega iPhone

El workflow del espejo crea `stk-haven-ios-unsigned` tras compilar
release y WidgetKit. Este artefacto **no es instalable directamente**
en un iPhone. Se requiere firmar Runner y la extensión WidgetKit con
perfiles de Apple compatibles (incluido el App Group compartido).
Procedimiento seguro en `docs/progress/IOS_PHYSICAL_TEST_SIGNING_20261106.md`.
Nunca publicar certificados ni claves en el espejo.
