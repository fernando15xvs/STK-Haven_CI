# Roadmap 2.0 — Auditoría final de validación

Este documento es la fuente de verdad para el cierre de pruebas de las fases J–T. La implementación puede cerrarse antes que la validación física, pero cada ítem solo se marca cuando existe evidencia real.

## Estado actual del candidato — 2026-09-12

**HEAD actual de la rama después de la separación Android/iOS:** `d3225db8e2767e93b965b7be7f6910d8a3caa8d6`.

Desde la última matriz automática verde se modificó código runtime y de build. Entre los cambios posteriores están:
- hardening de rendimiento Android/móvil: pestañas lazy, eliminación de blur costoso, física de scroll nativa, inicialización diferida y apertura concurrente de cajas Hive;
- release Android instalable con firma debug únicamente cuando no existe `android/key.properties`;
- entrypoints separados `main_android.dart` y `main_ios.dart`;
- bootstrap compartido sin imports de plataforma;
- servicios de arranque Android/iOS aislados en `lib/platform/android/` y `lib/platform/ios/`;
- scripts locales y workflow actualizados para compilar cada plataforma con su target explícito.

Por lo tanto, la matriz automática verde documentada sobre `844d5e18...` **queda como evidencia histórica**, pero **no valida el HEAD actual**. Debe repetirse `scripts/validate_roadmap2_local.ps1` antes de considerar verde el nuevo candidato.

### Evidencia manual Android ya completada y que sigue siendo válida funcionalmente

En emulador/dispositivo se verificó:
- Entrada rápida: OK.
- 1RM: OK.
- Deshacer: OK.
- Background/resume de workout: OK.
- Cerrar/reabrir workout conserva sesión: OK.
- Exercise Memory entre rutinas: OK.
- Temporizador global visible y funcional tras ajuste de layout: OK.
- Temporizador de descanso entre series visible: OK.
- Tarjeta del ejercicio ya no queda tapada por la superficie de Memoria: OK.
- Unilateral I/D independiente: OK.
- Izquierda→descanso→Derecha: OK.
- Derecha→descanso→Izquierda: OK.
- Background durante descanso unilateral: OK.
- Pesos distintos por lado: OK.
- Cerrar/reabrir conserva unilateral: OK.
- Finalizar/resumen unilateral sin error: OK.
- Crear/abrir programa: OK.
- Completar rutina A: OK.
- Rotación A→B→C: OK.
- Historial + programa: OK.
- Cerrar/reabrir con programa activo: OK.
- Estado final del programa: OK.

Hallazgos UX todavía pendientes:
- mejorar visualmente los marcadores I/D del workout unilateral;
- enriquecer la información unilateral del resumen/progreso;
- volver a medir fluidez en APK release físico después del hardening y del split de plataforma.

---

## Evidencia automática — Windows — 2026-09-09

**Candidato de código validado:** `844d5e181d2d00bf70d5f13f0394b3d84ae26f11`

**Entorno:**
- Windows / PowerShell.
- Flutter `3.38.9` stable.
- Dart `3.10.8`.
- DevTools `2.51.1`.
- Runner: `powershell -ExecutionPolicy Bypass -File .\scripts\validate_roadmap2_local.ps1`.

**Resultado:**

`SUCCESS: Roadmap 2.0 local build/test matrix available on this machine passed.`

Pasaron en la misma matriz:
- resolución de dependencias del workspace;
- `flutter analyze`;
- tests completos de `packages/core`;
- tests completos de `apps/app_mobile`;
- tests web/responsive de `apps/app_web`;
- Android debug APK;
- Android release APK;
- Android profile APK;
- Android AAB release;
- Android split-per-ABI release;
- web release dart2js con base `/STK-Haven/`;
- build comparativo WebAssembly;
- restauración del artefacto dart2js exacto destinado a Pages.

Artefactos Android observados:
- `app-arm64-v8a-release.apk`: `51,024,521` bytes.
- `app-armeabi-v7a-release.apk`: `49,039,827` bytes.
- `app-x86_64-release.apk`: `52,492,634` bytes.
- `app-release.apk`: `96,091,220` bytes.
- `app-profile.apk`: `151,958,674` bytes.
- `app-debug.apk`: `268,459,989` bytes.
- `app-release.aab`: `80,084,460` bytes.

El build iOS fue omitido correctamente porque requiere macOS. GitHub Actions no forma parte del criterio de cierre de este proyecto.

