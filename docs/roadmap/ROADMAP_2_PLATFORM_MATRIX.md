# Roadmap 2.0 — Matriz de plataforma y perfil de release

Este documento fija la matriz objetivo de STK Haven Roadmap 2.0. Los valores se derivan de la configuración versionada del repositorio; las mediciones físicas se completan durante la auditoría final, no durante la implementación.

## Android

- Piso explícito: **Android 6.0 / API 23** (`apps/app_mobile/android/app/build.gradle.kts`).
- `compileSdk` y `targetSdk` continúan resolviéndose desde el Flutter SDK instalado y se registrarán con el SHA candidato durante la auditoría final.
- Java/Kotlin: **17**.
- Release nunca usa automáticamente la clave debug. Si `android/key.properties` no existe, el artefacto release queda sin firma de producción.
- Distribución prevista:
  - APK debug para smoke rápido.
  - APK release para validación local.
  - AAB release para distribución.
  - APK release `--split-per-abi` para sideload personal cuando convenga.

### Pruebas físicas obligatorias antes de release

En al menos un Android API 23+ de recursos modestos y un Android moderno:

1. cold start en profile/release;
2. abrir Inicio con historial grande;
3. iniciar/reanudar workout;
4. timer de serie e inter-side tras background;
5. recreación de proceso con draft activo;
6. notificaciones y permiso correspondiente;
7. entrada peso → reps → RIR;
8. scrolling de Biblioteca/Progreso;
9. memoria y frames con DevTools/Profile.

Objetivo de rendimiento: interacción habitual sin trabajo síncrono largo; 55–60 FPS como objetivo visual y evitar frames >32 ms en flujos frecuentes.

## iOS

- Deployment target versionado: **iOS 15.0** (`ios/Podfile`).
- El `post_install` también fija `IPHONEOS_DEPLOYMENT_TARGET = 15.0` para Pods.
- No se baja el target solamente para ampliar compatibilidad. Cualquier cambio futuro exige auditar todos los plugins y construir/probar en hardware real.

### Pruebas obligatorias en macOS/iPhone

1. `pod install`;
2. tests Flutter;
3. build release sin firma;
4. build/profile en iPhone físico compatible con iOS 15+;
5. cold start, memoria y frames;
6. background/resume de workout, timer y notificaciones;
7. Reduce Motion + Modo rendimiento Ahorro;
8. SafeArea en equipos con/sin isla/notch cuando haya hardware disponible;
9. Dynamic Type;
10. teclado numérico y formularios.

La validación iOS no puede darse por ejecutada desde Windows.

## Web / PWA

- Build predeterminado de release: Flutter web compatible (dart2js) con `--base-href /STK-Haven/`.
- Build WASM: candidato de comparación, **no reemplaza** el build predeterminado sin una medición favorable y sin conservar fallback.
- Service worker propio único: `apps/app_web/web/sw.js`.
- Cache actual de la rama Roadmap 2.0: `stk-haven-shell-v7`.
- Navegaciones, bootstrap, JS/WASM, manifest y manifests de assets usan estrategia network-first.
- Assets secundarios usan cache-first con revalidación.
- Al activar un worker nuevo se eliminan shells STK Haven anteriores y caches legacy de Flutter.
- Los servicios web de backup/CSV usan APIs web modernas; Roadmap 2.0 no debe introducir nuevos usos de `dart:html`.

### Comparación web final

Construir ambos artefactos desde `apps/app_web`:

```bash
flutter build web --release --base-href /STK-Haven/
flutter build web --release --wasm --base-href /STK-Haven/
```

Registrar para cada variante:

- tamaño total de `build/web`;
- tamaño del entry point principal;
- tiempo de carga inicial en navegador de referencia;
- tiempo hasta primera interacción;
- compatibilidad en navegador objetivo;
- warnings del compilador;
- comportamiento offline/upgrade.

El deploy a GitHub Pages continúa usando el **artefacto exacto previamente validado**. No se reconstruye después de validar para desplegar otro binario diferente.

## Breakpoints / responsive web a validar

Smoke funcional en al menos:

- 360 × 800 — móvil estrecho;
- 430 × 932 — móvil grande;
- 768 × 1024 — tablet;
- 1366 × 768 — laptop;
- 1920 × 1080 — desktop;
- 2560 × 1440 — ultrawide.

Para cada ancho: navegación, Programas, workout, unilateral I/D, Progreso/Inteligencia, Fe, Perfil, diálogos y herramientas; además navegación por teclado, foco visible y labels semánticos.

## Modo rendimiento

Los tres valores persistidos son:

- **Automático**: combina plataforma y preferencias del sistema;
- **Calidad**: conserva efectos visuales cuando el equipo puede sostenerlos;
- **Ahorro**: reduce animaciones, blur, elevaciones/transiciones y densidad de puntos antes de reducir funcionalidad.

El modo Ahorro nunca puede cambiar resultados de progresión, historial, timers, backup o datos registrados.

## Gate de release

Ningún perfil físico se sustituye por una prueba debug. Antes de fusionar Roadmap 2.0 a `main` deben existir resultados documentados para todos los pasos disponibles localmente y una anotación explícita de cualquier prueba pendiente por requerir macOS/hardware físico. La ausencia de hardware se registra como **pendiente**, nunca como prueba aprobada.
