# STK Haven — A.3 clasificación semántica y plan de extracción

**Corte:** PR #57, 23/11/2026 · [Auditor automático inicial](STK_ARCHITECTURE_AUTOMATED_RESULTS_20261123.md) · código fuente de Core revisado por muestras directas. **No hay migraciones de producción en este bloque.**

## Subgrupos disjuntos: 170 archivos Core que dependen de Flutter o plugins

Los 170 se clasificaron mediante las declaraciones del JSON de GitHub Actions y la ruta/rol; los ejemplos de alto riesgo se reabrieron en el código fuente. Esta clasificación sirve para ordenar trabajo, no equivale a auditar línea por línea cada implementación.

| Clase de intervención | Archivos | Decisión |
|---|---:|---|
| UI/temas dentro de Core | **55** | Mover widgets/páginas/ThemeData a Mobile; extraer reglas que aún estén embebidas |
| Providers y servicios de estado que importan `flutter_riverpod` | **54** | Mantener estado/casos de uso en Core mediante `riverpod` puro o modelos+puertos; adaptar binding Flutter en Mobile |
| Repositorios/persistencia/remoto `hive_flutter` o `supabase_flutter` | **41** | Mantener contratos/modelos/algoritmos; separar inicialización del cliente, plugin Hive/Flutter y credenciales por adaptadores Mobile |
| Adaptadores de dispositivo, permisos y notificaciones | **17** | Mantener reglas de notificación en Core y mover implementación Flutter/native channels a Mobile |
| Flutter SDK sin widget explícito | **3** | Reemplazar `flutter/foundation`, platform channels o configuración por interfaces independientes del SDK |
| **Total** | **170** | Sin solapamiento entre las cinco clases |

Los **115 Core no visuales** se componen de 54 providers, 41 datos, 17 integraciones y 3 helpers Flutter. Los 55 visuales incluyen 52 pantallas/widgets y dos archivos de tema más una importación de Flutter Widgets en `active_workout_provider.dart`.

## Casos de alto riesgo revisados en fuente

1. **Entrenamiento activo** — `packages/core/lib/features/workout/application/active_workout_provider.dart` importa `flutter/widgets.dart` y `flutter/services.dart`. La función `_playRestCompletionFeedbackIfForeground` consulta `WidgetsBinding.instance.lifecycleState`, cancela una notificación de fondo, invoca un tono nativo por `MethodChannel('stk_haven/rest_tone')` y emite `HapticFeedback.mediumImpact()`. Debe convertirse en una interfaz inyectada desde Mobile para obtener estado foreground, reproducir el tono, cancelar la notificación y vibrar, conservando la regla **un único aviso y sin robar foco a YouTube Music**. La migración no debe alterar `WorkoutSession.id`, el borrador Hive ni los temporizadores.
2. **Sync** — `features/sync/application/cloud_sync_provider.dart` importa providers que viven en carpetas `presentation/providers`. Son providers lógicos, no widgets, pero todavía dependen de `flutter_riverpod` y de la inicialización `supabase_flutter`. No mover Sync a una pantalla ni romper autenticación: extraer providers Dart y cliente remoto por puertos.
3. **Sugerencias de entrenamiento** — `features/workout/application/active_workout_suggestions_provider.dart` depende de providers de Perfil/Rutinas en Core. Las dos rutas transitorias del auditor señalan dependencias indirectas de UI/Flutter; no introducir otras mientras se aísla el estado.
4. **Notificaciones** — `core/services/workout_notification_service.dart` tiene `FlutterLocalNotificationsPlugin`, Flutter channels, cálculos de zona horaria y lectura de Hive. Extraer políticas de disparo/tiempos a Core y adaptador de notificaciones/local timezone a Mobile; conservar los IDs, tiempos y cancelación automática de rest timers.
5. **Preferencias** — `features/profile/presentation/providers/settings_provider.dart` y `features/profile/data/settings_repository.dart` no dibujan UI, pero consumen `flutter_riverpod`/ `hive_flutter`. Migrar el estado/persistencia sin alterar claves `SettingsState` ni `AppearanceSettings.fromJson`.
6. **Web congelada** — `features/faith/data/bible_database_web.dart` reside actualmente en Core e importa `flutter/foundation.dart`. Debe desacoplarse, pero no modificar `apps/app_web` ni condicionar CI Mobile a que la Web pausada compile.

## Orden recomendado para código funcional después de la guardia

**B (ahora):** congelar las declaraciones prohibidas de Core y Mobile en un baseline que solo pueda decrecer; impedir que aparezcan nuevas importaciones UI/Flutter en Core, Core→Mobile/Web y Mobile→Web, incluidos dependientes Core→UI nuevos. Integrar pruebas unitarias del guard y JSON de diagnóstico en Actions.

**C.1 — Puertos críticos:** foreground/tono/háptica/cancelación de notificación; archivos/backup; autenticación/cliente remoto; fotografía y dispositivos. Preservar APIs mediante wrappers temporales, pruebas de integración y no pasar `BuildContext` a Core.

**C.2 — Configuración y Perfil:** trasladar páginas/widgets/tema de Core a Mobile sin cambiar primero su apariencia. Los modelos `SettingsState` y `AppearanceSettings` permanecen Core. Proteger consentimiento y datos antiguos. La nueva pantalla de Perfil lectura directa + engranaje viene después del movimiento.

**C.3 — Coach, Fe, hábitos, nutrición, programas, progreso, workout:** mover por grupos completos de importadores y tests de widgets, priorizando validación de sesión activa, cronómetro, música, recuperación y nutrición para menores.

**C.4 — Purificación:** cuando se hayan aislado consumidores, retirar de Core `flutter`, `flutter_riverpod`, `hive_flutter`, plugins/SDK de plataforma; activar barrera de arquitectura totalmente estricta con allowlist vacía.

**D–F:** sistema de diseño centralizado **solo Mobile**, Aspecto/tamaño/fuente/UI Styles, Perfil y Ajustes, QA físico y CI 7/7.

## Primer piloto de purificación de persistencia (C.0)
Los repositorios `settings_repository`, `routine_repository`, `active_workout_repository`, `hydration_repository`, `workout_repository`, `personal_record_repository`, `gamification_repository` y `personal_reminder_repository` en `packages/core/lib/features/*/data/` solo consumen `Box`/API Hive; el import de `hive_flutter` se cambia a `hive` Dart puro. **`HiveDatabase.initFlutter()` se conserva intacto** porque es inicialización de plataforma que requiere extracción por puerto posteriormente. La guardia debe registrar **8 eliminaciones** sin nuevas importaciones prohibidas. Sin conversión de bytes, claves, modelos, datos ni migraciones.

## Criterios y evidencia

- Confirmar clasificación contra pruebas pertinentes: Core 196 tests, Mobile 177 tests. La extracción de un archivo exige contratos cubiertos y navegación probada antes de borrar su ruta antigua.
- La referencia legada contiene **303 declaraciones prohibidas distintas** y **2 dependientes indirectos Core UI**, calculados automáticamente del report JSON del commit de corte. Una declaración existente puede eliminarse, jamás incorporar una nueva a la allowlist.
- La guardia de Fase B detecta nuevas declaraciones por SHA-256 de `path + NUL + uri`, no simplemente por cantidad de archivos. La barrera definitiva aún exige **cero dependencias prohibidas**, antes de cerrar arquitectura.
- **No modificar Web**, datos, IDs, persistencia, onboarding ni PR merge. El espejo sigue siendo solo GitHub Actions.
