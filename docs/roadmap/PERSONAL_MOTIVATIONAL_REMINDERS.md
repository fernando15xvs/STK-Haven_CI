# STK Haven — recordatorios personales voluntarios

## Alcance

Pantalla **Perfil / Ajustes / Notificaciones / Mi recordatorio personal**. El usuario escribe su propia frase y configura una notificación local recurrente **cada 30 o 60 minutos**. Los avisos comienzan tras guardar y activar (no inmediatamente), se pueden probar manualmente, pausar o eliminar en cualquier momento. Sin registro de cuentas, coach, salud ni historial de recaídas.

## Privacidad y seguridad

- El texto reside en la caja Hive independiente `personalRemindersBox_v1`; no se integra en `app_settings`, `BackupService` o la sincronización de copias cloud.
- No hay llamadas HTTP, tablas en Supabase, publicidad, analítica ni contenido dirigido al coach.
- De fábrica `enabled=false` y `showMessageInNotification=false` (pantalla bloqueada muestra un aviso **genérico**, no el texto sensible).
- Mostrar el mensaje en notificaciones requiere una decisión separada; la pantalla avisa que podría ser visible en la pantalla bloqueada.
- Hasta 280 caracteres, validación de control chars, cadencia estrictamente 30/60 y parsing fail-closed.
- Botones Pausar y Borrar cancelan únicamente los IDs 42901/42902 de este módulo; no tocan otros recordatorios.
- Solicitud del permiso de notificaciones solo al pulsar Guardar y activar / Enviar prueba.
- Android/iOS: `periodicallyShowWithDuration` + `inexactAllowWhileIdle` en Android. No se solicitan alarmas exactas. La programación es nativa y puede seguir cuando la app se cierra (dependiente de OS).
- No está disponible en web.

## Limitaciones declaradas

- El sistema operativo puede retrasar el intervalo por restricciones de batería, modos de concentración, permisos y cambios de política. No prometer puntualidad al minuto.
- Hive de aplicación tiene acceso limitado por sandbox de sistema, pero no es almacenamiento criptográfico; el mensaje sigue siendo dato privado en el dispositivo y las copias de seguridad del **propio sistema operativo** pueden gestionarlo independientemente de STK Haven.
- No asegura recuperación de ninguna adicción. Debe combinarse con apoyos elegidos por el usuario cuando corresponda.
- Verificar en Android/iOS reales: permisos, avisos después de cerrar la app, reinicio, 30/60 min, desactivación inmediata, visualización en pantalla bloqueada, accesibilidad y reinstalación.

## CI

Únicamente el espejo público `STK-Haven_CI`. No ejecutar GitHub Actions en el repositorio privado ni fusionar a main sin CI 6/6 verde. No hay migraciones ni despliegues remotos.
