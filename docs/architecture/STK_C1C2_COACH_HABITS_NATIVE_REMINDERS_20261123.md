# C.1.c.2 — recordatorios de Coach y Hábitos solo en Mobile

**Rama canónica:** PR privada #57 DRAFT. **Espejo:** `STK-Haven_CI/main` solo para Actions; Web congelada.

## Separación realizada
- `CoachTaskNotificationService`, `HabitTaskNotificationService` y `CoachProLocalReminderService` conservan sus APIs estáticas públicas en Core como fachadas Dart puras, sin imports de Flutter.
- Los schedulers originales completos, con plugins, timezone y permisos, se trasladan a `apps/app_mobile/lib/platform/reminders/` y se registran en el bootstrap compartido antes de `runApp`.
- Sin adaptador Mobile instalado: `requestPermission` y `scheduleNext` devuelven false; `initialize`, `cancel` y `synchronize` son operaciones seguras sin efectos.
- Sin cambios de persistencia, privacidad, IDs de tareas, consumo de consentimiento, algoritmo de fechas, recompensas, supabase, Hive ni onboarding.

## Contrato de compatibilidad
- Coach Pro: mismos IDs **41810, 41811, 41812**, aviso sin datos personales, consentimiento explícito y repetición por día/hora.
- Coach tasks: hash de `task.id` a partir de **200000000** + módulo 100000000, mismas fechas `dueDates` y permiso voluntario.
- Habit tasks: hash de `task.id` a partir de **300000000** + módulo 100000000, misma programación recurrente diaria, mismas notificaciones de lectura.
- Los mensajes de Fe, preferencias personales y medidas aún son consumidores de `LocalNotificationTimezone` en Core; migrar esta inicialización requiere un bloque coordinado y nuevos tests.
- El caso de uso de hábitos continúa en Core; únicamente la integración con Flutter/OS pasa a Mobile.

## QA
- [x] Contratos Dart con dobles para argumentos, fechas, opt-in, permiso y cancelación sin plataforma.
- [x] Importaciones nuevas Core solo de modelos Dart propios, sin Web.
- [ ] Validar 7/7 jobs obligatorios en el último snapshot del espejo con paridad SHA de todos los archivos de esta entrega.
- [ ] QA física de Android+iOS: primer opt-in, actualizar/revocar permiso, reprogramar tarea, cancelar al archivar, cambios de hora/zona, app suspendida, textos privados en bloqueo y reinicio.
- [ ] Auditoría de importación transitiva tras migrar los consumidores restantes.
