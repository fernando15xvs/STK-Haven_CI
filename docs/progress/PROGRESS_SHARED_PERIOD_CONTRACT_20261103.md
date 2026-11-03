# Progreso 2.0 — Contrato de período compartido (UX-11)

**Fecha:** 2026-11-03. **Rama principal:** `feat/progress-shared-period-20261103`.
**SHA base:** `084178fac93c0a0e51d8be1796c38991f156ace1` (STK-Haven/main).
**Alcance:** solo Resumen, Ejercicios, Músculos y el selector superior.
**CI:** `STK-Haven_CI` sirve únicamente para ejecutar GitHub Actions; no se crea un PR adicional allí. Se publica el snapshot verificado en el `main` del espejo para activar el workflow `push: main` y se comprueban SHA/archivos, antes de integrar el **único PR** canónico.

## Selección y presentación

- **Una sola selección `TimeFilter`: 7D/1M/3M/1A** mediante `timeFilterProvider`, mostrada una vez en la parte superior de Progreso para Resumen/Ejercicios/Músculos. Se mantiene durante el cambio de pestañas.
- El selector se desplaza horizontalmente a 320 px y con texto 160 %, **sin reducir Outfit para forzar una sola fila**.
- **Medidas conserva su propio período**, sin mostrar el selector de estadísticas: sus intervalos y el origen de medidas corporales no son equivalentes a sesiones.
- **Ficha → Rendimiento enfocado** y la ruta heredada `ProgressIntelligencePage` conservan su selector local `30 días/90 días/Todo`, para no perder la vista completa del ejercicio.

## Ventana y excepciones honestas

- `TimeFilter.startDateAt(now)` calcula el instante de inicio a partir de una referencia única de 7/30/90/365 días. No hay porcentajes ni series inventadas al cambiar el período.
- **Resumen:** sesiones atribuidas a **`finishedAt`**; el calendario visualiza días locales y sus comparaciones respetan su contrato de sesiones efectivas.
- **Ejercicios:** métricas atribuidas a **`startedAt`**, como ya especifican `ExerciseProgressCalculator` e índice de historial. Para evitar cambiar registros, una sesión que cruza medianoche puede aparecer en fechas diferentes respecto a Resumen. Se informa de esa excepción en la pantalla; no se oculta.
- **Músculos:** series registradas atribuidas al final de la sesión, como en Resumen. La comparación entre las **dos últimas semanas completas** es deliberadamente independiente del selector: se explica en la propia tarjeta.
- Los datos del panel Ejercicios utilizan el caché indexado: las ventanas se redondean a un minuto para evitar nuevas claves por cada pulsación; el límite superior incluye el minuto en curso y excluye días futuros.
- Cambiar de período no altera ID, sesión parcial, datos Hive, PR históricos, rutina, STK Motivation, programa ni recompensas.

## Pruebas de este incremento

1. `packages/core/test/features/progress/application/progress_period_contract_test.dart` comprueba la misma referencia para los cuatro filtros.
2. `apps/app_mobile/test/features/progress/progress_shared_period_test.dart` verifica 320 px, texto 1.6, claro/oscuro, cambio 1M→1A→7D, opción «Todo» local y ausencia de excepciones de render.
3. Mantener `apps/app_mobile/test/muscle_balance_panel_test.dart`, `progress_unified_exercises_test.dart`, casos de historial completo y regresiones existentes.
4. Exigir CI completo (Core, móvil, Android, iOS, Supabase, anatomía, Motivation) en snapshot del espejo, **sin confundirlo con QA física**.

## Pendiente explícito

- DATA-07/08: definición final de sesiones parciales, duración registrada, calendario y cruzar medianoche.
- QA-05/06: iPhone/Android físicos en OLED/tema oscuro, acentos y texto grande.
- UX-11 solo puede marcarse terminada tras CI del último SHA y fusión canónica.
