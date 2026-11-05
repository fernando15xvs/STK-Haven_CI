# Progreso 2.0 — cifras tabulares y contraste de KPI (DES-02)

**Fecha:** 2026-11-04 · **Alcance:** indicadores numéricos en Progreso.

## Regla de diseño

Toda cifra de KPI usa **Outfit**, ya registrada y empaquetada, con
`FontFeature.tabularFigures()` para que los dígitos mantengan su posición
al cambiar filtro/medida y no «salten» horizontalmente. No se añade una
tipografía monoespaciada diferente.

- Volumen total: `ProgressVolumeHeadline` ya usa `Outfit` +
  `tabularFigures` (sin cambios a conversiones ni formateo español).
- Ejes/tooltips en volumen y e1RM: `ProgressChartStyle` ya usa
  `Outfit` + `tabularFigures`; el foco y el rango Mín./Máx.
  están separados de los datos históricos.
- Consistencia (entrenamientos/semana y minutos de sesión):
  `ProgressConsistencyMetrics` usa `AppTypography.headlineMedium`
  con figuras tabulares y `AppColors.of(context).textPrimary`.
  Las etiquetas permanecen `AppTypography.labelSmall` en color secundario.
- Balance muscular: los tres KPI totales (`Series directas`,
  `Trabajados`, `Sin actividad`) heredan el mismo Outfit con números
  tabulares. Las cifras individuales por músculo ya usan
  `AppTypography.monoLarge/monoMedium` que son Outfit tabular.

**Sin alterar** cálculos, unidades, pesos, sesiones, PR, entrenamiento
parcial, gamificación, estado de filtros, Hive ni Supabase.
No se añaden sombras, gradientes, bordes llamativos ni decoraciones.

## Validación

- `progress_consistency_metrics_test.dart`: 320 px, texto 1.6,
  claro y oscuro OLED; verifica fuente Outfit, figuras tabulares,
  color semántico y contraste >=4.5:1 para ambos KPI. Mantiene
  tooltip explicativo de minutos y no duplica días activos.
- `muscle_balance_panel_test.dart`: 320 px y evidencia real de sesiones;
  valida las tres cifras del resumen en Outfit tabular, sin modificar el
  modelo de balance o su estado.
- Las pruebas existentes de gráficos (`progress_chart_readability_test.dart`,
  `progress_chart_viewport_matrix_test.dart`) continúan comprobando los
  ocho acentos, kg/lb, fechas, temas y ausencia de desbordamientos.

**Gate:** CI 7/7 en `STK-Haven_CI/main`, SHA exacto de cada archivo del
PR contra fuente canónica privada y merge únicamente tras éxito. La
auditoría global DES-01/03/04/05/06/07/08/09 y QA física/VoiceOver/TalkBack
**siguen abiertas**; este bloque solo cierra DES-02 cuando pase CI.
