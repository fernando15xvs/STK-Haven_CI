# Progreso 2.0 — Contrato DATA-08: actividad efectiva y calendario

**Fecha:** 2026-11-03. **Fuente:** STK-Haven privado.
**Rama:** `fix/progress-effective-activity-consistency-20261103`.
**Dependencia:** PR #40 (DATA-07); este incremento se revisa e integra después
de #40. El espejo STK-Haven_CI se usa **solo para Actions**, sin segundo PR.

## Problema verificado

El proveedor de Progreso filtraba por `finishedAt`, pero contaba como
entrenamiento una fila importada incluso sin series realizadas. También
sumaba su duración y marcaba activo el día en el calendario. El entrenador
no permite finalizar un entrenamiento nuevo sin trabajo válido, pero Hive
puede conservar importaciones antiguas y eso no autoriza borrarlas.

## Contrato aplicado a estadísticas, no a persistencia

1. **Actividad de entrenamiento:** existe al menos una serie de tipo
   `WorkoutSetType.working` con `completed == true` y
   `performanceReps > 0`. Peso cero con repeticiones positivas cuenta
   (ejercicio con peso corporal). Calentamiento únicamente, series
   pendientes o entradas vacías no cuentan.
2. **Sesión parcial:** si contiene una serie efectiva válida, cuenta en
   frecuencia, volumen y calendario desde `finishedAt`, aunque falten otras
   series; no significa sesión totalmente completada.
3. **Sesión de programa completada:** continúa siendo decisión exclusiva de
   `WorkoutNotifier`/las reglas de programa, no de Progreso. Sin cambios en
   recompensas, recordatorios, navegación de reanudación ni borradores.
4. **Día activo:** calendario, Resumen y frecuencia reciben el mismo conjunto
   de sesiones de actividad antes de aplicar sus ventanas; un día local se
   atribuye por `finishedAt` (aunque el entrenamiento comience antes de
   medianoche). No se cuentan registros con `finishedAt > now`, ni siquiera
   cuando su fecha local cae en **hoy**. Períodos comparativos y promedio
   de duración registrada aplican idéntico criterio de actividad.
5. **Historial:** los registros importados vacíos, anteriores o incompletos
   siguen disponibles con su ID original. No hay migración, modificación de
   Hive, sincronización cloud, borrado ni cambio de PR.
6. **Excepciones preservadas:** Ejercicios utiliza su contrato temporal
   histórico basado en `startedAt`. Medidas tiene rangos propios.
   Los datos sintéticos para revisar esta diferencia están documentados en
   `PROGRESS_SHARED_PERIOD_CONTRACT_20261103.md`.

## Criterios de aceptación

- Test Core `progress_effective_activity_contract_test.dart`: sesiones
  importadas sin series; solo calentamiento; series pendientes; set completado
  sin repeticiones; parcial con trabajo; peso corporal; cruce de medianoche;
  período actual/anterior y exclusión de futuro.
- Ejecutar tests de `calendar_heatmap_calculator`,
  `progress_metric_date_window`, `progress_recorded_duration_contract`
  y suites relacionadas, más iOS/Android/analyze en el espejo.
- Comparar SHA de **cada archivo cambiado** entre rama canónica y snapshot
  espejo, y fusionar tras CI verde del último SHA.
- QA física en claro/oscuro/OLED y fuente grande queda pendiente en QA-05/06;
  no atribuir estos resultados a CI.
- Revisar visualmente en la web y móvil que el término «sesión» signifique
  trabajo registrado; el historial completo sigue accesible.

**Estado:** implementación en rama, aún sin CI ni aceptación final.
