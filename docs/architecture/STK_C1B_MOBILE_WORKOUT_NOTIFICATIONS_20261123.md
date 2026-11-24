# STK Haven — C.1.b: implementación de notificaciones solo en Mobile

Fecha: 23/11/2026 · PR canónica #57 (DRAFT) · Web congelada.

## Qué se separó

- **Core**: `packages/core/lib/core/services/workout_notification_service.dart` es ahora una fachada Dart **sin Flutter, UI, plugins, Hive ni canales nativos**. Define `WorkoutNotificationBackend` e invoca el backend registrado por Mobile. Si no se registra (por ejemplo, entorno de test o Web congelada), el backend seguro no produce efectos ni afirma permisos concedidos.
- **Mobile**: `apps/app_mobile/lib/platform/workout/mobile_workout_notification_service.dart` contiene **la implementación original íntegra** de `WorkoutNotificationService`, ahora llamada `MobileWorkoutNotificationService`, con sus mismas colas estáticas, identificadores de notificación y opciones de sonido, alarma Android, zona horaria y Live Activity iOS.
- **Mobile**: `MobileWorkoutNotificationBackend` adapta el contrato Dart de Core a la implementación concreta. `mobile_app_bootstrap.dart` lo registra **después de inicializar Hive y antes de runApp**, para ambos entrypoints nativos.
- El adaptador `MobileWorkoutNativeServices` y los inicializadores `platform/android` y `platform/ios` usan directamente esa misma implementación Mobile, de manera que todos comparten cola, IDs y generación de cancelación. La página Notificaciones y los ajustes de Core continúan utilizando la fachada Dart; **no importan Mobile**.

## Comportamiento preservado

- Descanso: ID 998 para cronómetro silenciado, 999 para aviso final, `timeoutAfter`, receptor nativo Android `stk_haven/rest_expiry`, cola `_restQueue` y `_restGeneration` y Live Activity iOS.
- Sonido de fondo: `AudioAttributesUsage.notificationEvent` y canales versionados v2; sonido foreground del puerto C.1.a mediante `stk_haven/rest_tone`, **sin fallback de alerta que robe foco a otras apps de música**.
- Recordatorio diario: misma hora/minuto, ID 1001, permiso opcional y cancelación.
- Sesión sin terminar: IDs 1041/1042, política +3h/+24h, mismos mensajes y cola para no pisar eventos.
- Si falla un plugin o se revoca un permiso, la inicialización reintenta sin impedir el entrenamiento y la cancelación de alarma mantiene sus fallbacks.
- No se modifican `SettingsState`, formato de preferencias, `WorkoutSession`, IDs persistidos, Hive, Supabase, rutinas, backups, onboarding ni el código de Web.

## Pruebas
- [x] Pruebas Core del contrato de la fachada, incluyendo backend falso, configuración diaria, IDs de sesión, cancelación y ausencia de plugin real.
- [x] Actualizar pruebas Mobile de cronómetro, sonido, alarmas, Live Activity e inicialización para leer la implementación en Mobile; mover el contrato de plugin que estaba erróneamente en Core.
- [x] Ambas plataformas inicializan el mismo backend antes del árbol Riverpod; no se tocan canales Kotlin/Swift.
- [ ] Analizar/tests del último HEAD y **CI 7/7 en verde**; verificar el resultado de arquitectura (disminución de deuda, sin regresiones).
- [ ] QA física iOS/Android con música externa, 0:00, +15/+30, Omitir, finalización, modo background y reanudación.

## Próximo trabajo arquitectónico

`LocalNotificationTimezone`, recordatorios de agua, pasos, Fe, Coach y hábitos todavía tienen implementación Flutter en Core. **Se migrarán en bloques posteriores**, compartiendo contratos y sin perder programaciones. La migración C.1.b no significa que Core ya esté libre de todas las dependencias Flutter. Tampoco se adapta la Web pausada.
