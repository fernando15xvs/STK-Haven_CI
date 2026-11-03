# Auditoría DATA-07 / DATA-08 — Tiempo y sesiones parciales

> Fecha: 2026-11-02. **Auditoría de código; sin modificación ni limpieza de registros.**
> [Roadmap](../roadmap/PROGRESS_2_VISUAL_QUALITY_ROADMAP_20261102.md) ·
> [Checklist](../roadmap/PROGRESS_2_VISUAL_QUALITY_CHECKLIST_20261102.md)

## Evidencia verificada en `main`

| Componente | Código observado | Implicación |
| --- | --- | --- |
| `active_workout_provider.dart` → `finishWorkout` | `now.difference(startedAt).inSeconds`, salvo duración manual (1–720 min) | Mide tiempo registrado/transcurrido, **no tiempo de esfuerzo activo**. Una sesión larga abierta puede contribuir a una duración media como «252m». |
| `resumeSavedWorkout` | `startedAt = now - savedSession.durationSeconds` | Conserva la duración registrada al reanudar; el tiempo transcurrido después de reanudar vuelve a sumarse. No implica necesariamente entrenamiento continuo. |
| `finishWorkout` parcial | Guarda historial con el mismo ID, deja borrador reanudable y retiene series pendientes | Una sesión parcialmente finalizada con trabajo efectivo figura en el historial sin duplicar su ID. Gamificación y programa **solo avanzan al terminar completamente**. |
| `progress_metrics_service.dart` | Suma `durationSeconds` de las sesiones con `finishedAt > startDate`; media = suma / número de sesiones | Un valor extremo eleva la media. El filtro no exige `finishedAt <= now`, mientras el calendario sí termina en «hoy». |
| `calendar_heatmap_calculator.dart` | Cuenta sesiones por **fecha de `finishedAt`** dentro de los días de la cuadrícula | El calendario puede diferir de una cuenta semanal basada en `startedAt`, o de una sesión con fecha de fin futura. |
| `workout_comparator.dart` | Cuenta volumen/series solo con `set.completed && !set.warmup` | El trabajo parcial completado contribuye al volumen; los pendientes no. |
| `ProgressMetricsProvider` | La frecuencia y duración usan `currentPeriodSessions.length` | Históricos importados sin series efectivas podrían sumar sesiones/duración si no se acuerda un filtro. |

## Conclusiones

1. El ejemplo visual «252m» es **un posible valor atípico**, pero **no demuestra un bug** sin revisar el registro correspondiente y la duración real elegida. No se debe modificar automáticamente.
2. Es razonable conservar las series realizadas de un entrenamiento parcial, pero debe existir un contrato explícito para *entrenamientos registrados* frente a *entrenamientos totalmente completados* (recompensas/programas).
3. Los filtros de resumen y calendario deben usar límites temporales compatibles, especialmente ante registros importados, sesiones próximas a medianoche y fechas futuras.
4. Una etiqueta profesional sería «Duración media registrada», con aclaración de que no equivale a tiempo neto de esfuerzo. No ocultar sesiones largas ni manipular datos.

## Casos reproducibles obligatorios antes de cambiar fórmulas

- [ ] Caso A: sesión completada de 60 min en el período → duración total 60 min, media 60 min; un día activo.
- [ ] Caso B: sesión parcial de 45 min con dos series efectivas completadas y una pendiente → sus series cuentan en volumen; **sin** premio ni progreso de programa por sesión incompleta.
- [ ] Caso C: misma sesión parcial, reanudada y completada con el **mismo ID** → un único histórico actualizado; no sumar dos sesiones ni dos recompensas.
- [ ] Caso D: sesión importada sin ninguna serie efectiva realizada → determinar si debe contar en frecuencia y calendario; no inferir «fallida».
- [ ] Caso E: entrenamiento que empieza el domingo 23:40 y termina el lunes 00:20 → Inicio, calendario y Resumen deben atribuirlo al mismo día definido por contrato. El incremento UX actual alinea Inicio con `finishedAt`.
- [ ] Caso F: finalización manual con `finishedAt` futuro respecto de `now` → no debe aumentar métricas presentes sin evidencia; preservar el registro original.
- [ ] Caso G: sesiones de 30, 60 y 252 min → media registrada correcta y nota explicativa; sin censurar valores atípicos.
- [ ] Caso H: selección 7D/1M/3M/1A y períodos anteriores → ventanas no solapadas, sin datos futuros y con sumas consistentes.


## Incremento de validación DATA-07 — 2026-11-03

**Fuente de código:** `STK-Haven/main` posterior a PR #39, rama
`fix/progress-registered-duration-contract-20261103`.
**En este incremento no se reescriben registros ni se cambia quién cuenta.**

- El filtrado de finalizaciones futuras **ya fue corregido** por PR #35:
  `isSessionInMetricsPeriod` exige `finishedAt <= now`. La referencia
  histórica de la tabla anterior describe el estado previo, no el actual.
- Se extrae una suma pura `summarizeRecordedDurations` para verificar que
  `promedio = suma(durationSeconds) / número de entradas registradas / 60`.
  El cálculo excluye automáticamente entradas fuera de la ventana porque las
  filtra el proveedor antes de invocarlo.
- La interfaz dice **MEDIA REGISTRADA** y explica mediante tooltip que
  incluye pausas y tiempo registrado al dejar un entrenamiento abierto; no
  representa minutos de esfuerzo neto ni diagnostica la cifra 252m como error.
- La prueba `progress_recorded_duration_contract_test.dart` reproduce A–H
  con sesiones sintéticas, una sin historial y un extremo de 252 minutos.
  Para C valida el resumen de un snapshot ya reemplazado, **no** afirma
  ejecutar la persistencia Hive ni pruebas de recompensas.
- Por compatibilidad, una entrada importada sin sets efectivos **todavía
  cuenta como entrenamiento registrado**, tal como hacía el proveedor.
  **DATA-08 sigue abierto**: definir con pruebas el criterio distinto de
  actividad efectiva y de sesión de programa terminada antes de cambiar
  frecuencia, calendario o porcentajes.

**Puertas de cierre:** CI completo del espejo, comparación de fuentes,
fusión canónica y pruebas físicas de la etiqueta/tooltip. Mientras tanto,
la aprobación de DATA-07 es parcial; DATA-08 y QA-05/06 continúan pendientes.

## Decisión pendiente de producto

Antes de cambiar cualquier métrica, decidir si «frecuencia de entrenamiento»
incluye sesiones parciales con al menos una serie efectiva o solo las
totalmente completadas. **Recomendación técnica:** contar trabajo efectivo
realizado como actividad, pero dejar «sesión de programa completada» como
concepto separado; no confundirlo con recompensas.

## Próximos archivos a tocar (solo después de pruebas)

- `packages/core/lib/features/progress/application/progress_metrics_service.dart`
- `packages/core/lib/features/progress/application/calendar_heatmap_calculator.dart`
- `packages/core/test/features/progress/application/*`
- `apps/app_mobile/lib/features/progress/presentation/pages/progress_page.dart`

**Estado:** DATA-07/08 siguen pendientes; auditoría inicial completada sin
pruebas físicas ni refactor de métricas. No cerrar casillas prematuramente.
