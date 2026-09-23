# Roadmap 2.0 — Auditoría de implementación J–T

Rama de integración: `feat/roadmap-2-complete`.

Este documento separa **implementación** de **validación**. Una fase marcada como implementada significa que su arquitectura, modelos, lógica, persistencia, UI y/o harness de pruebas requerido ya existe en la rama. No significa que los builds, perfiles físicos, goldens, PWA/offline o smoke tests hayan sido ejecutados todavía.

La ejecución final está definida en `docs/roadmap/ROADMAP_2_FINAL_VALIDATION_AUDIT.md` y `scripts/validate_roadmap2_local.sh`.

## Estado ejecutivo

| Fase | Implementación | Validación pendiente |
| --- | --- | --- |
| J — Exercise Memory | COMPLETA | tests/smoke local final |
| K — Unilateral Pro | COMPLETA | timers/background + UI física |
| L — Programas 2.0 | COMPLETA | flujo real A/B/C + backup |
| M — Workout UX 2.0 | COMPLETA | teclado, undo, timers, resumen |
| N — Progreso 2.0 | COMPLETA | cache/resultados con dataset real |
| O — Refinamientos | COMPLETA | smoke transversal |
| P — Performance Core | COMPLETA EN CÓDIGO | benchmarks/perfil 1k/5k y frames |
| Q — Android | CONFIGURACIÓN/CÓDIGO COMPLETOS | perfil físico, AAB/APK, notificaciones |
| R — iOS | CONFIGURACIÓN/CÓDIGO COMPLETOS | macOS + iPhone físico |
| S — Web/PWA | IMPLEMENTACIÓN COMPLETA | dart2js/WASM, responsive, offline/upgrade |
| T — Calidad/release | HARNESS Y MIGRACIONES COMPLETOS | ejecutar matriz/goldens/integración |

---

## J — Exercise Memory global

Implementado:

- `ExercisePerformanceMemory` global por `exerciseId`.
- Índice de historial por ejercicio/rutina/fecha.
- Última ejecución independiente de `routineId`.
- Contexto de rutina/fecha/rango de reps/tipo de serie.
- `Última vez` en workout.
- Precarga opcional.
- `Usar última vez`.
- `Copiar serie anterior`.
- Preserva targets/rest propios de `RoutineExercise`.
- Progresión cross-routine por `exerciseId`.
- Rangos de reps no comparables se contextualizan con e1RM/RIR y no producen incremento ciego.
- IDs distintos nunca comparten memoria aunque el nombre coincida.
- Tests Push A → Push B → Push C y rep-context escritos.

## K — Unilateral Pro

Implementado:

- Peso/reps/RIR/completado I/D independientes, append-only en Hive.
- Lectura backward-compatible para históricos antiguos.
- Mismo peso opcional.
- Descanso entre lados independiente.
- Lado inicial configurable.
- Mobile mantiene controles I/D existentes; web incorpora editor por columnas I/D.
- Progresión usa lado limitante sin borrar el lado más fuerte.
- Volumen normalizado evita salto artificial ~2× frente a legacy.
- e1RM/volumen por lado y máximos históricos I/D en Progreso.
- Diferencias I/D se muestran de forma descriptiva.
- Tests de coordinador, progreso unilateral y backup schema 8/9 escritos.

## L — Rutinas y Programas 2.0

Implementado:

- Modelo `TrainingProgram` persistente.
- Rotación por orden A → B → C → A independiente del weekday.
- Planificación semanal de las rutinas sigue siendo contexto opcional.
- `Siguiente sesión` en Inicio.
- Mesociclo configurable.
- Semanas de descarga manuales.
- Duplicación de programa y semana.
- Historial de cumplimiento.
- Volumen previsto vs realizado por grupo muscular.
- UI de crear/editar/activar/duplicar/eliminar/reordenar.
- Persistencia local mediante caja optimizada + shadow autoritativo `training_programs_v2` en metadata para backup.
- Restore rehidrata el mirror y el provider escucha cambios del shadow.
- Test de rotación y test de shadow backup escritos.

## M — Workout UX 2.0

Implementado:

- Precarga desde Exercise Memory.
- Entrada rápida numérica.
- Flujo autofocus peso → reps → RIR.
- Copiar serie/última ejecución.
- Completar bilateral con una acción cuando ya hay datos.
- Undo de una acción con snapshot inmutable de sesión.
- Timer de workout y descanso derivados de timestamps.
- Timer inter-side.
- Haptics/sonido configurables.
- Notificación de descanso respeta sonido/vibración.
- Notificación se inicializa lazy/idempotente para reanudación temprana.
- Overlay compacto compartido mobile/web.
- Superseries y warmup/approach conservados.
- Sustitución evita atribuir trabajo completado a otro `exerciseId`.
- Resumen post-entreno compara cada ejercicio con su última ejecución global.

## N — Progreso e inteligencia 2.0

Implementado:

- Historial por sesión global por ejercicio.
- Última vs anterior cross-routine.
- Tendencias peso/reps/RIR/e1RM.
- Volumen por ejercicio y grupo con 30/90 días/todo.
- Métricas I/D.
- Señal informativa de estancamiento.
- Sugerencias explicables de progresión.
- Recovery actúa como modificador prudente, no bloqueo rígido.
- PR de reps derivado del historial sin migrar enum Hive existente.
- PR carga/e1RM/volumen existentes conservados.
- Cache de analytics + invalidación por revisión del historial.
- Downsampling de series temporales.

## O — Mejoras de funciones existentes

Implementado:

