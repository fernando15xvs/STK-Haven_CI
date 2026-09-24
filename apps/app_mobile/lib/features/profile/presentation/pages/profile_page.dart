import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/platform/platform_capabilities.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/habits/application/habit_study_timer_provider.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/habits/application/study_plan_provider.dart';
import 'package:core/features/profile/presentation/pages/experience_preferences_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/core/services/backup_service.dart';
import 'package:core/core/services/backup_file_service.dart';
import 'package:core/features/onboarding/application/program_service.dart';
import 'package:core/core/constants/preset_programs.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/program_preview_modal.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/profile/application/data_export_service.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/section_heading.dart';
import 'package:gym_tracker/features/profile/presentation/pages/achievements_page.dart';
import 'package:gym_tracker/features/faith/presentation/pages/favorites_page.dart';

final _backupService = BackupService();
final _backupFileService = BackupFileService();

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes y Perfil')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          const SizedBox(height: AppSpacing.md),
          const CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.surfaceHigh,
            child: Icon(Icons.person, size: 50, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Center(child: Text('Atleta Principal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
          
          const SizedBox(height: AppSpacing.xxl),

          const SectionHeading(title: 'PERSONALIZACIÓN'),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.tune_rounded, color: AppColors.primary),
              title: Text(
                'Tu experiencia',
                style: AppTypography.headlineMedium,
              ),
              subtitle: Text(
                'Objetivo, días, duración, entorno, unidad, recordatorios y Fe',
                style: AppTypography.bodySmall,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExperiencePreferencesPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (settings.activeProgram != null) ...[
            const SectionHeading(title: 'PROGRAMA ACTUAL'),
            const SizedBox(height: AppSpacing.sm),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: Text(settings.activeProgram!.programNameSnapshot, style: AppTypography.headlineMedium),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Semana ${ (DateTime.now().difference(settings.activeProgram!.startedAt).inDays / 7).floor() + 1 } de ${settings.activeProgram!.durationWeeks}', style: AppTypography.bodySmall),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceBorder),
                  ListTile(
                    title: const Text('Ver programa', style: TextStyle(color: AppColors.primary)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () {
                      final p = presetPrograms.firstWhere((p) => p.id == settings.activeProgram!.presetProgramId, orElse: () => presetPrograms.first);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => ProgramPreviewModal(program: p, mode: ProgramPreviewMode.preview),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.surfaceBorder),
                  ListTile(
                    title: const Text('Cambiar programa', style: TextStyle(color: AppColors.primary)),
                    trailing: const Icon(Icons.autorenew, color: AppColors.textSecondary),
                    onTap: () {
                      final activeWorkout = ref.read(activeWorkoutProvider);
                      if (activeWorkout.isActive) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tienes un entrenamiento en curso. Finalízalo o descártalo antes de cambiar tu programa.')),
                        );
                        return;
                      }
                      _showChangeProgramDialog(context, ref);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          
          const SectionHeading(title: 'GAMIFICACIÓN'),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              title: Text('Nivel y Logros', style: AppTypography.headlineMedium),
              subtitle: Text('Revisa tu progreso y medallas', style: AppTypography.bodySmall),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsPage()));
              },
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          const SectionHeading(title: 'ENTRENAMIENTO'),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('RIR habilitado', style: AppTypography.headlineMedium),
                  subtitle: Text('Registro de repeticiones en reserva', style: AppTypography.bodySmall),
                  value: settings.isRirEnabled,
                  onChanged: (val) => notifier.setRirEnabled(val),
                  activeThumbColor: AppColors.primary,
                ),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                SwitchListTile(
                  title: Text('Descanso automático', style: AppTypography.headlineMedium),
                  subtitle: Text('Iniciar temporizador tras completar serie', style: AppTypography.bodySmall),
                  value: settings.autoRestEnabled,
                  onChanged: (val) => notifier.setAutoRestEnabled(val),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),

          if (faithEnabled) ...[
            const SectionHeading(title: 'FORTALEZA'),
            const SizedBox(height: AppSpacing.sm),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                SwitchListTile(
                  title: Text('Mostrar tarjeta en Inicio', style: AppTypography.headlineMedium),
                  subtitle: Text('Fortaleza de hoy en tu dashboard', style: AppTypography.bodySmall),
                  value: settings.showDailyVerse,
                  onChanged: (val) => notifier.setShowDailyVerse(val),
                  activeThumbColor: AppColors.primary,
                ),
                if (PlatformCapabilities.current.supportsLocalNotifications) ...[
                  const Divider(height: 1, color: AppColors.surfaceBorder),
                  SwitchListTile(
                    title: Text('Notificaciones diarias', style: AppTypography.headlineMedium),
                    subtitle: Text('Recibir la fortaleza de hoy (8:00 AM)', style: AppTypography.bodySmall),
                    value: settings.dailyVerseNotifications,
                    onChanged: notifier.setDailyVerseNotifications,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
                const Divider(height: 1, color: AppColors.surfaceBorder),
                ListTile(
                  title: Text('Versículos Favoritos', style: AppTypography.headlineMedium),
                  subtitle: Text('Revisa tus reflexiones guardadas', style: AppTypography.bodySmall),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage()));
                  },
                ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          
          const SectionHeading(title: 'UNIDADES'),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: Text('Peso', style: AppTypography.headlineMedium),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<WeightUnit>(
                      value: settings.weightUnit,
                      dropdownColor: AppColors.surfaceHigh,
                      items: WeightUnit.values.map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u.label.toUpperCase(), style: AppTypography.bodyMedium),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) notifier.setWeightUnit(val);
                      },
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                 Builder(builder: (context) {
                   final unit = settings.weightUnit;
                   final displayOptions = unit == WeightUnit.kg
                       ? [1.25, 2.5, 5.0]
                       : [2.5, 5.0, 10.0];

                   final currentDisplayValue = WeightConverter.displayWeight(
                       settings.defaultIncrement, unit);
                   double? selectedOption;
                   for (final opt in displayOptions) {
                     if ((opt - currentDisplayValue).abs() < 0.01) {
                       selectedOption = opt;
                       break;
                     }
                   }
                   selectedOption ??= displayOptions.reduce((a, b) =>
                       (a - currentDisplayValue).abs() < (b - currentDisplayValue).abs() ? a : b);

                   return ListTile(
                     title: Text('Incremento por defecto', style: AppTypography.headlineMedium),
                     subtitle: Text('Sugerencia de progreso en motores', style: AppTypography.bodySmall),
                     trailing: DropdownButtonHideUnderline(
                       child: DropdownButton<double>(
                         value: selectedOption,
                         dropdownColor: AppColors.surfaceHigh,
                         items: displayOptions.map((v) => DropdownMenuItem(
                           value: v,
                           child: Text(
                             '${v % 1 == 0 ? v.toInt() : v} ${unit.label}',
                             style: AppTypography.bodyMedium,
                           ),
                         )).toList(),
                         onChanged: (val) {
                           if (val != null) notifier.setDefaultIncrement(val, unit);
                         },
                       ),
                     ),
                   );
                 }),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          const SectionHeading(title: 'DATOS'),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file, color: AppColors.textPrimary),
                  title: Text('Exportar backup', style: AppTypography.headlineMedium),
                  subtitle: Text('Crear archivo .json de respaldo', style: AppTypography.bodySmall),
                  onTap: () async {
                    try {
                      final jsonString = _backupService.createBackup();
                      await _backupFileService.exportFile(jsonString);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
                      }
                    }
                  },
                ),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: AppColors.textPrimary),
                  title: Text('Exportar a CSV', style: AppTypography.headlineMedium),
                  subtitle: Text('Exportar tus entrenamientos a Excel', style: AppTypography.bodySmall),
                  onTap: () async {
                    final history = ref.read(workoutHistoryProvider);
                    if (history.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No hay entrenamientos para exportar.')),
                      );
                      return;
                    }
                    try {
                      await DataExportService().exportWorkoutsToCSV(history);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al exportar: $e')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                ListTile(
                  leading: const Icon(Icons.download, color: AppColors.textPrimary),
                  title: Text('Importar backup', style: AppTypography.headlineMedium),
                  subtitle: Text('Restaurar desde archivo .json', style: AppTypography.bodySmall),
                  onTap: () async {
                    final activeWorkout = ref.read(activeWorkoutProvider);
                    if (activeWorkout.session != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Termina tu entrenamiento actual antes de restaurar un backup.')),
                      );
                      return;
                    }

                    final jsonString = await _backupFileService.pickBackupFile();
                    if (jsonString == null) return; // User canceled

                    final result = _backupService.validateBackup(jsonString);
                    
                    if (!context.mounted) return;

                    if (!result.isValid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.errorMessage ?? 'Error desconocido al leer backup')),
                      );
                      return;
                    }

                    // Show confirmation
                    final parsed = result.parsedData!;
                    final routines = (parsed['routines'] as List).length;
                    final workouts = (parsed['workouts'] as List).length;
                    final exercises = (parsed['exercises'] as List).length;
                    final prs = (parsed['personalRecords'] as List).length;

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surfaceHigh,
                        title: const Text('BACKUP ENCONTRADO', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        content: Text(
                          'Contenido:\n\n$routines rutinas\n$workouts entrenamientos\n$exercises ejercicios\n$prs récords personales\n\nEste proceso reemplazará los datos actuales del dispositivo.',
                          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('RESTAURAR BACKUP', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await _backupService.restoreBackup(parsed);
                        await TrainingProgramRepository.fromHive()
                            .hydrateFromBackupMetadata();
                        ref.invalidate(settingsProvider);
                        ref.invalidate(userExperienceProfileProvider);
                        ref.invalidate(habitTasksProvider);
                        ref.invalidate(habitStudyTimerProvider);
                        ref.invalidate(studyPlanEnrollmentsProvider);
                        ref.invalidate(trainingProgramListProvider);
                        ref.invalidate(routineListProvider);
                        ref.invalidate(exerciseListProvider);
                        ref.invalidate(workoutHistoryProvider);
                        ref.invalidate(personalRecordRepositoryProvider);
                        ref.invalidate(bodyMeasurementProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✓ Backup restaurado correctamente')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error crítico al restaurar: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),
          Center(
            child: Text(
              'Gym Tracker v1.0.0 (RC)\nConstruido para ti',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 12),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  void _showChangeProgramDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Cambiar programa', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Tus entrenamientos realizados NO se eliminarán.\n\n¿Qué hacemos con las rutinas del programa actual?',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showProgramSelection(context, ref, keepOld: true);
            },
            child: const Text('CONSERVAR', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showProgramSelection(context, ref, keepOld: false);
            },
            child: const Text('REEMPLAZAR', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showProgramSelection(BuildContext context, WidgetRef ref, {required bool keepOld}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text('Selecciona un programa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...presetPrograms.map((p) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: Text('${p.daysPerWeek} días • ${p.level}', style: const TextStyle(color: AppColors.primary)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(programServiceProvider).replaceProgram(p, keepOld);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Programa ${p.name} activado')));
                  }
                },
              )),
              const Divider(color: AppColors.surfaceBorder),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                title: const Text('Crear desde cero', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: const Text('No instalar ninguna rutina nueva', style: TextStyle(color: AppColors.textSecondary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(programServiceProvider).removeActiveProgram(keepGeneratedRoutines: keepOld);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
