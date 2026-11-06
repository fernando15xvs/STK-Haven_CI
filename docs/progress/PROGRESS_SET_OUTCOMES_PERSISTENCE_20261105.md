# DATA-09 — registro explícito de estados de series

Fecha: 2026-11-05. Preparado en PR #55 de forma acumulativa; **no integrar
a `main` hasta completar CI y la revisión de lote**.

## Contrato de datos

- `WorkoutSet.completed=true` significa **Completada**; prevalece sobre
  cualquier dato contradictorio y limpia `recordedOutcome` al completar.
- `WorkoutSet.completed=false` y `recordedOutcome=null` significa
  **Pendiente**. Este es el estado **de todos los históricos antiguos**
  sin evidencia; no inferir fallida a partir de RIR=0, carga=0, falta de
  repeticiones, pausa omitida o entrenamiento parcial.
- Solo la selección voluntaria **Omitida** registra `'skipped'`.
- Solo la selección voluntaria **Fallida** registra `'failed'`.
- **Pendiente** borra expresamente la clasificación previa, sin borrar
  peso/repeticiones; completar la serie limpia la evidencia automáticamente.
- Estados no reconocidos se muestran conservadoramente como Pendiente.

## Compatibilidad

Se agrega `HiveWorkoutSet.@HiveField(16)` **opcional**, sin reutilizar
IDs, sin cambiar los 16 campos anteriores, sin nueva caja Hive y sin
esquema remoto. Adaptador `hive_workout_session.g.dart` lee campo
ausente como `null`. El backup JSON v11 conserva un campo opcional
`recordedOutcome`; backups anteriores sin ese campo siguen admitidos.
Los borradores activos se serializan igual. No hay migración destructiva
ni reclasificación retroactiva.

La ruta móvil y la web presentan la opción explícita por serie.
La opción no aparece para una serie unilateral con un lado ya realizado
para no etiquetar un trabajo parcial real como omitido o fallido.
«Omitir» del descanso NO modifica el estado de la serie.

## Matriz

Pruebas de dominio: cuatro estados, RIR/carga históricos, restablecimiento
y limpieza al completar. Pruebas Hive: borrador activo, historial y mismo
ID. Pruebas backup: v8 legible, formato v11 conserva saltos/fallos.
Pruebas UI: etiquetas en historial y estado seleccionable.

**Criterio de integración:** revisión de cambios y 7/7 trabajos del CI
canónico ejecutados exclusivamente en el espejo, SHA de blobs idénticos.
No afirmar QA en dispositivo ni cierre total antes de evidencia.
