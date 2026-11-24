# STK Haven — C.1.c.3: servicios de recordatorio nativo fuera de Core

PR canónica #57; Web pausada. No fusionar antes de validación.

## Entrega agrupada
- Los programadores de notificaciones para Fe, mensajes personales y Medidas se trasladan íntegros a `apps/app_mobile/lib/platform/reminders`.
- La zona horaria `stk_haven/timezone` pasa a `MobileLocalNotificationTimezone` y solo se usa dentro de Mobile, tanto en los 3 módulos nuevos como en las seis implementaciones Mobile de descanso, agua, pasos, Coach, hábitos y Coach Pro.
- Core conserva `VerseNotificationService`, `PersonalMotivationalReminderService` y `MeasurementReminderService` como fachadas Dart; modelos puros, consentimiento y preferencias se mantienen.
- iOS y Android instalan backends en el bootstrap compartido antes del `ProviderScope`.
- Pruebas de plugins de Fe y Medidas pasan de `packages/core/test` a `apps/app_mobile/test`; se mantienen assertions de hora local, permisos, capacidad iOS, fail-closed, cancelación, datos personales y notificaciones de otras familias. Nuevas pruebas Core verifican delegación sin SDK de notificaciones.
- Web queda congelada; falta de backend no activa recordatorios ni solicita permisos.
- No tocar IDs 1301/1302/1310–1357, 42901/42902/42910+, 1601; tampoco 998/999, 1001, 1102, 1201/1202, 41810–41812 ni hashes 200M/300M.
- Conservados `measurement_reminder_v1`, `measurement_reminder_scheduled_v1`, `verse_notifications_enabled`, cadencias y lógica de rollback.
- No cambios de Hive/Supabase, entrenamientos, backups ni onboarding.

## Aprobación / siguiente fase
- [ ] 7/7 del último mirror SHA y paridad de 20+ blobs.
- [ ] QA física iOS/Android, permisos/clock timezone, aviso con app suspendida, música externa, reinicio; no confundir CI con pruebas reales.
- [ ] C.2 migrar 52+ UI Core a Mobile y reubicar sus tests; conservar políticas de negocio en Core.
- [ ] C.3 eliminar Flutter del pubspec Core y cerrar imports visuales, incluidos providers e integraciones restantes, con allowlist vacía.
