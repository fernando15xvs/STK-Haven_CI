# Coach Pro Fase 3 — agenda de tareas recurrentes

## Contrato de producto

La base ya contiene `stk_coach_tasks` con frecuencias `once`, `daily` y `weekly`, y un historial de ocurrencias realmente registradas por el cliente. Este bloque **no vuelve a crear** esa infraestructura.

Se añade una vista profesional de los **próximos 14 días**, paginada y ordenada en el servidor, sobre las tareas activas de una sola relación, usando `stk_task_due_on` (fuente de verdad). La operación no inserta ocurrencias ni ejecuta alarmas. Una fecha programada sin registro devuelve `status = null` y la interfaz muestra *sin registro*, nunca *omitida* o *incumplida*.

## Autorización y privacidad

- `stk_list_coach_pro_task_schedule` valida cuenta permanente, capability coach, acceso Coach Pro vigente, relación activa y consentimiento `assign_tasks` por cada llamada.
- Se filtra por **relationship_id, coach_user_id y client_user_id** antes de generar las fechas. Un entrenador nunca puede usar el UUID de otra relación.
- Ventana entre 1 y 14 días, con inicio restringido a fechas entre 30 días pasados y 90 futuros.
- Límite máximo de página 50, `offset <= 10000`; la aplicación usa 25. No expone instrucciones privadas de tareas ni check-ins.
- El cliente solo puede registrar una ocurrencia mediante su RPC previa `stk_set_coach_task_status`; consultar el calendario no crea registros.
- No se envían notificaciones ni se programan recordatorios automáticamente.

## Flutter

- La ficha Coach Pro, sección Tareas, abre **Agenda de próximas tareas**.
- Tarjetas de tarea con fecha, estado explícito, navegación al historial y paginación. Se recarga al volver de la ficha y al reanudar la app.
- Provider por sesión y relación con `autoDispose`, sin caché persistente.

## Pruebas

- pgTAP: ventanas/paginación, generación diaria/semanal, ausencia de escritura al leer, marca explícita del cliente, privacidad entre entrenadores, revocación de permisos, pausa y vencimiento de Coach Pro.
- Tests Dart de parsing estricto y ausencia de falsos incumplimientos.
- Solo ejecutar GitHub Actions en `STK-Haven_CI`. No fusionar ni desplegar nueva migración remota hasta validar CI verde.

## Pendientes del resto de Fase 3

Interacciones de gestión de recurrencias y edición/versionado, recordatorios opt-in con privacy-by-default, smoke en Android/iOS reales y accesibilidad.
