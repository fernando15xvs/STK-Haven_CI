# STK Haven — Resultados automáticos de Fase A.2

**Fuente verificable:** GitHub Actions [#45307024472](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/45307024472), artifact `stk-architecture-inventory` (JSON de 426 097 bytes, 14 días de retención), ejecutado en espejo HEAD `f01f142bc3415af066837df86833c20a0dd2c35b`. El auditor pasó en modo diagnóstico y publicó el archivo. **No significa que toda la ejecución de CI haya terminado en verde**.

**Método:** `tools/architecture_inventory.py` analiza declaraciones Dart `import`/`export`/`part`, incluidos imports condicionales, resuelve rutas de packages Core/Mobile/Web, calcula cierre transitivo Core→UI y genera JSON del checkout. Es una inspección léxica: no sustituye al analyzer semántico, pruebas de runtime ni auditoría humana de lógica visual embebida.

## Resultado de todo el árbol (890 Dart)
| Detección | Archivos | Declaraciones |
|---|---:|---:|
| Core importa UI de Flutter / `dart:ui` o tema visual | 55 | 61 |
| Core importa cualquier módulo del SDK Flutter | 70 | 85 |
| Core importa paquetes Flutter/plugins de plataforma (incl. `flutter_riverpod`) | 170 | 297 |
| Core importa Mobile o Web directamente | **0** | **0** |
| Mobile importa Web directamente | **0** | **0** |
| Mobile importa página/widget/tema visual Core | **25** | **36** |
| Core depende indirectamente de UI (sin ser uno de los 55 directos) | **2** | — |
| Imports workspace/relativos sin resolver | **6** | — |

El escaneo incluye **341 Core/lib**, **196 Core/test**, **114 Mobile/lib**, **177 Mobile/test**, **45 Web/lib**, **5 Web/test** y **12 herramientas/otros**.

## Excepciones de máxima prioridad
- `packages/core/lib/features/workout/application/active_workout_provider.dart` **importa `package:flutter/widgets.dart`**. Es un caso de lógica de entrenamiento mezclada con Flutter fuera de `presentation`. Antes de moverlo, extraer cualquier ciclo de vida/interacción visual hacia Mobile; preservar identidad de sesión, cronómetros y estado.
- **2 consumidores Core transitivos de Core UI:** `features/sync/application/cloud_sync_provider.dart` y `features/workout/application/active_workout_suggestions_provider.dart`. No mover solo los widgets; corregir la dirección de las dependencias.
- 6 imports relativos no resueltos están exclusivamente dentro de `apps/app_web/lib/features/faith/presentation/` e intentan cargar `../../../../core/theme/app_colors.dart`. **No modificar ni compilar Web**, dado el acuerdo de congelación; documentar como deuda de Web pausada.
- La revisión manual previa clasificó **52 widgets/páginas + 2 temas** y **8 providers lógicos** en `presentation`/tema; el barrido halló **un archivo Flutter adicional en application**, por eso la cifra total direct Core UI es **55**.
- Los plugins/Flutter en Core se extraerán mediante puertos/adaptadores, no eliminando paquetes ni datos de Hive/Supabase sin pruebas.

## 25 consumidores Mobile→Core UI (rutas reales)
- `apps/app_mobile/lib/core/layout/mobile_content_frame.dart`
- `apps/app_mobile/lib/core/theme/app_colors.dart`
- `apps/app_mobile/lib/core/theme/app_theme.dart`
- `apps/app_mobile/lib/features/faith/presentation/pages/daily_verse_page.dart`
- `apps/app_mobile/lib/features/habits/presentation/study_habits_mobile_page.dart`
- `apps/app_mobile/lib/features/home/presentation/pages/dashboard_page.dart`
- `apps/app_mobile/lib/features/home/presentation/pages/home_screen.dart`
- `apps/app_mobile/lib/features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart`
- `apps/app_mobile/lib/features/profile/presentation/pages/achievements_page.dart`
- `apps/app_mobile/lib/features/profile/presentation/pages/profile_page.dart`
- `apps/app_mobile/lib/features/profile/presentation/pages/stk_mobile_privacy_page.dart`
- `apps/app_mobile/lib/features/progress/presentation/pages/anatomy_audit_page.dart`
- `apps/app_mobile/lib/features/progress/presentation/pages/body_measurement_page.dart`
- `apps/app_mobile/lib/features/progress/presentation/pages/focused_exercise_progress_page.dart`
- `apps/app_mobile/lib/features/progress/presentation/pages/progress_page.dart`
- `apps/app_mobile/lib/features/progress/presentation/widgets/body_measurement_silhouette.dart`
- `apps/app_mobile/lib/features/progress/presentation/widgets/body_measurement_summary.dart`
- `apps/app_mobile/lib/features/progress/presentation/widgets/muscle_heatmap_grid.dart`
- `apps/app_mobile/lib/features/progress/presentation/widgets/progress_shared_period_selector.dart`
- `apps/app_mobile/lib/features/routines/presentation/pages/routines_page.dart`
- `apps/app_mobile/lib/features/routines/presentation/widgets/quick_training_plan_sheet.dart`
- `apps/app_mobile/lib/features/workout/presentation/active_workout_page.dart`
- `apps/app_mobile/lib/features/workout/presentation/active_workout_page_content.dart`
- `apps/app_mobile/lib/features/workout/presentation/workout_summary_page.dart`
- `apps/app_mobile/lib/shared/app/stk_haven_app.dart`

## Próximas acciones para completar Fase A
- [x] Inventario de 890 rutas y prueba automatizada en GitHub Actions.
- [x] Conteo directo y transitivo de importaciones con fuente JSON.
- [x] Confirmación directa: 0 imports Core→Mobile/Web y 0 Mobile→Web (en producción y bajo este método).
- [ ] Revisar el JSON archivo por archivo para catalogar los 170 consumidores Core de plugins/Flutter (no todos son visuales) y los 55 Core UI, incluyendo falsos positivos.
- [ ] Analizar reglas de negocio dentro de páginas/widgets y definir puertos para notificaciones, audio, backups, identidad, permisos y persistencia.
- [ ] Identificar pruebas afectadas por cada movimiento y publicar matriz de dependencias/migraciones.
- [ ] Ejecutar prueba final de CI del HEAD de este informe y cerrar Fase A; después iniciar guardia con allowlist decreciente en Fase B.

**Importante:** el script tiene `--enforce`, pero no se ejecutará con ese flag hasta configurar correctamente las barreras y resolver la deuda heredada. La arquitectura **no** está limpia todavía. No hubo cambios en lógica, UI, datos ni Web.