> Nota de trazabilidad: cualquier commit posterior que modifique únicamente documentación de esta auditoría no invalida una ejecución previa. Cualquier cambio posterior de código/runtime sí exige volver a ejecutar la matriz correspondiente.

### Incidencia runtime Android detectada durante smoke real

Durante la validación manual Android se detectó una pantalla roja al usar las acciones rápidas del entrenamiento. La cadena visible terminaba en `_dependents.isEmpty`, pero la captura completa en emulador mostró como error primario `A TextEditingController was used after being disposed`.

La causa concreta estaba en `QuickSetEntryDialog`: los `TextEditingController` y `FocusNode` se creaban fuera del widget del diálogo y se destruían inmediatamente al resolverse `showDialog()`, cuando Flutter todavía podía conservar la ruta durante su transición de salida. Se corrigió moviendo esos recursos al ciclo de vida de un `StatefulWidget` propio, de modo que Flutter los destruye únicamente al retirar realmente el diálogo del árbol.

Además, los controles globales del workout dejaron de depender de un `OverlayEntry` persistente a nivel de aplicación y se mantuvieron dentro de la ruta activa del entrenamiento. El resultado 1RM quedó renderizado dentro del propio host del workout, sin depender de una ruta modal para presentar el resultado.

**Smoke posterior en emulador Android:** la pantalla roja dejó de reproducirse al consultar 1RM tras la corrección.

---

## Regla de cierre
Roadmap 2.0 no se considera listo para `main` hasta que:

- [x] `flutter analyze` no tenga errores ni warnings bloqueantes en el candidato automático histórico.
- [x] Tests core/mobile/web relevantes pasen en el candidato automático histórico.
- [x] Android debug/release/profile/AAB/split y web release construyan correctamente en el candidato automático histórico.
- [ ] Repetir matriz completa sobre el candidato posterior al hardening/split Android-iOS.
- [ ] iOS se valide en macOS o equipo compatible antes del release final iOS.
- [x] Backups v8/v9 cubiertos por tests de restauración Hive pasan en la matriz histórica.
- [ ] Smoke tests funcionales manuales J–T restantes pasen en datos nuevos y datos existentes.
- [ ] No haya regresiones manuales en superseries, warmup/approach, PWA/offline, backup/sync ni progreso.

---

## 0. Integridad Git / release candidate
- [x] Registrar SHA exacto del candidato automático Windows histórico.
- [x] Comparar rama contra `main` y confirmar que contiene `main` sin quedar por detrás.
- [x] Runner distingue cambios fuente de artefactos Flutter regenerados conocidos.
- [ ] Registrar nuevo SHA automático después de ejecutar la matriz post-split.
- [ ] Repetir `git status` final antes del merge y confirmar que no hay cambios fuente locales.
- [ ] Confirmar ausencia de secretos/credenciales y archivos locales en la diferencia final antes del merge.

## 1. Matriz automática general
- [x] Matriz completa pasó sobre `844d5e18...`.
- [ ] Repetir `flutter pub get` sobre HEAD actual.
- [ ] Repetir `flutter analyze` sobre HEAD actual.
- [ ] Repetir tests completos de `packages/core` sobre HEAD actual.
- [ ] Repetir tests completos de `apps/app_mobile` sobre HEAD actual.
- [ ] Repetir tests web/responsive sobre HEAD actual.
- [ ] Repetir Android debug/profile/release/AAB/split usando `lib/main_android.dart`.
- [ ] Repetir Web dart2js/WASM sobre HEAD actual.
- [ ] iOS analyze/test/build en macOS usando `lib/main_ios.dart`.

## 2. Fase J — Exercise Memory global
- [x] Tests automáticos cross-routine por `exerciseId` pasaron en la matriz histórica.
- [x] Tests automáticos de acciones de memoria y contexto de repeticiones pasaron en la matriz histórica.
- [x] Smoke manual: mismo ejercicio comparte historial entre rutinas.
- [ ] Smoke manual: distinto `exerciseId` nunca comparte historial aunque el nombre coincida.
- [x] `Última vez` y Exercise Memory entre rutinas verificados funcionalmente.
- [ ] Warmup/approach/working se alinean visualmente por tipo y ordinal.
- [x] `Usar última vez`/memoria cross-routine no rompió el objetivo de la rutina durante la prueba realizada.
- [ ] `Copiar serie anterior` en sesión real: no estuvo disponible en el escenario probado.
- [ ] Rangos no comparables se presentan como contexto distinto y sin aumento ciego.