- Inicio: programa/siguiente sesión/readiness/acciones contextuales.
- Recovery: tendencias separadas de energía/sueño/estrés/molestias + contexto de rendimiento.
- Biblioteca: último rendimiento y acceso rápido a historial.
- Herramientas: 1RM desde ejercicio activo con valores precargados; calculadora de discos conservada.
- Configuración centralizada para entrenamiento/timers/unilateral/rendimiento/accesibilidad.
- Fe: búsqueda, filtros, edición rápida y persistencia offline existente.
- Backup/sync: última copia local/nube y dirección explícita dispositivo↔nube.

## P — Performance Core

Implementado en código:

- Uso de `select()` en estado de alta frecuencia del overlay.
- Timers no fuerzan redibujado de páginas completas desde el contador global.
- `WorkoutHistoryIndex` por ejercicio/rutina/fecha.
- Cache de analytics por revisión de historial.
- Listas grandes usan builders/slivers en superficies relevantes.
- Páginas no visitadas de web usan lazy `IndexedStack` por conjunto de visitadas.
- `PerformanceMode`: Automático / Calidad / Ahorro.
- Ahorro y Reduce Motion desactivan animaciones costosas a nivel de app.
- Downsampling de gráficas.
- Tests sintéticos 1k/5k escritos con tiempos informativos.
- Plugins mobile no críticos se difieren hasta después del primer frame.

Validación requerida: DevTools/profile y tiempos/frames en hardware real.

## Q — Android

Implementado/configurado:

- minSdk explícito API 23+.
- Script genera profile APK, release APK, AAB y `--split-per-abi`.
- Inicialización de notificaciones/background fuera del cold-start crítico.
- Timers persistentes por timestamp y notificaciones lazy.
- `Modo ahorro`/Reduce Motion reducen animaciones.

Pendiente de ejecución: perfil físico gama baja/media, memoria/jank, process recreation y notificaciones en versiones soportadas.

## R — iOS

Implementado/configurado:

- Deployment target 15.0 conservado; no se baja sin auditoría real de dependencias.
- Reduce Motion del sistema se integra mediante `MediaQuery.disableAnimations`.
- `Modo ahorro` también reduce animaciones.
- Timer timestamp/background y notificaciones comparten core mobile.
- El runner incluye build iOS profile cuando se ejecuta en macOS.

Pendiente de ejecución: build/profile macOS, iPhone físico, SafeArea/Dynamic Type/teclado/notificaciones.

## S — Web/PWA 2.0

Implementado:

- Un único service worker custom, versionado (`shell-v7`).
- Limpieza de caches custom anteriores y caches Flutter legacy.
- Network-first para navegación y shell/JS/WASM/manifiestos críticos.
- `skipWaiting()` + `clients.claim()` para upgrade.
- Migración de descargas/exportación desde `dart:html` a `package:web` + `dart:js_interop`.
- dart2js permanece baseline de producción.
- Runner construye WASM como comparación y restaura exactamente el artefacto dart2js validado para Pages.
- Lazy loading de secciones web visitadas.
- Navegación por teclado y semántica en shell.
- Tests responsive web 390/768/1440/2560 escritos.

Pendiente de ejecución: comparación real de artefactos/navegadores, PWA install/offline/upgrade y lector de pantalla.

## T — Calidad, migraciones y release

Implementado/preparado:

- Backup schema 9 conserva datos I/D y mantiene compatibilidad con schemas anteriores soportados.
- Tests explícitos schema 8 defaults y schema 9 detalle unilateral.
- Programas se respaldan mediante shadow autoritativo de metadata.
- Restauración vieja no conserva Programas stale; restauración nueva rehidrata el mirror.
- Metadata operativa de fechas de backup vive en `analyticsCache` y no contamina el payload restaurable.
- Tests J cross-routine, rep-ranges, K unilateral, L rotación, N progreso y P 1k/5k escritos.
- Test integrado de dominio Programa → memoria → workout → resumen → progreso → siguiente rotación.
- Tests responsive mobile 320/390/600 y web 390/768/1440/2560 escritos.
- Runner final `scripts/validate_roadmap2_local.sh` preparado.
- Matrices de plataforma y auditoría de pruebas documentadas.

Pendiente exclusivamente de ejecución/aprobación:

- `flutter analyze` y suites completas.
- Golden visual con baselines generados/aprobados localmente.
- Builds release/profile.
- Integración real de cierre/reapertura y restore.
- Perfil físico Android/iOS.
- Browser/PWA offline/upgrade.
- Regresión histórica completa.

---

## Hallazgos corregidos durante la auditoría estática

1. Doble splash web: corregido previamente en `main`/Pages.
2. Programas restaurados podían quedar ocultos por una caja optimizada stale: shadow autoritativo + rehidratación.
3. Metadata de “última copia” podía viajar dentro del backup: movida a `analyticsCache`.
4. Resumen post-entreno seguía comparando solo rutina: añadida comparación global por ejercicio sin cambiar la comparación de sesión completa.
5. Notificaciones/background bloqueaban startup mobile: diferidos tras primer frame.
6. Reanudación temprana de timer podía competir con inicialización diferida: servicio de notificaciones lazy/idempotente.
7. Progreso unilateral mostraba solo porcentaje: ahora expone e1RM/volumen y máximos históricos I/D.
8. Runner Roadmap 2 no ejecutaba tests web: ahora son obligatorios.

## Criterio para pasar a validación

La implementación queda congelada cuando una última revisión de Git confirma:

- rama `feat/roadmap-2-complete` 0 commits detrás de `main`;
- no hay cambios adicionales de funcionalidad pendientes;
- la matriz `ROADMAP_2_FINAL_VALIDATION_AUDIT.md` contiene todos los checks no ejecutados;
- el siguiente cambio sobre la rama debe ser únicamente una corrección encontrada por la validación local/física.
