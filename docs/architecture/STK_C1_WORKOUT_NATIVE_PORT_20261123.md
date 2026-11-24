# STK Haven — C.1: puerto de efectos nativos del entrenamiento

**Fecha:** 23/11/2026 · PR canónica #57 DRAFT · Web congelada · Modelo de datos intacto.

## Objetivo y arquitectura
- **Core**: `packages/core/lib/features/workout/application/workout_native_services_port.dart` contiene únicamente un contrato Dart y una implementación NoOp para pruebas/entornos sin iOS/Android. No usa `Widget`, `WidgetsBinding`, `MethodChannel`, `HapticFeedback`, `ThemeData` ni dependencias de Mobile/Web.
- **Core**: `active_workout_provider.dart` conserva la política del entrenamiento, temporizador relativo a `currentRestEndsAt`, estado, IDs, persistencia y permisos de recordatorios. Ahora invoca `WorkoutNativeServices` mediante Riverpod y **no importa `flutter/widgets.dart`, `flutter/services.dart` ni `WorkoutNotificationService`**.
- **Mobile**: `lib/platform/workout/mobile_workout_native_services.dart` ejecuta los cinco efectos: programar descanso OS, cancelarlo, programar/cancelar recordatorios de sesión inacabada, y emitir feedback de fin de descanso solo en primer plano.
- **Mobile**: `lib/shared/bootstrap/mobile_app_bootstrap.dart` inyecta `MobileWorkoutNativeServices` desde el `ProviderScope` común tanto para Android como para iOS.
- **Dependencia permitida**: Mobile → Core. Core no importa Mobile ni Web.

## Compatibilidad exacta del comportamiento
1. Al iniciar o restaurar un descanso, el adaptador llama al mismo `WorkoutNotificationService.scheduleRestTimerNotification` con **idéntico endTime e ID de sesión**; conserva AlarmManager, notificaciones 998/999, cola generacional y Live Activity iOS existentes.
2. Al saltar el descanso, deshacer, finalizar, cancelar o restaurar un plazo vencido, el adaptador usa exactamente la misma cancelación nativa de antes. La referencia al adaptador se conserva en el Notifier para que funcione durante `ref.onDispose`. Es reasignable si Riverpod reconstruye el Notifier.
3. Al llegar a cero, **solo si `AppLifecycleState.resumed`**, el adaptador cancela la alerta OS, activa el canal nativo `stk_haven/rest_tone` si el sonido está habilitado y aplica `HapticFeedback.mediumImpact()` si la vibración está habilitada.
4. Si la app está en segundo plano, la notificación del sistema sigue siendo la única fuente del aviso; no se ejecuta el tono en Dart.
5. Se conserva la política de **no invocar `SystemSound.alert`** cuando falle el canal nativo: podría detener la música del usuario.
6. No hay cambios en Hive, Supabase, modelos, temporizadores, cálculo de series, nutrición, onboarding, canales nativos de iOS/Android ni paquetes del proyecto.

## Pruebas y guardia
- [x] Dos tests Core del contrato Dart: NoOp y override Riverpod con una implementación falsa que preserva session ID, tiempos y preferencias de sonido/vibración.
- [x] Actualizar contrato Mobile `workout_rest_os_expiry_audio_contract_test.dart` para buscar el tono/ciclo de vida en el adaptador, comprobar inyección en el bootstrap y mantener assertions del receptor Android y Live Activity iOS.
- [x] Eliminar dos importaciones Flutter directas (`widgets.dart`, `services.dart`) del motor de entrenamiento; sin nuevos imports Core→UI, Core→Mobile/Web ni Mobile→Web.
- [ ] **CI del último HEAD**: Analyze/Core, Mobile tests, iOS build, Android artifacts y Supabase (7/7 obligatorio).
- [ ] QA física: iPhone y Android con YouTube Music, descanso activo, salto, navegación, app suspendida, notificación 0:00 y preferencias de sonido/vibración.

## Pendiente en C.1
El `WorkoutNotificationService` de 16 KB todavía **reside en Core y depende de plugins Flutter**. El adaptador Mobile delega temporalmente a ese servicio existente para evitar alterar la cola de cancelaciones/alarma y los call sites restantes en Ajustes y arranque de la app. En el siguiente subbloque se trasladará la implementación completa del servicio de notificaciones a Mobile (u otro adaptador puro de plataforma), manteniendo la política y sus modelos Dart en Core. **La arquitectura todavía NO se considera limpia.**

No migrar Web ni reabrir onboarding; no fusionar #57 sin autorización.
