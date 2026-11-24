# STK Haven — Auditoría A.1: Core lógico / Mobile interfaz
**Corte:** 23/11/2026 · PR #57 DRAFT · commit `d4dda3e7dd763091d9a4f048fe5bbdc43f7dae1a` · árbol `7d852b86fbbf41cc4784c971d2bcd947b41d3eaf`.

**Estado: EN CURSO.** Documento de diagnóstico verificado por lectura del árbol y fuentes seleccionadas; no es la certificación definitiva de cero violaciones. [Inventario de los 890 Dart](STK_CORE_MOBILE_SOURCE_INVENTORY_20261123.md).

## Reglas de destino
1. Core = modelos, reglas, casos de uso, puertos, repositorios y estado sin dependencias Flutter/UI ni importaciones Mobile/Web.
2. Mobile = toda la interfaz (Material, Widgets, páginas, design system), infraestructura/adaptadores de dispositivo y composición del app; nunca importa `apps/app_web`.
3. Web = congelada. Referencia de rama principal `a5bd29a385b2deebaf7d4b81ef738a03153a360d` obtenida del repositorio. **No está certificada como último build funcional Web**; se conserva como referencia de congelación, sin tocar archivos Web.
4. Eliminar plugins de Core progresivamente tras extraer adaptadores; no convertir la lógica en widgets ni crear implementaciones paralelas permanentes.

## Inventario a nivel de ruta (árbol completo)
| Grupo | Dart |
|---|---:|
| `packages/core/lib/` | 341 |
| `packages/core/test/` | 196 |
| `apps/app_mobile/lib/` | 114 |
| `apps/app_mobile/test/` | 177 |
| `apps/app_web/lib/` | 45 |
| `apps/app_web/test/` | 5 |
| Otros (scripts/otros) | 12 |
| **Total** | **890** |

**62 archivos inspeccionados por contenido** dentro de `packages/core/lib/**/*presentation*` y `core/theme/`: **52 páginas/widgets Flutter reales**, **2 archivos de tema Flutter**, **8 providers sin widgets**. La carpeta `presentation` no basta para clasificar un archivo: los providers indicados conservan lógica/estado, aunque sus dependencias Flutter/Riverpod/Hive requieren separación en fases posteriores.

## Core → candidatos de extracción a Mobile, confirmados
La totalidad de los 52 archivos de interfaz identificados en `presentation/` importan `package:flutter/material.dart`; los 2 archivos `core/theme/*` también son UI. El listado exacto de rutas se encuentra en el inventario enlazado.

- **52 componentes visuales** de Coach, Coach Pro, Fe, Hábitos, Identidad, Nutrición, Perfil, Programas, Progreso, Sync y Workout.
- **2 temas Flutter**: `core/theme/app_palette.dart` (colores/ThemeExtension) y `core/theme/appearance_theme.dart` (ThemeData).
- **8 providers no visuales en `presentation/providers`**, que **no se moverán como páginas**: 
  - `packages/core/lib/features/exercises/presentation/providers/exercise_favorites_provider.dart`
  - `packages/core/lib/features/exercises/presentation/providers/exercise_personal_settings_provider.dart`
  - `packages/core/lib/features/exercises/presentation/providers/exercise_provider.dart`
  - `packages/core/lib/features/profile/presentation/providers/settings_provider.dart`
  - `packages/core/lib/features/profile/presentation/providers/user_experience_profile_provider.dart`
  - `packages/core/lib/features/programs/presentation/providers/training_program_provider.dart`
  - `packages/core/lib/features/routines/presentation/providers/routine_provider.dart`
  - `packages/core/lib/features/workout/presentation/providers/personal_record_provider.dart`

**Decisión:** extraer primero las reglas contenidas dentro de pantallas/diálogos, cambiar imports y rutas en Mobile y recién después eliminar los originales Core. No dar por pura una carpeta solo porque no se llame `presentation`.

## Mobile → Core UI: 18 archivos consumidores confirmados
Inspeccionadas las declaraciones `import`, `export` y `part` de **los 114 Dart de producción de Mobile**. Identificados **18 archivos** con importaciones a elementos visuales de Core. El destino de esas referencias debe cambiar a nuevas rutas Mobile.

