# C.1.c.1 — recordatorios de hidratación y pasos en Mobile

- Core mantiene las APIs públicas originales de `HydrationReminderService` y `StepGoalReminderService` mediante puertos Dart, sin Flutter ni plugins.
- Las implementaciones originales se trasladan a `apps/app_mobile/lib/platform/reminders/`, registrando los backends antes de `runApp` para Android e iOS.
- Sin backend, Core falla de modo seguro: los permisos y scheduling devuelven false, initialize/cancel no-op.
- Preservados IDs 1102, 1201, 1202; canales, horarios, cadencia, textos, cancelación y petición voluntaria de permiso sin modificación.
- `LocalNotificationTimezone` sigue transitoriamente en Core: Fe, Coach, hábitos, Medidas y recordatorios personales aún utilizan el canal; migrarlo solo rompería sus pruebas de zona horaria.
- No hay cambios de Hive, Supabase, rutinas, preferencias persistidas, Web ni onboarding.

## Pruebas y criterios
- Test Core con spy de ambos puertos para argumentos, estado sin plataforma y cancelación.
- Verificar los siete trabajos de CI en espejo, incluidos Android/iOS, y paridad SHA de estos archivos.
- QA física pendiente: permisos reales, recordatorios después de reiniciar/cambiar fecha, desactivar alerta, bloqueo, ruido/música externa y diferencia de zona horaria.

## Siguiente
Migrar por grupos Fe, Coach, hábitos, medidas y mensajes personales con sus pruebas de plugins; finalmente el adaptador timezone. Mantener PR #57 DRAFT y espejo sin PR.
