# STK Haven — Coach Pro Fase 3: frecuencia de check-ins con consentimiento

Estado: **bloque de desarrollo pendiente de CI público**. Fuente `STK-Haven`, CI exclusivamente en `STK-Haven_CI`.

## Qué añade

- Entrenador con Coach Pro vigente puede **proponer** 1–3 días por semana en una relación activa que autorizó `view_checkins` y `assign_tasks`.
- El cliente puede **aceptar, rechazar o desactivar** su frecuencia. Una nueva propuesta del entrenador invalida la aceptación anterior.
- El estado se lee mediante RPC y se bloquea inmediatamente cuando se revoca alguno de los permisos, se pausa la relación o expira el plan del entrenador.
- Cada escritura avanza una revisión y exige el número de revisión observado, de modo que las decisiones sobre propuestas antiguas fallan de manera segura.
- No se cambia el historial de check-ins ni la RPC de registro: el cliente sigue pudiendo enviar check-ins voluntariamente según el consentimiento actual.

## Privacidad y límites

- Tabla `stk_coach_pro_checkin_cadences` con RLS habilitada y **sin grants directos** al cliente; acceso exclusivamente por RPC con identidad permanente, pertenencia y permisos.
- No incluye notas de salud, diagnóstico, inferencias automáticas, datos clínicos ni contenidos de otros entrenadores.
- Las preferencias **no generan recordatorios, notificaciones, alarmas ni tareas automáticamente**. Este bloque no es un sistema de notificaciones ni un mecanismo de seguimiento obligatorio.
- No modifica el estado del cliente ni sus entrenamientos sin permiso explícito.
- Sin despliegue a Supabase remoto hasta completar CI y acordar la estrategia de migración.

## Integración Flutter

- Desde la ficha Coach Pro, sección Check-ins, se ofrece la propuesta cuando están visibles ambos permisos.
- Desde la pantalla del cliente de check-ins se puede abrir la propuesta, aceptarla o desactivarla.
- El proveedor está aislado por identidad y relación; consulta permisos al servidor en cada carga. Respuesta inválida se rechaza sin fabricar fechas o valores.
- Pruebas pgTAP adversariales con revocación, caducidad, otros entrenadores y token de revisión; tests de parsing Dart.

## Próximas tareas de Fase 3

- Borradores y edición de plantillas programables, operaciones de tareas recurrentes y adherencia contextual.
- Recordatorios únicamente cuando exista consentimiento opt-in independiente y configuración de privacidad de notificaciones.
- Pruebas de dispositivos reales, UX de errores y rendimiento con cartera grande.
