# Progreso 2.0 — DATA-09: evidencia del estado de cada serie

**Fecha:** 2026-11-04 · **Alcance:** dominio sin migración y presentación del historial.

## Hecho verificado

El modelo `WorkoutSet` persistido conserva `completed: bool`, datos de
carga/repeticiones/RIR, `WorkoutSetType` y marcadores por lado.
**No registra intención de omitir una serie ni intento fallido.**
La acción «Omitir» identificada en la pantalla del entrenamiento
**omite el descanso del cronómetro**, no la serie. El cierre parcial
de una sesión tampoco es evidencia de intento o fracaso.

Un modelo que solo contiene `completed=false` **no distingue**
una serie pendiente de una omitida o fallida. Ni peso cero, ni RIR=0,
ni una extremidad completada justifican inferir ese estado.

## Contrato explícito y compatible

`WorkoutSetRecordStatusPolicy.fromSet(set)` resuelve estados existentes
conservadoramente:
- `completed=true` → **Completada**.
- `completed=false` → **Pendiente**.

`WorkoutSetOutcomeEvidence.skipped/failed` permite presentar **Omitida** o
**Fallida** únicamente si el consumidor aporta esa evidencia explícita.
El historial no la tiene hoy: por tanto, **no pasará ninguna evidencia por
defecto** ni inventará el estado. Un registro `completed=true` siempre
se conserva completado incluso si un consumidor pasa una etiqueta
contradictoria.

`ExerciseHistorySetRow` acepta `recordedOutcome` opcional, con badge
`Pendiente/Omitida/Fallida` y `AppColors.textSecondary/warning/error`.
`Completada` sigue mostrando el valor sin badge redundante. Todas las
etiquetas usan Outfit y tokens, sin tachar como «fallida» una serie
no realizada. No se modifican los cálculos históricos ni los filtros.

**No se toca** `WorkoutSet`, serialización Hive, esquema Supabase,
backups, historiales existentes ni lógica de recompensa. Implementar un
control del usuario para marcar «Omitida/Fallida» y guardarlo requerirá
un contrato separado de serialización compatible, migración estudiada
y pruebas de recuperación de backups; no se realizará sin él.

## Validación y criterio de cierre

- Pruebas Core: `completed` frente a `pending` histórico, valores
  cero, RIR y unilaterales; estados explícitos distintos cuando existe
  evidencia, sin cambios de datos persistidos.
- Pruebas UI: 320 y 390 px, claro/oscuro OLED, 160 % de texto,
  contraste >= 4,5:1 y badges/no badge de cada estado.

**DATA-09 continúa abierta hasta que exista almacenamiento seguro,
evidencia y ruta real de marcado para «omitida/fallida» o una decisión
explícita de producto de mantener solo estados verificables.** Este
bloque resuelve la ambigüedad de presentación y prueba los límites del
dato actual, pero no finge persistencia de cuatro estados. El merge
requiere 7/7 trabajos obligatorios en CI espejo y paridad exacta SHA
con la fuente privada. QA física y firma Apple siguen abiertas.
