# STK Haven Roadmap 2.0 — Matriz de plataformas

Esta matriz es intencional y no debe cambiar silenciosamente por defaults del SDK.

## Android
- Mínimo: Android 6.0 (API 23), fijado en `apps/app_mobile/android/app/build.gradle.kts`.
- Target/compile: siguen el Flutter SDK validado para no congelar requisitos de Play/SDK en código de aplicación.
- Distribución a validar al cierre: APK debug, APK release, AAB release y APK `--split-per-abi` para sideload personal.
- Perfil físico: al menos un dispositivo de recursos modestos compatible y un dispositivo moderno.
- Flujos críticos: cold start, workout activo, entrada numérica, timers/background, notificaciones, progreso con historial grande.

## iOS
- Deployment target actual: iOS 15.0.
- No se reduce el target solo para ampliar compatibilidad. Primero deben verificarse dependencias, build y comportamiento real.
- Validación final obligatoria en macOS/iPhone físico: cold start, memoria/frames, background/resume, notificaciones, SafeArea, Dynamic Type y teclado.

## Web / PWA
- El build estable de referencia sigue siendo la salida web compatible actual; WASM se evalúa como alternativa, no como reemplazo automático.
- Debe mantenerse fallback para navegadores/dispositivos donde WASM no sea apropiado.
- Un único service worker efectivo debe controlar actualización/offline.
- Validación responsive: móvil, tablet, laptop y ultrawide.
- Validación de accesibilidad: teclado, foco y lector de pantalla en flujos críticos.

## Presupuesto funcional de rendimiento
- Evitar trabajo síncrono largo en interacción UI.
- Objetivo visual 55–60 FPS en dispositivos de referencia y evitar de forma sistemática frames >32 ms en flujos frecuentes.
- Timers calculados desde timestamps para evitar drift.
- Historial grande debe usar índices/cache y no bloquear apertura de Inicio/Workout/Progreso.
- `PerformanceMode`: Automático / Calidad / Ahorro, con degradación visual antes que pérdida funcional.

La aceptación de esta matriz se ejecutará con `docs/roadmap/ROADMAP_2_FINAL_VALIDATION_AUDIT.md` una vez finalizadas todas las fases.