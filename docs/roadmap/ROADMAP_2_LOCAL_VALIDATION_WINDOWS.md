# Roadmap 2.0 — Validación local en Windows

Este documento define el flujo oficial para validar Roadmap 2.0 en una máquina Windows sin depender de GitHub Actions.

## Rama candidata

La validación debe ejecutarse sobre:

```text
feat/roadmap-2-complete
```

Antes de comenzar, el árbol de trabajo debe estar limpio. El runner final aborta automáticamente si `git status --porcelain` devuelve cambios.

## Runner recomendado

Desde PowerShell, en la raíz del repositorio:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate_roadmap2_local.ps1
```

El runner registra el SHA exacto del candidato y ejecuta la matriz disponible en Windows.

## Matriz automática ejecutada en Windows

1. `flutter --version`.
2. `flutter pub get` del workspace.
3. `flutter analyze --no-fatal-infos`.
4. Suite completa de `packages/core`.
5. Suite completa de `apps/app_mobile`.
6. Android debug APK.
7. Android release APK.
8. Web release dart2js con `--base-href /STK-Haven/`.
9. Suite completa de `apps/app_web`, incluidos tests responsive/widget.
10. Android profile APK.
11. Android AAB release.
12. Android release APK `--split-per-abi`.
13. Preservación del artefacto web dart2js validado.
14. Build WebAssembly de comparación.
15. Restauración exacta del artefacto dart2js validado para Pages.
16. Comprobación de `index.html`, `flutter_bootstrap.js` y `sw.js`.

## Validaciones que no puede cerrar Windows por sí solo

- Build/profile iOS: requiere macOS.
- Perfil y pruebas físicas en iPhone.
- Perfil físico Android de memoria/jank/process recreation/notificaciones.
- Aprobación visual/golden cuando requiera inspección humana.
- Instalación PWA, offline, actualización de service worker y pruebas reales de navegador.
- Smoke tests funcionales manuales J–T.
- Regresión funcional histórica manual.
- Restauración real de backups representativos cuando requiera interacción con la aplicación.

Estas validaciones no dependen de GitHub Actions; se ejecutan localmente en el hardware/plataforma correspondiente.

## Criterio de éxito automático

Si el runner termina con:

```text
SUCCESS: Roadmap 2.0 local build/test matrix available on this machine passed.
```

la matriz automática disponible en esa máquina queda aprobada para el SHA mostrado al inicio.

Un fallo en cualquier comando detiene el runner inmediatamente y debe corregirse en `feat/roadmap-2-complete` antes de volver a ejecutar la matriz completa.

## Artefactos esperados

Después de una ejecución correcta deben existir, según la plataforma:

```text
apps/app_mobile/build/app/outputs/flutter-apk/
apps/app_mobile/build/app/outputs/bundle/release/
apps/app_web/build/web/
apps/app_web/build/web-wasm-roadmap2/
```

`apps/app_web/build/web/` queda restaurado al artefacto dart2js validado. El artefacto WASM se conserva por separado únicamente para comparación.

## Regla de cierre de Roadmap 2.0

Roadmap 2.0 se considera listo para merge únicamente cuando:

1. La matriz automática local correspondiente al candidato pasa completamente.
2. Las pruebas manuales aplicables de Android/web/PWA pasan.
3. iOS se valida en macOS antes de un release que incluya iOS.
4. No quedan regresiones críticas ni bloqueantes abiertas.
5. El SHA final validado coincide con el SHA que se pretende fusionar a `main`.

GitHub Actions no forma parte del criterio de cierre de este proyecto.
