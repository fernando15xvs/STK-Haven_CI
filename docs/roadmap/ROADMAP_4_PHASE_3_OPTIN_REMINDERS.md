# Coach Pro Fase 3 — recordatorios locales voluntarios

## Alcance y consentimiento

- Los recordatorios se configuran **solo por el cliente** en la pantalla de check-ins de Android/iOS.
- Aceptar una frecuencia de check-ins **nunca activa notificaciones**; el switch está apagado por defecto.
- El cliente elige hora local (07:00–22:00) y habilita expresamente el permiso del sistema.
- La propuesta de días (1–3) debe estar aceptada y en su revisión actual. Una propuesta nueva del entrenador invalida automáticamente el consentimiento anterior en el servidor.
- Solo puede haber una relación con recordatorios activos por cliente.
- El entrenador no puede activar, leer ni editar este permiso por su cuenta.
- La desactivación del switch cancela las alarmas locales reservadas, incluso cuando ya no esté aceptada la propuesta.

## Privacidad

- En pantalla bloqueada **solo** se usa `STK Haven` y un texto genérico. No hay nombres, objetivos, notas, salud, rutinas, scores, nombres de tareas ni identificadores.
- Los avisos se programan **localmente** mediante `flutter_local_notifications` con el modo inexacto para los días aceptados.
- No se envía Web Push ni se crean registros de envío, jobs remotos, notificaciones de Coach Pro al entrenador ni ocurrencias de tareas.
- La tabla `stk_coach_pro_reminder_opt_ins` tiene RLS y no otorga SELECT/INSERT/UPDATE a clientes: únicamente funciones RPC autenticadas con comprobación de titularidad, relación activa, permisos `view_checkins` y `assign_tasks`, Coach Pro y revisión del consentimiento.
- En lectura, una relación revocada, pausada, un plan expirado o una revisión reemplazada devuelven `enabled=false`. La app reconcilia el plan local cuando se abre la pantalla o vuelve de segundo plano.
- **Límite reconocido:** iOS/Android guardan notificaciones programadas localmente; una revocación remota mientras la aplicación está completamente cerrada no puede retirar instantáneamente las alarmas sin infraestructura push/borrado remoto. Por eso el contenido es genérico y el estado se revalida cuando el usuario vuelve a la pantalla. No se presenta como sincronización instantánea entre dispositivos.

## Validación

- Test pgTAP con defecto OFF, consentimiento independiente, modificación de cadencia, concurrencia por cliente, multi-coach, intruso y opt-out.
- Parsing Dart estricto y prueba del contenido genérico de notificaciones.
- Flutter, Android/iOS y DB+RLS exclusivamente en `STK-Haven_CI`.
- Sin fusionar ni desplegar la migración remota hasta CI público 6/6 verde.

## Después de este bloque

Cobertura de restauración/cierre de sesión para todas las notificaciones locales, UX en dispositivos físicos y regresiones de cambio de huso horario; accesibilidad y auditoría final antes de dar por terminada Fase 3.
