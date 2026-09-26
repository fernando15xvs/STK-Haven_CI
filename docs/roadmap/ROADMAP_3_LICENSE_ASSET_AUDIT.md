# Roadmap 3.0 — Auditoría de licencias y assets

Fecha: 2026-09-25

## Alcance

Revisión estática del árbol versionado usado por Android, iOS y Web antes del gate local final.

## Assets propios del producto

- Iconos y variantes de launcher/splash bajo `apps/app_mobile/assets/imagenes/` y los catálogos nativos iOS/macOS se consideran assets del producto STK Haven.
- `apps/app_web/assets/imagenes/slf_logo.png` y `apps/app_mobile/assets/imagenes/slf_logo.png` forman parte del branding versionado del producto.
- No hay fuentes tipográficas de terceros versionadas en el repositorio; la UI usa Material/Cupertino y fuentes del sistema.

## Asset de terceros versionado

- El único asset de procedencia no demostrada detectado (`apps/app_mobile/assets/lottie/confetti.json`) no tenía referencias de código y fue eliminado junto con el bundle/dependencia `lottie`; no se distribuirá.

## Dependencias

Las dependencias Dart/Flutter se resuelven mediante `pubspec.yaml` / lockfile y sus avisos de licencia se integran en el mecanismo de licencias de Flutter cuando los paquetes los publican correctamente. La auditoría local final debe abrir la pantalla de licencias/avisos de la aplicación si está expuesta y confirmar que no haya un paquete sin atribución esperada.

## Gate

- [x] No se detectaron fuentes de terceros copiadas dentro del repositorio.
- [x] Se inventariaron los assets estáticos versionados relevantes.
- [x] Asset `confetti.json` de procedencia no demostrada retirado del producto y dependencia Lottie no usada eliminada.
- [ ] Smoke local de avisos/licencias en Android/iOS/Web antes del cierre H.

Este documento no sustituye asesoría legal; funciona como inventario técnico para el release gate.