| Área | Consumidor (ruta relativa a `apps/app_mobile/lib`) | UI de Core actualmente utilizada |
|---|---|---|
| Faith | `features/faith/presentation/pages/daily_verse_page.dart` | `features/faith/presentation/widgets/contextual_passage_details.dart` |
| Hábitos | `features/habits/presentation/study_habits_mobile_page.dart` | `features/habits/presentation/pages/study_habits_page.dart` |
| Inicio | `features/home/presentation/pages/dashboard_page.dart` | `features/workout/presentation/widgets/recent_workout_details.dart` |
| Inicio | `features/home/presentation/pages/home_screen.dart` | `features/coach/presentation/pages/coach_hub_page.dart` |
| Nutrición | `features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart` | `features/nutrition/presentation/pages/nutrition_intelligence_page.dart` |
| Perfil | `features/profile/presentation/pages/profile_page.dart` | 9 imports: pantallas de Perfil/Coach/Sync y componentes de Perfil |
| Perfil | `features/profile/presentation/pages/stk_mobile_privacy_page.dart` | `features/sync/presentation/backup_status_page.dart` |
| Progreso | `features/progress/presentation/pages/anatomy_audit_page.dart` | `features/sync/presentation/backup_status_page.dart` |
| Progreso | `features/progress/presentation/pages/body_measurement_page.dart` | `features/progress/presentation/widgets/measurement_reminder_controls.dart` |
| Progreso | `features/progress/presentation/pages/focused_exercise_progress_page.dart` | `features/progress/presentation/pages/progress_intelligence_page.dart` |
| Progreso | `features/progress/presentation/pages/progress_page.dart` | `progress_intelligence_page.dart + compact_progress_period_selector.dart` |
| Progreso | `features/progress/presentation/widgets/muscle_heatmap_grid.dart` | `features/progress/presentation/widgets/compact_progress_period_selector.dart` |
| Progreso | `features/progress/presentation/widgets/progress_shared_period_selector.dart` | `features/progress/presentation/widgets/compact_progress_period_selector.dart` |
| Entrenar | `features/routines/presentation/pages/routines_page.dart` | `features/programs/presentation/pages/training_programs_page.dart` |
| Entrenar | `features/routines/presentation/widgets/quick_training_plan_sheet.dart` | `features/programs/presentation/pages/training_programs_page.dart` |
| Workout | `features/workout/presentation/active_workout_page.dart` | `features/workout/presentation/widgets/active_workout_memory_overlay.dart` |
| Workout | `features/workout/presentation/active_workout_page_content.dart` | 3 widgets: increment control, rep range notice, memory overlay |
| Workout | `features/workout/presentation/workout_summary_page.dart` | `features/faith/presentation/widgets/workout_closing_reflection_card.dart` |

**Resultado para la prohibición Mobile → Web:** **0 imports/exports/parts directos** a `apps/app_web` hallados entre esos 114 archivos bajo las rutas y nombres de paquete buscados. Quedan por resolver alias/exports indirectos y scripts/Tests en el análisis A.2. No afirmar aún cero dependencias transitivas.

## Plugins, plataforma y mezclas Core (muestra comprobada)
Se leyeron los 17 archivos de `core/services` y otros 15 archivos críticos de servicios/application/data de Fe, Nutrición, Sync, Identity, Perfil, Progreso y Coach. Ejemplos constatados:
- `core/services/workout_notification_service.dart`: Flutter services/foundation, notificaciones nativas y Hive Flutter.
- `core/services/local_notification_timezone.dart`: Flutter platform channels; requiere un adaptador Mobile.
- `core/services/backup_file_service_mobile.dart`: `file_picker` y `share_plus`; mover implementación, retener contrato de export/import en Core.
- `core/services/hydration_reminder_service.dart`, `personal_motivational_reminder_service.dart`, `step_goal_reminder_service.dart`, `coach_pro_local_reminder_service.dart`: APIs de notificación/Flutter en Core.
- `features/faith/services/verse_background_service.dart`: Workmanager y preferencias nativas.
- `features/faith/services/verse_notification_service.dart`, `features/progress/services/measurement_reminder_service.dart`, `features/habits/application/habit_task_notification_service.dart`, `features/coach/application/coach_task_notification_service.dart`: notificaciones/Flutter.
- `features/faith/services/verse_widget_sync.dart`: canales Flutter; `features/faith/data/bible_database_mobile.dart`: SQLite+Flutter; `bible_database_web.dart` contiene implementación específica Web **dentro de Core** y debe aislarse (sin editar Web).
- `features/profile/application/data_export_service_mobile.dart`: compartir ficheros y rutas del dispositivo.
- `features/identity/application/app_identity_provider.dart` y `features/sync/application/cloud_sync_provider.dart`: `flutter_riverpod` + `supabase_flutter`; diseño de puertos y providers puros antes de mover dependencias.
- `features/nutrition/data/food_vision_service.dart`: `supabase_flutter` sin ser UI; conservar la lógica de validación/acceso, separar inicialización cliente.

