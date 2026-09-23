# STK Haven — Auditoría de bloques pendientes

Fecha de corte: 2026-09-02
Roadmap fuente: issue #8

## Estado general

Las fases **A, B, C, D, E, F, G y H** están implementadas. La Fase H fue validada completamente por el workflow #284 sobre `5933161625095af2bb8fa73b2ab79aa0e48457a8`:

- `flutter analyze` ✅
- tests de `core` ✅
- tests mobile ✅
- Android debug APK ✅
- Android release APK ✅
- iOS release sin firma ✅
- Web release para GitHub Pages ✅

La **Fase I está implementada en `feat/roadmap-i-platform`**, que incluye también la Fase H validada, pero por decisión operativa no se ejecutará otro GitHub Actions: debe pasar la misma matriz de validación **local** antes de fusionarse con `main`.

## Fase G — Herramientas — cerrada

- [x] Calculadora 1RM compartida en `core`.
- [x] Temporizador independiente fuera de sesión.
- [x] Accesos inteligentes según el ejercicio.
- [x] Calculadora de discos y conversión kg/lb integradas.

## Fase H — Fe y bienestar — cerrada

- [x] Historial de reflexiones.
- [x] Notas personales de reflexión editables/eliminables.
- [x] Acciones rápidas de Haven Faith.
- [x] Biblia, reflexión diaria, Haven Faith y favoritos.

El historial y las notas viven en `metadata` Hive, por lo que forman parte del backup/restauración existente sin adapter ni migración local adicional.

## Fase I — Plataforma — implementación terminada / validación local pendiente

### PWA instalable y offline-first

- [x] Manifest PWA completo con scope/start URL relativos para GitHub Pages.
- [x] Iconos normales y maskable.
- [x] Service worker propio (`apps/app_web/web/sw.js`).
- [x] App shell precacheado y recursos Flutter cacheados dinámicamente.
- [x] Navegación con fallback offline a `index.html`.
- [x] Estrategia de actualización que elimina cachés antiguas de STK Haven.

La persistencia funcional continúa en Hive/local storage; el service worker no intercepta peticiones externas a Supabase.

### Sincronización opcional Supabase entre dispositivos

- [x] La app sigue siendo local-first y no exige cuenta.
- [x] Cuenta opcional por correo/contraseña separada de la sesión anónima usada por Haven Faith.
- [x] Subir copia del dispositivo manualmente.
- [x] Restaurar copia de nube solo tras confirmación explícita.
- [x] Reutilización de `BackupService` y su restauración transaccional/rollback.
- [x] Estrategia de conflictos explícita: `Subir` = local gana; `Restaurar` = nube gana; sin merge silencioso.
- [x] Tabla Supabase de una copia por usuario con RLS y rechazo de sesiones anónimas.

Requisito de despliegue: aplicar `supabase/migrations/20260902203000_stk_haven_cloud_backups.sql` al proyecto Supabase antes de usar la sincronización remota.

### Notificaciones locales configurables

- [x] Reflexión diaria existente conservada.
- [x] Recordatorio diario de entrenamiento configurable.
- [x] Selector de hora.
- [x] Permisos solicitados al activar la función, no en el arranque.
- [x] Reprogramación al iniciar Android/iOS sin volver a pedir permisos.
- [x] Stub seguro en web.

### Atajos de teclado web

- [x] `Ctrl/⌘ + 1..6` para Inicio, Rutinas, Progreso, Fe, Perfil y Herramientas.
- [x] `Ctrl/⌘ + K` para accesos rápidos.
- [x] Ayuda de atajos visible desde la NavigationRail de escritorio.

### Accesibilidad y Reduce Motion

- [x] Preferencia persistente `Reducir movimiento`.
- [x] Respeto de `MediaQuery.disableAnimations` del sistema/navegador.
- [x] Menú flotante mobile sin transición cuando Reduce Motion está activo.
- [x] Semántica explícita en navegación y acciones personalizadas mobile.
- [x] Controles Material estándar con foco/teclado en web y panel compartido de plataforma.
- [x] Corrección del menú rápido para anchos mobile estrechos.

## Validación local obligatoria antes de `main`

La matriz está versionada en `scripts/validate_local.sh` y replica el CI:

- `flutter pub get` del workspace.
- `flutter analyze --no-fatal-infos`.
- tests de `packages/core`.
- tests de `apps/app_mobile`.
- Android debug APK.
- Android release APK.
- Web release con `--base-href /STK-Haven/`.
- iOS release sin firma cuando se ejecuta en macOS.

El despliegue manual de la web validada está versionado en `scripts/deploy_pages_local.sh`, que publica el contenido ya compilado de `apps/app_web/build/web` en `gh-pages` sin GitHub Actions.

## Criterio final de cierre

No fusionar `feat/roadmap-i-platform` con `main` hasta que `scripts/validate_local.sh` termine correctamente en la máquina local. Si la máquina no es macOS, la validación iOS debe ejecutarse posteriormente en un Mac antes de considerar completa toda la matriz multiplataforma.

## Riesgos / decisiones a conservar

- Mantener compatibilidad con datos locales existentes y evitar migraciones Hive cuando un estado accesorio pueda vivir de forma segura en `metadata`.
- No mezclar calentamiento/aproximación con series efectivas, PRs o métricas de rendimiento.
- Preservar IDs estables de ejercicios y rutinas para no romper historial ni referencias.
- Mantener la sincronización cloud como opcional; el modo local debe seguir siendo funcional.
- Nunca resolver conflictos cloud automáticamente cuando exista riesgo de pérdida de datos: la dirección de sincronización debe seguir siendo una elección explícita del usuario.
