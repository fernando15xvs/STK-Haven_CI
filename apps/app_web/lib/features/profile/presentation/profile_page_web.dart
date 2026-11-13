import 'package:core/features/profile/presentation/pages/appearance_settings_page.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/services/backup_service.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/coach/presentation/pages/coach_connections_page.dart';
import 'package:core/features/habits/application/habit_study_timer_provider.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/habits/application/study_plan_provider.dart';
import 'package:core/features/profile/presentation/pages/experience_preferences_page.dart';
import 'package:core/features/profile/presentation/pages/personal_profile_page.dart';
import 'package:core/features/profile/presentation/widgets/personal_profile_summary.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';

import '../../../core/services/backup_file_service_web.dart';
import '../../../core/theme/app_colors.dart';
import '../../faith/presentation/favorites_page_web.dart';
import '../application/data_export_service_web.dart';
import 'achievements_page_web.dart';
import 'web_notification_settings_page.dart';

class ProfilePageWeb extends ConsumerWidget {
  const ProfilePageWeb({super.key});

  static final BackupService _backupService = BackupService();
  static final BackupFileService _backupFiles = BackupFileService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final history = ref.watch(workoutHistoryProvider);
    final routines = ref.watch(routineListProvider);
    final measurements = ref.watch(bodyMeasurementProvider);
    final active = ref.watch(activeWorkoutProvider);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
              children: [
                Text('Mi perfil', style: AppTypography.displaySmall),
                const SizedBox(height: 6),
                Text(
                  '${routines.length} rutinas · ${history.length} entrenamientos · ${measurements.length} registros corporales',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                PersonalProfileSummary(
                  onEdit: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PersonalProfilePage()),
                  ),
                ),
                const SizedBox(height: 16),
                Text('CONFIGURACIÓN', style: AppTypography.labelLarge),
                const SizedBox(height: 18),
                _Section(
                  title: 'Personalización',
                  child: _ActionTile(
                    icon: Icons.tune_rounded,
                    title: 'Tu experiencia',
                    subtitle:
                        'Objetivo, días, duración, entorno, unidad, recordatorios y Fe.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ExperiencePreferencesPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Web y PWA',
                  child: _ActionTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notificaciones y alarmas',
                    subtitle:
                        'Web Push, permiso del navegador y sonido de alarmas.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WebNotificationSettingsPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Coach & Clientes',
                  child: _ActionTile(
                    icon: Icons.groups_2_outlined,
                    title: 'Conexiones',
                    subtitle:
                        'Invitaciones, consentimiento, permisos y relaciones vinculadas.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CoachConnectionsPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Coach Pro',
                  child: _ActionTile(
                    icon: Icons.dashboard_outlined,
                    title: 'Cartera profesional',
                    subtitle:
                        'Seguimiento y resumen de tus clientes vinculados.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CoachProDashboardPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Gamificación',
                  child: _ActionTile(
                    icon: Icons.emoji_events_outlined,
                    title: 'Nivel y logros',
                    subtitle: 'Revisa tu XP, nivel y medallas desbloqueadas.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AchievementsPageWeb(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Aspecto',
                  child: _ActionTile(
                    icon: Icons.palette_outlined,
                    title: 'Personalizar aspecto',
                    subtitle:
                        'Modo claro, oscuro o automático; colores y acabado.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AppearanceSettingsPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Entrenamiento',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('RIR habilitado'),
                        subtitle: const Text(
                          'Registrar repeticiones en reserva en cada serie.',
                        ),
                        value: settings.isRirEnabled,
                        onChanged: notifier.setRirEnabled,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Descanso automático'),
                        subtitle: const Text(
                          'Iniciar el temporizador de descanso al completar una serie.',
                        ),
                        value: settings.autoRestEnabled,
                        onChanged: notifier.setAutoRestEnabled,
                      ),
                      ListTile(
                        title: const Text('Tiempo de descanso según'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButton<RestTimingMode>(
                              isExpanded: true,
                              value: settings.restTimingMode,
                              items: const [
                                DropdownMenuItem(
                                  value: RestTimingMode.completedSet,
                                  child: Text('La serie completada'),
                                ),
                                DropdownMenuItem(
                                  value: RestTimingMode.nextSet,
                                  child: Text('La siguiente serie'),
                                ),
                              ],
                              onChanged: settings.autoRestEnabled
                                  ? (value) {
                                      if (value != null)
                                        notifier.setRestTimingMode(value);
                                    }
                                  : null,
                            ),
                            const Text(
                              'Siguiente serie: usa su descanso, incluso al cambiar de ejercicio. Sigue el orden de la sesión. Las superseries mantienen el descanso por ronda; entre lados se usa su tiempo propio.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (faithEnabled) ...[
                  const SizedBox(height: 18),
                  _Section(
                    title: 'Fortaleza',
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mostrar mensaje diario en Inicio'),
                          subtitle: const Text(
                            'Muestra el versículo o fortaleza del día en el dashboard web.',
                          ),
                          value: settings.showDailyVerse,
                          onChanged: notifier.setShowDailyVerse,
                        ),
                        const Divider(height: 1),
                        _ActionTile(
                          icon: Icons.bookmarks_outlined,
                          title: 'Versículos favoritos',
                          subtitle:
                              'Consulta y administra los versículos que guardaste.',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FavoritesPageWeb(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _Section(
                  title: 'Unidades',
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Unidad de peso'),
                        trailing: DropdownButton<WeightUnit>(
                          value: settings.weightUnit,
                          items: WeightUnit.values
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit.label.toUpperCase()),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (unit) {
                            if (unit != null) notifier.setWeightUnit(unit);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      _IncrementSelector(
                        settings: settings,
                        notifier: notifier,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Datos',
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.upload_file,
                        title: 'Exportar backup',
                        subtitle:
                            'Descargar una copia JSON de todos tus datos.',
                        onTap: () => _exportBackup(context),
                      ),
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.download,
                        title: 'Importar backup',
                        subtitle: active.isActive
                            ? 'Finaliza o descarta tu entrenamiento activo antes de restaurar.'
                            : 'Restaurar rutinas, entrenamientos, ejercicios, PRs y ajustes.',
                        onTap: active.isActive
                            ? null
                            : () => _importBackup(context, ref),
                      ),
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.table_chart_outlined,
                        title: 'Exportar entrenamientos a CSV',
                        subtitle:
                            'Descargar el historial en un archivo compatible con Excel.',
                        onTap: history.isEmpty
                            ? null
                            : () async {
                                try {
                                  await DataExportService().exportWorkoutsToCSV(
                                    history,
                                  );
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'No se pudo exportar: $error',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Estado local',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 600;
                      final cards = [
                        _SmallStat(
                          label: 'Rutinas',
                          value: '${routines.length}',
                        ),
                        _SmallStat(
                          label: 'Entrenos',
                          value: '${history.length}',
                        ),
                        _SmallStat(
                          label: 'Ejercicios',
                          value: '${ref.watch(exerciseListProvider).length}',
                        ),
                        _SmallStat(
                          label: 'PRs',
                          value:
                              '${ref.watch(personalRecordRepositoryProvider).getAllPRs().length}',
                        ),
                      ];
                      if (compact) {
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: cards
                              .map(
                                (card) => SizedBox(
                                  width: (constraints.maxWidth - 10) / 2,
                                  child: card,
                                ),
                              )
                              .toList(growable: false),
                        );
                      }
                      return Row(
                        children: cards
                            .map(
                              (card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: card,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final json = _backupService.createBackup();
      await _backupFiles.exportFile(json);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar: $error')));
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final json = await _backupFiles.pickBackupFile();
    if (json == null || !context.mounted) return;

    final validation = _backupService.validateBackup(json);
    if (!validation.isValid || validation.parsedData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            validation.errorMessage ?? 'El archivo de backup no es válido.',
          ),
        ),
      );
      return;
    }

    final parsed = validation.parsedData!;
    final routines = (parsed['routines'] as List?)?.length ?? 0;
    final workouts = (parsed['workouts'] as List?)?.length ?? 0;
    final exercises = (parsed['exercises'] as List?)?.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: Text(
          'El archivo contiene $routines rutinas, $workouts entrenamientos y $exercises ejercicios.\n\nLa restauración reemplazará los datos locales actuales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _backupService.restoreBackup(parsed);
      await TrainingProgramRepository.fromHive().hydrateFromBackupMetadata();
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
          const SnackBar(content: Text('Backup restaurado correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al restaurar: $error')));
      }
    }
  }
}

class _IncrementSelector extends StatelessWidget {
  final SettingsState settings;
  final SettingsNotifier notifier;

  const _IncrementSelector({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final unit = settings.weightUnit;
    final options = unit == WeightUnit.kg
        ? <double>[1.25, 2.5, 5]
        : <double>[2.5, 5, 10];
    final current = WeightConverter.displayWeight(
      settings.defaultIncrement,
      unit,
    );
    var selected = options.first;
    for (final option in options) {
      if ((option - current).abs() < (selected - current).abs())
        selected = option;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Incremento por defecto'),
      subtitle: const Text('Paso usado en las sugerencias de progresión.'),
      trailing: DropdownButton<double>(
        value: selected,
        items: options
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(
                  '${value % 1 == 0 ? value.toInt() : value} ${unit.label}',
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) notifier.setDefaultIncrement(value, unit);
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.of(context).textSecondary,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: AppRadius.lg_,
            border: Border.all(color: AppColors.of(context).border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      leading: Icon(
        icon,
        color: onTap == null
            ? AppColors.of(context).textDisabled
            : AppColors.of(context).primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;

  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceHigh,
        borderRadius: AppRadius.md_,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTypography.headlineLarge),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
