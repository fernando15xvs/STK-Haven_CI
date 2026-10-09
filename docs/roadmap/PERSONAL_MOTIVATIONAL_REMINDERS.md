# STK Haven — biblioteca de mensajes personales rotativos

## Función

- Ajustes → Notificaciones → **Mis mensajes personales**.
- Guardar hasta **24 mensajes** individuales; cada uno tiene **título** (hasta 80 caracteres) y **texto** (hasta 3.000 caracteres).
- Añadir, editar, quitar, reordenar y expandir cada tarjeta para leer el texto completo dentro de STK Haven.
- Cadencia global voluntaria cada **30 minutos** o **1 hora**. Los mensajes se intercalan por orden, una única notificación en cada intervalo.
- La configuración no se habilita sola. Incluye prueba individual, pausa inmediata y borrado total.

## Programación nativa

- Se programan **24** avisos diarios cuando la cadencia es de 60 min, o **48** cuando es de 30 min.
- Cada horario tiene un ID propio (42910–42957) y se repite **cada día** con `DateTimeComponents.time`, tanto en Android como iOS.
- En cada horario se selecciona un mensaje de la lista en orden circular tomando el siguiente horario como el primero tras guardar.
- **Límite real:** si el número de mensajes no divide exactamente los 24/48 horarios diarios, el turno vuelve a comenzar al final del día. Se siguen intercalando los mensajes; no se promete una secuencia sin reinicios a lo largo de varios días.
- Los horarios coinciden con la siguiente hora o media hora del reloj local; no necesariamente con los minutos exactos desde que se activó.
- Las restricciones de batería, permisos, Focus/No molestar o cambios de zona horaria pueden retrasar o silenciar una alerta. La programación depende del sistema operativo, no de tareas remotas.
- El máximo de 48 slots deja espacio para otras notificaciones en los sistemas con límites de pendientes, pero comprobar coexistencia en dispositivos físicos sigue siendo obligatorio.

## Privacidad

- Texto guardado en `personalRemindersBox_v1`, una caja local que **no forma parte** del backup de STK Haven, tampoco de la sincronización cloud.
- `showMessageInNotification=false` de fábrica. Con este ajuste, incluso los títulos son ocultos y se muestra un mensaje genérico.
- El opt-in separado para mostrar título y texto enseña **solo los primeros 120 caracteres** del cuerpo en la notificación; el texto de hasta 3.000 se lee en la app, no en la pantalla bloqueada.
- Ningún mensaje se envía al entrenador, a Supabase, a analítica o a terceros mediante este módulo.
- Hive no es almacenamiento cifrado por sí mismo; copias del sistema operativo podrían incluir archivos de la app. No prometer cifrado avanzado inexistente.
- Cada guardado cancela los IDs de la versión anterior (42901 y 42902) y los horarios reservados nuevos antes de reprogramar, sin interferir con otras notificaciones.

## Compatibilidad

- `PersonalReminderSettings.fromJson` admite el formato anterior con `message` y lo conserva como la primera tarjeta titulada **Mi primer mensaje**.
- Configuraciones inválidas, cantidades excesivas, texto corrupto o frecuencias no admitidas deshabilitan el envío (fail-closed).
- Web: vista informativa sin programación periódica, solo Android e iOS.

## Validación

- Pruebas Flutter del modelo: 24 mensajes, mensajes largos, títulos, orden alternado, consentimientos separados, lectura y conversión de configuración anterior.
- CI exclusivamente en `STK-Haven_CI`; nunca ejecutar GitHub Actions en privado.
- QA real pendiente: Android/iOS, sistema cerrado, noche completa, reinicio, permisos revocados, cambios de zona horaria, accesibilidad, límite de notificaciones de iOS y revisión del texto en lock screen.
- Los recordatorios son una herramienta personal de apoyo, no una intervención clínica ni garantía de recuperación.