El `pubspec.yaml` de Core todavía declara `flutter`, `flutter_riverpod`, `hive_flutter`, `flutter_local_notifications`, `file_picker`, `image_picker`, `workmanager`, `supabase_flutter`, etc. **No quitarlos en A ni migrar persistencia/boxes a ciegas.**

### Orden de migración propuesto
1. **Preparar puertos de plataforma y proveedores Dart puros** para servicios, notificaciones, autenticación, archivos, preferencias nativas. Congelar modelos JSON/Hive existentes con tests antes de mover implementación.
2. **Tema/Perfil y Ajustes** (incluida gran foto, datos visibles en modo lectura y Nivel/logros) con dependencias visuales arrastradas desde Core.
3. **Coach/Coach Pro, Fe y Hábitos**: agrupar componentes que se importan unos a otros; revisar Estado/proveedores y lógica embebida.
4. **Nutrición, Progreso, Programas, Entrenar/Workout**: seguir mapa inverso de Mobile; preservar timers/side rest, sesión activa y cálculos clínicos/menores según las reglas actuales.
5. **Limpiar exportaciones, plugins y referencias** y activar guardias con allowlist vacía en CI.

## Matriz de riesgos / pruebas antes de migrar
| Riesgo | Línea base indispensable |
|---|---|
| Sesión activa y unilateral | misma sesión, dos lados = una serie, descansos, background, notificaciones y música |
| Datos existentes | Hive IDs/boxes, superseries, historial, rutinas, backups y restauración sin reiniciar onboarding |
| Nutrición y menores | edad 15+, cálculo <18 y ≥18 y políticas sin cambios |
| Identidad/privacidad | Supabase Auth, consentimiento opcional, foto, borrado y restauración de datos |
| UI global | Perfil, Inicio, Entrenar, Progreso, OLED, claro/oscuro, 320/390/430dp, escala 100/160/200% |
| Web | código pausado; posible incompatibilidad de API anotada, no bloquear Mobile ni modificar Web |

**CI previo de código funcional:** [Actions #45289091283](https://github.com/fernando15xvs/STK-Haven_CI/actions/runs/45289091283) completado con `success` en commit espejo `d6f200ab02cde33a69f24dd9054cbd5e701a6a0e`. La ejecución sobre el roadmap previo (`00a10e5`) estaba todavía en progreso al tomar la línea base. Un nuevo commit de documentación requiere su propia confirmación de CI.

## Checklist de Fase A
- [x] Árbol GitHub sin truncar, rutas de Core/Mobile/Web/test inventariadas.
- [x] Inspeccionados los 62 archivos de Core en `presentation`/tema; separados 52 widgets/páginas + 2 temas + 8 providers.
- [x] Inspeccionadas las importaciones declaradas en los 114 archivos de producción Mobile; 18 consumidores Core UI, sin Mobile→Web directo en la muestra.
- [x] Documentado el subconjunto de servicios/plugins críticos y el SHA de referencia Web congelada.
- [ ] **A.2** Inspeccionar por contenido las 279 rutas restantes Core (no solo por nombre) y catalogar todas sus importaciones/exportaciones/parts y las dependencias transitivas.
- [ ] **A.3** Examinar los 196 tests Core y los 177 Mobile y mapear referencias antiguas y rutas necesarias al mover widgets; revisar otros scripts.
- [ ] **A.4** Clasificar UI+reglas mezcladas y diseñar puertos concretos por archivo/feature, con métricas definitivas de violaciones.
- [ ] **A.5** Verificar baseline actualizado de la PR + espejo y cerrar Fase A **antes de mover código funcional**.

**No se ha realizado ningún movimiento de UI, cambio de lógica, migración de datos ni modificación Web.**