## 3. Fase K — Unilateral Pro
- [x] Tests automáticos de coordinación unilateral pasaron en la matriz histórica.
- [x] Tests de progreso unilateral pasaron en la matriz histórica.
- [x] Tests de backup v9 preservaron valores por lado en la matriz histórica.
- [x] Peso/reps/RIR independientes por lado en uso real.
- [x] Flujo Izquierda→descanso→Derecha→descanso de serie.
- [x] Flujo Derecha→descanso→Izquierda.
- [x] Background/resume conserva timer inter-side.
- [ ] Mobile I/D requiere refinamiento visual de sus marcadores.
- [ ] Diferencia entre lados/resumen unilateral requiere más información visual.

## 4. Fase M — Workout UX 2.0
- [x] Tests automáticos relevantes de memoria/comparación pasaron en la matriz histórica.
- [x] Regresión runtime Android: acciones rápidas/1RM ya no reproducen pantalla roja.
- [x] Entrada rápida validada funcionalmente.
- [x] 1RM validado funcionalmente.
- [x] Deshacer restaura el estado esperado en la prueba manual.
- [x] Timer usa timestamp correctamente tras background/resume en la prueba manual.
- [x] Cerrar/reabrir conserva el workout activo.
- [x] Temporizador global visible y funcional.
- [x] Descanso entre series visible y funcional tras corregir superposición de layout.
- [ ] Autofocus/teclado en todos los dispositivos soportados.
- [ ] Haptics/sonido respetan preferencias en dispositivo físico.
- [ ] Superseries y warmup/approach mantienen semántica previa.
- [ ] Sustitución de ejercicio conserva identidad/historial correcto.
- [ ] Resumen post-entreno compara contra última ejecución global con todos los escenarios.

## 5. Fase L — Programas 2.0
- [x] Tests automáticos de rotación A→B→C y backup shadow pasaron en la matriz histórica.
- [x] Crear/abrir programa en UI real.
- [x] Completar rutina A y avanzar correctamente.
- [x] Rotación A→B→C validada manualmente.
- [x] Historial + programa validado manualmente.
- [x] Cerrar/reabrir conserva programa activo y siguiente estado.
- [x] Estado final del ciclo validado manualmente.
- [ ] Planificación semanal opcional no rompe la rotación.
- [ ] Mesociclo y descarga manual.
- [ ] Duplicar programa/semanas sin compartir IDs mutables.
- [ ] Previsto vs realizado semanal por grupo muscular.
- [ ] Restore desde backup real de programa y continuación de uso.

## 6. Fase N — Progreso e inteligencia 2.0
- [x] Tests automáticos de progreso global y unilateral pasaron en la matriz histórica.
- [x] Tests de contexto de progresión pasaron en la matriz histórica.
- [ ] Historial por ejercicio global verificado visualmente.
- [ ] Tendencias peso/reps/RIR/e1RM con dataset real.
- [ ] Volumen por ejercicio/grupo con filtros de período.
- [ ] Estancamiento y sugerencias se presentan de forma explicable.
- [ ] Recovery modifica sugerencia sin bloquear automáticamente.
- [ ] PR carga/reps/e1RM/volumen correctos con datos reales.
- [ ] Invalida cache al añadir/editar/restaurar sesiones en uso real.

## 7. Fase O — Refinamiento transversal
- [ ] Inicio muestra siguiente rutina/programa y readiness contextual en todos los estados.
- [ ] Recovery muestra tendencias y relación con rendimiento sin diagnóstico.
- [ ] Biblioteca muestra último rendimiento e historial rápido.
- [ ] Herramientas se abren desde ejercicio activo con valores precargados.
- [ ] Perfil centraliza preferencias workout/timers/unilateral/rendimiento.
- [ ] Fe: búsqueda/filtros/edición rápida/offline guardado.
- [ ] Backup/sync muestra última copia y dirección de restauración con claridad.

## 8. Fase P — Performance Core
- [x] Benchmark sintético 1k sesiones ejecutado dentro de tests core en la matriz histórica.
- [x] Benchmark sintético 5k sesiones ejecutado dentro de tests core en la matriz histórica.
- [x] Tests de índice de historial/analytics con 1k y 5k sesiones pasaron históricamente.
- [x] Se aplicó hardening móvil posterior: tabs lazy, menos blur/compositing, scroll nativo, trabajo no crítico diferido y Hive concurrente.
- [ ] Repetir matriz automática post-hardening.
- [ ] Medir apertura de workout, progreso e inicio con historial grande en dispositivo real.
- [ ] Revisar memoria y frames >32 ms en dispositivo físico.
- [ ] Confirmar Riverpod/timers sin reconstrucciones excesivas con DevTools.

