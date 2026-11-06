# GAM-01 — política conservadora de primer récord en sesión parcial

Fecha: 2026-11-05. Resuelto para implementación **sin cambiar la
semántica existente** bajo la instrucción de cerrar el bloque de tareas.

## Decisión adoptada: opción A

Permitir el logro único **first_pr** cuando una serie efectiva realmente
**completada** demuestra un récord, incluso si la sesión total es parcial.
Ese logro reconoce el **récord**, no premia la finalización de sesión.
El récord se persiste antes de marcar el logro, y la operación de logro
se espera con `await` antes de devolver el análisis.

**Separación obligatoria:** `addWorkoutSession`, XP por entrenamiento,
volumen de gamificación y rotación de programa solo ocurren cuando todas
las series efectivas de la sesión están completas. Una sesión parcial
permanece reanudable bajo el mismo ID. Un segundo análisis con un récord
ya registrado no genera nuevos eventos, y `first_pr` es idempotente.
Una serie omitida/fallida, en descanso, sin repeticiones o sin completar
no puede generar un récord.

## Regresiones

`pr_detector_test.dart` comprueba que un récord válido de serie
completada existe en una sesión parcial con otras series omitidas,
fallidas o pendientes; y que esas series incompletas no aportan PR.
`workout_recovery_contract_test.dart` comprueba mismo ID al reanudar
y rotación única. El proveedor de gamificación conserva la barrera de
completitud y la deduplicación por ID.

Si se decide en producto que **first_pr** debe esperar hasta completar
la sesión (opción B), eso será un cambio de política separado con nueva
prueba de recompensa diferida; no debe hacerse de forma implícita.
