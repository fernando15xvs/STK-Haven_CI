# Roadmap 3.0 — Auditoría de regresión Roadmap 2 y backups

Fecha: 2026-09-26  
Rama: `feat/roadmap-3-foundation`

## Objetivo

Demostrar que Roadmap 3 no elimina ni rompe las capacidades centrales de Roadmap 2 y que los backups antiguos siguen siendo restaurables.

## Cobertura automática existente

### Backups / compatibilidad

- `packages/core/test/core/services/backup_backward_compatibility_roadmap2_test.dart`
- `packages/core/test/core/services/backup_service_test.dart`
- `packages/core/test/core/services/backup_service_unilateral_v9_test.dart`
- `packages/core/test/core/services/habit_tasks_backup_v10_test.dart`
- `packages/core/test/core/services/user_experience_profile_backup_test.dart`
- `packages/core/test/features/programs/data/training_program_backup_shadow_test.dart`
- `packages/core/test/features/exercises/data/exercise_favorites_backup_test.dart`

Cobren compatibilidad de schemas anteriores, unilateral v9, incorporación de Habits v10, perfil Roadmap 3 y persistencia de Programas/Favoritos.

### Exercise Memory / progresión

- `packages/core/test/features/workout/application/exercise_memory_actions_test.dart`
- `packages/core/test/features/workout/application/exercise_performance_memory_test.dart`
- `packages/core/test/features/workout/application/progression_engine_test.dart`
- `packages/core/test/features/workout/application/progression_engine_cross_routine_test.dart`
- `packages/core/test/features/workout/application/progression_engine_rep_context_test.dart`

### Unilateral Pro

- `packages/core/test/domain/workout_set_unilateral_test.dart`
- `packages/core/test/features/workout/application/unilateral_set_coordinator_test.dart`
- `packages/core/test/features/workout/application/unilateral_set_coordinator_roadmap2_test.dart`
- `packages/core/test/features/progress/application/unilateral_progress_summary_test.dart`

### Progreso 2.0

- `packages/core/test/features/progress/application/exercise_progress_calculator_test.dart`
- `packages/core/test/features/progress/application/exercise_progress_roadmap2_test.dart`
- `packages/core/test/features/progress/application/calendar_heatmap_calculator_test.dart`
- `packages/core/test/core/utils/fitness_formatter_progression_context_test.dart`

### Programas / rotación

- `packages/core/test/features/programs/application/program_rotation_coordinator_test.dart`
- `packages/core/test/features/programs/application/program_schedule_projector_test.dart`
- `packages/core/test/features/programs/application/training_program_template_test.dart`
- `packages/core/test/features/programs/data/training_program_backup_shadow_test.dart`

Incluye continuidad de rotación, idempotencia, sesiones off-sequence, días omitidos, cambio de días disponibles, deload, pausa/reanudación y backup/restore de posición.

## Gate de migración R2 → R3

El workflow de CI prepara un escenario incremental:

1. retira temporalmente las migraciones Roadmap 3;
2. arranca/reconstruye Supabase con las 3 migraciones existentes en Roadmap 2;
3. restaura las 9 migraciones Roadmap 3;
4. ejecuta `supabase migration up --local`;
5. ejecuta pgTAP sobre el esquema actualizado;
6. después ejecuta un `supabase db reset` con toda la cadena y vuelve a ejecutar pgTAP.

Esto valida tanto **upgrade incremental** como **instalación limpia**.

## Lo que sigue siendo manual

Aunque todos los tests anteriores estén verdes, L01 y L06 siguen siendo necesarios al final:

- instalar sobre una copia real con datos Roadmap 2;
- comprobar visualmente datos relevantes;
- crear/restaurar un backup real end-to-end.

Esos smokes no deben sustituirse por afirmaciones automáticas.

## Criterio de cierre

H3/H11 pueden pasar a evidencia automática verde cuando el candidato final ejecute:
- Core tests completos;
- Mobile/Web tests;
- nuevo gate R2→R3 de Supabase;
- pgTAP;
- builds de plataforma.

La validación física de datos reales permanece en L01/L06.