## 9. Fase Q — Android
- [x] Piso Android configurado de forma estable: `maxOf(23, flutter.minSdkVersion)`.
- [x] Arquitectura separada con `lib/main_android.dart` y `lib/platform/android/`.
- [x] Build release puede firmarse con key privada o, solo para pruebas locales, con debug key.
- [x] Smoke en emulador reproduce el flujo 1RM corregido sin pantalla roja.
- [x] Funciones J/K/L principales probadas manualmente en Android.
- [ ] Repetir debug/profile/release/AAB/split sobre el nuevo entrypoint Android.
- [ ] Confirmar mejora de fluidez en el APK release físico post-hardening.
- [ ] Cold start release/profile en dispositivo físico.
- [ ] Memoria y jank en dispositivo gama baja/media.
- [ ] Recreación de proceso mantiene workout/timers.
- [ ] Notificaciones verificadas en versiones Android soportadas.

## 10. Fase R — iOS
- [x] Arquitectura separada con `lib/main_ios.dart` y `lib/platform/ios/`.
- [ ] Build release/profile en macOS con el nuevo entrypoint iOS.
- [ ] Cold start/memoria/frames en iPhone físico compatible.
- [ ] Background/resume timers/notificaciones.
- [ ] Reduce Motion/Modo rendimiento reduce efectos costosos.
- [ ] SafeArea, Dynamic Type y teclado.

## 11. Fase S — Web / PWA 2.0
- [x] Build web dart2js release pasó en la matriz histórica.
- [x] Build comparativo WASM pasó en la matriz histórica.
- [x] Tests responsive web pasaron, incluido 390×844, en la matriz histórica.
- [x] Artefacto dart2js exacto se restauró para Pages después del build WASM.
- [ ] Repetir matriz web sobre HEAD actual.
- [ ] Upgrade de release sin limpiar caché manualmente.
- [ ] Offline abre versión instalada esperada.
- [ ] Instalación PWA y reapertura.
- [ ] Teclado y lector de pantalla.
- [ ] Cache/service worker no sirve release antigua tras deploy.

## 12. Fase T — Migraciones / integración / release
- [x] Restore schema 8 con defaults unilaterales seguros pasó históricamente.
- [x] Restore schema 9 conserva datos detallados por lado históricamente.
- [x] Tests J cross-routine pasaron históricamente.
- [x] Tests de rangos de repeticiones/contexto pasaron históricamente.
- [x] Tests unilateral pasaron históricamente.
- [x] Tests Programas A/B/C pasaron históricamente.
- [x] Tests responsive críticos pasaron históricamente.
- [x] Test de integración Roadmap 2.0 programa→memoria→workout→resumen→progreso pasó históricamente.
- [ ] Repetir todos los anteriores sobre HEAD post-split.
- [ ] Golden approval humana.
- [x] Integration manual con cierre/reapertura durante workout.
- [ ] Integration manual restore backup→continuar uso.
- [ ] Auditoría de regresión funcional histórica completa.

## 13. Regresión funcional histórica
- [ ] Crear/editar/eliminar rutina tradicional.
- [ ] Entrenamiento libre.
- [ ] Añadir/quitar/reordenar ejercicios y series.
- [ ] Superseries.
- [ ] Warmup/approach/working.
- [ ] Notas por ejercicio/sesión.
- [ ] Calculadora de discos.
- [ ] RIR on/off.
- [ ] kg/lb.
- [ ] Recovery/check-in.
- [ ] Gamificación si sigue habilitada.
- [ ] Export CSV.
- [ ] Backup local.
- [ ] Cloud backup/sync si está configurado.
- [ ] PWA offline.
- [ ] Navegación y accesibilidad existentes.

## Estado de cierre actual

La implementación J–T continúa en la rama `feat/roadmap-2-complete`, sin merge a `main`. La matriz automática histórica fue verde, pero el candidato actual cambió por hardening móvil y separación Android/iOS, por lo que requiere una nueva ejecución completa antes de recuperar estado automático VERDE.

La evidencia manual Android ya cubre Exercise Memory, acciones rápidas/1RM, timers, persistencia, Unilateral Pro funcional y Programas 2.0 básico. Permanecen pendientes el refinamiento visual unilateral, Progreso/Intelligence manual, rendimiento físico post-hardening, regresión histórica, PWA y toda la validación iOS/macOS.

No hacer merge a `main` hasta completar o aceptar explícitamente las validaciones pendientes del nuevo candidato.
