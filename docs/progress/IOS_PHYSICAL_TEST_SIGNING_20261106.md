# STK Haven — instalar en iPhone y generar una IPA firmada

**Actualizado:** 2026-11-06 · **Objetivo:** prueba de la build
final de `STK-Haven/main` después de integrar PR #55.
No insertar credenciales ni perfiles Apple en repositorios, chats,
tickets, capturas o en el espejo público de CI.

## Lo que sí entrega GitHub Actions

En el espejo público `STK-Haven_CI`, el job
`iOS release + profile` compila `lib/main_ios.dart` con
`--dart-define=STK_PNG_PILOTS=true` y ejecuta
`flutter build ios --release --no-codesign`.
Empaqueta `Payload/Runner.app` como
`STK-Haven-unsigned.ipa`, comprueba ZIP/WidgetKit y publica
el artefacto `stk-haven-ios-unsigned`. El nombre `.ipa`
**no implica** que exista una firma válida.

**No intentar instalar esta IPA sin firmar** directamente desde
Archivos, AirDrop ni un servicio de instalación: iOS exige una
firma Apple y perfiles correctos.

## Preparación local en Mac (recomendada)

Requisitos: macOS con Xcode y sus herramientas, Flutter 3.38.9,
CocoaPods, acceso al repositorio privado, iPhone de prueba autorizado
y acceso legítimo a un equipo de Apple Developer capaz de firmar
Runner **y** la extensión WidgetKit con App Groups.

1. Obtener el `main` canónico ya fusionado (no el mirror CI).
2. En la raíz del proyecto: `flutter pub get --enforce-lockfile`.
3. En `apps/app_mobile/ios`: `pod install`.
4. Abrir `apps/app_mobile/ios/Runner.xcworkspace` en Xcode.
5. En el target **Runner** > Signing & Capabilities: seleccionar
   el equipo Apple del propietario y firma automática; conservar
   Bundle ID `com.FernandoSac.gymTracker`.
6. Repetir con el target **StkVerseWidget** y su Bundle ID
   `com.FernandoSac.gymTracker.StkVerseWidget`. Ambas firmas
   deben pertenecer al mismo equipo autorizado.
7. Verificar la capacidad **App Groups** en ambos targets:
   `group.com.FernandoSac.gymTracker` debe estar habilitada
   en ambos perfiles (los archivos entitlements ya la declaran).
   Si la cuenta/equipo no permite esta capacidad, gestionar
   el aprovisionamiento antes de continuar: no borrar la
   capacidad para maquillar una instalación.
8. Conectar el iPhone, confiar en el Mac, habilitar Developer
   Mode si iOS lo requiere y escoger ese iPhone como destino
   del esquema `Runner`.
9. Ejecutar desde Xcode (o desde `apps/app_mobile`:
   `flutter run --release -d <id-del-dispositivo>
   -t lib/main_ios.dart --dart-define=STK_PNG_PILOTS=true`).
10. Para generar una IPA **firmada** de instalación/distribución,
   seleccionar destino **Any iOS Device (arm64)**,
   **Product > Archive** y luego en Organizer
   **Distribute App** con el método válido para tu equipo
   (Development/Ad Hoc/TestFlight/App Store). Verificar
   que Runner y StkVerseWidget se firmen.
   Las instalaciones directas desde Xcode no requieren
   exportar primero una IPA.

**No** ejecutar certificados en el espejo público:
el CI deliberadamente trabaja sin credenciales de Apple.

## Evidencia de QA en iPhone

Registrar **modelo y versión de iOS**, versión/build,
SHA de commit de `main`, método de firma/distribución,
fecha, resultado de instalación y capturas con datos sintéticos.
Recorrer Resumen, Ejercicios, Músculos, Medidas, ficha técnica,
historial y entrenamiento reanudable; en claro/oscuro/OLED,
tamaño de texto 1,0/1,3/1,6, kg/lb y VoiceOver.
También revisar Reduce Motion, Safe Area y áreas de toque.
Usar la matriz `PROGRESS_2_DEVICE_QA_RUNBOOK_20261103.md`.

**Estado de QA-05/09:** NO EJECUTADO hasta recibir esta
evidencia física. No confundir un build iOS verde con una
prueba de instalación firmada.
