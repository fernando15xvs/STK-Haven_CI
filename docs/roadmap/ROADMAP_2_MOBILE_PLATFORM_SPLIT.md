# Roadmap 2.0 — separación Android / iOS

## Objetivo

STK Haven mantiene **una sola aplicación Flutter y una sola lógica de negocio**, pero Android e iOS ya no comparten el mismo entrypoint de arranque ni el mismo archivo de inicialización de plataforma.

La separación evita acoplar el bootstrap de Android con el de iOS y permite optimizar permisos, notificaciones, background work y configuración nativa de cada sistema de forma independiente.

## Estructura

```text
apps/app_mobile/lib/
├── main.dart                         # alias local Android para Windows/flutter run
├── main_android.dart                 # entrypoint Android
├── main_ios.dart                     # entrypoint iOS
├── platform/
│   ├── android/
│   │   └── android_platform_services.dart
│   └── ios/
│       └── ios_platform_services.dart
└── shared/
    ├── app/
    │   └── stk_haven_app.dart        # MaterialApp/UI/lifecycle compartido
    └── bootstrap/
        └── mobile_app_bootstrap.dart # Supabase/Hive/ProviderScope compartido
```

## Qué queda compartido

- UI y navegación Flutter.
- Riverpod.
- modelos y reglas de negocio.
- workout, progreso, programas y recovery.
- Hive y repositorios compartidos.
- configuración común de Supabase.

Compartir estas capas evita duplicar funcionalidad y reduce el riesgo de que Android e iOS diverjan funcionalmente.

## Qué queda separado

### Android

`lib/main_android.dart` importa exclusivamente el bootstrap Android:

```text
platform/android/android_platform_services.dart
```

Este archivo es el punto donde deben vivir las decisiones específicas de Android: permisos, canales de notificación, WorkManager, alarms y futuras optimizaciones Android.

### iOS

`lib/main_ios.dart` importa exclusivamente el bootstrap iOS:

```text
platform/ios/ios_platform_services.dart
```

Este archivo es el punto donde deben vivir las decisiones específicas de Apple: permisos Darwin, background policy, Reduce Motion, Dynamic Type y otras integraciones iOS.

## Comandos oficiales

### Android debug

```powershell
flutter build apk --debug --target lib/main_android.dart
```

### Android release

```powershell
flutter build apk --release --target lib/main_android.dart
```

### Android AAB

```powershell
flutter build appbundle --release --target lib/main_android.dart
```

### iOS release

```bash
flutter build ios --release --no-codesign --target lib/main_ios.dart
```

### iOS profile

```bash
flutter build ios --profile --no-codesign --target lib/main_ios.dart
```

## `main.dart`

El entorno principal de desarrollo actual es Windows + Android. Para conservar `flutter run` sin parámetros, `main.dart` es un alias del entrypoint Android.

En macOS/iPhone debe usarse explícitamente:

```bash
flutter run --target lib/main_ios.dart
```

Los scripts oficiales de validación ya fuerzan el target correcto y no dependen de `main.dart`.

## Rendimiento

Esta separación reduce acoplamiento e inicialización cruzada, pero no sustituye las optimizaciones de renderizado. La fluidez Android depende también de:

- evitar filtros blur costosos;
- construir pestañas bajo demanda;
- reducir rebuilds de Riverpod;
- evitar trabajo de SQLite/background en el primer frame;
- mantener cálculos pesados fuera del camino crítico de UI.

Estas optimizaciones están siendo tratadas en conjunto con esta separación.

## Estado de validación

La arquitectura está implementada en `feat/roadmap-2-complete`.

Después de este cambio se debe volver a ejecutar la matriz local Roadmap 2.0. En Windows se validará Android; los builds iOS seguirán pendientes hasta ejecutarse en macOS.
