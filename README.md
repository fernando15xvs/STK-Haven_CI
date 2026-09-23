# STK Haven

STK Haven es una aplicación Flutter de entrenamiento, progreso y bienestar personal con clientes separados para móvil y web y una capa de lógica compartida.

## Estructura

```text
apps/
  app_mobile/   Android + iOS con entrypoints separados
  app_web/      Web responsive / PWA
packages/
  core/         dominio, persistencia y servicios compartidos
supabase/
  functions/    backend seguro de Haven Faith
  migrations/   esquema y rate limiting
```

El `pubspec.yaml` de la raíz define un Dart workspace. No es una aplicación ejecutable.

La aplicación móvil comparte UI y lógica de negocio, pero Android e iOS tienen bootstrap independiente:

```text
apps/app_mobile/lib/main_android.dart
apps/app_mobile/lib/main_ios.dart
```

## Preparación del workspace

Desde la raíz:

```bash
flutter pub get
flutter analyze --no-fatal-infos
```

### Android / iOS

```bash
cd apps/app_mobile
flutter pub get
flutter test
```

Android:

```bash
flutter run --target lib/main_android.dart
flutter build apk --debug --target lib/main_android.dart
flutter build apk --release --target lib/main_android.dart
```

En el entorno Windows/Android actual, `flutter run` sin target sigue funcionando porque `lib/main.dart` es un alias de `main_android.dart`.

iOS:

```bash
flutter run --target lib/main_ios.dart
flutter build ios --release --no-codesign --target lib/main_ios.dart
```

El build de iOS requiere macOS/Xcode/CocoaPods.

La separación completa del bootstrap móvil está documentada en:

```text
docs/roadmap/ROADMAP_2_MOBILE_PLATFORM_SPLIT.md
```

### Web

```bash
cd apps/app_web
flutter pub get
flutter build web --release
flutter run -d chrome
```

### Core compartido

```bash
cd packages/core
flutter test
```

El workflow de GitHub está configurado para análisis, tests y builds independientes de core, Android, iOS y Web. Para Roadmap 2.0 la validación autoritativa sigue siendo local mientras no se utilicen minutos de GitHub Actions.

## Haven Faith / IA

Haven Faith usa este flujo:

```text
Flutter -> Supabase Auth -> Edge Function haven-faith-ai -> Gemini
```

La aplicación no contiene la API key de Gemini ni una clave secreta de Supabase. El cliente solo contiene la URL del proyecto y la `publishable key`, que son configuración pública de cliente.

La configuración pública está en:

```text
packages/core/lib/core/config/supabase_config.dart
```

Puede sustituirse al compilar:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

La Edge Function está versionada en `supabase/functions/haven-faith-ai/index.ts`, exige JWT y mantiene `GEMINI_API_KEY` exclusivamente en el backend.

### Configuración obligatoria en Supabase

1. Habilitar **Anonymous Sign-Ins** en Authentication > Providers.
2. Crear el secreto `GEMINI_API_KEY` con una clave que nunca haya sido distribuida dentro del cliente.
3. `GEMINI_MODEL` es opcional; si no se define se usa el modelo configurado por defecto en la función.

No reutilizar una clave de Gemini que haya estado anteriormente embebida en el cliente.

## Firma de Android release

La configuración vive dentro de la aplicación móvil:

```bash
cd apps/app_mobile
cp android/key.properties.example android/key.properties
```

Guarda el keystore localmente y completa `android/key.properties`. Los archivos de firma (`key.properties`, `.jks`, `.keystore`) están excluidos de Git.

Comportamiento actual:

- si `android/key.properties` existe, el build release usa la firma privada configurada;
- si no existe, el build release utiliza la firma debug únicamente para permitir instalación y pruebas locales.

Un release firmado con la clave debug **no es apto para Play Store ni distribución definitiva**. La publicación final debe usar un keystore privado de producción.

## Notificaciones

Android declara los permisos y receivers requeridos para notificaciones, reinicio y alarmas. Los permisos de notificación se solicitan cuando se utiliza la función correspondiente, no al iniciar la aplicación.

El temporizador de descanso intenta utilizar una alarma exacta en Android y utiliza una alarma inexacta como fallback cuando no existe autorización.

iOS utiliza capacidades del sistema para notificaciones y trabajo en segundo plano. El horario real de ejecución de Background Fetch es administrado por iOS y no debe considerarse una alarma exacta.

El arranque de estos servicios se mantiene aislado por plataforma en `lib/platform/android/` y `lib/platform/ios/`.

## Datos locales y migraciones

Las migraciones son fail-closed: si falta una migración necesaria, STK Haven no marca la base como actualizada.

La gamificación registra los IDs de entrenamientos ya procesados para evitar duplicar XP o volumen durante reintentos. Los backups validan el esquema y no pueden reducir la versión instalada de la base de datos.

## Seguridad y limpieza del repositorio

- No agregar `.env` como asset de Flutter.
- No guardar tokens, API keys secretas, contraseñas ni keystores en Git.
- Nunca usar una `secret key` o `service_role` de Supabase en el cliente.
- `**/build/`, `supabase/.temp/` y otros artefactos generados están excluidos del repositorio.
- Antes de fusionar a `main`, ejecutar la matriz local de validación y completar las comprobaciones manuales pendientes.
