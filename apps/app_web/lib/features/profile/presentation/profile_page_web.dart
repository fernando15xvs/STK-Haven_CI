import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/constants/preset_programs.dart';
import 'package:core/core/services/backup_service.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/preset_program.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/onboarding/application/program_service.dart';
import 'package:core/features/profile/presentation/pages/experience_preferences_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
              children: [
                Text('Ajustes y perfil', style: AppTypography.displaySmall),
                const SizedBox(height: 6),
                Text(
                  '${routines.length} rutinas · ${history.length} entrenamientos · ${measurements.length} registros corporales',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _ProfileHeader(settings: settings),
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
                  title: 'Programa de entrenamiento',
                  child: _ProgramSection(
                    settings: settings,
                    activeWorkout: active,
                    onPreview: settings.activeProgram == null ? null : () => _previewActiveProgram(context, settings),
                    onChoose: () => _chooseProgram(context, ref),
                    onRemove: settings.activeProgram == null ? null : () => _removeProgram(context, ref),
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Gamificación',
                  child: _ActionTile(
                    icon: Icons.emoji_events_outlined,
                    title: 'Nivel y logros',
                    subtitle: 'Revisa tu XP, nivel y medallas desbloqueadas.',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsPageWeb())),
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
                        subtitle: const Text('Registrar repeticiones en reserva en cada serie.'),
                        value: settings.isRirEnabled,
                        onChanged: notifier.setRirEnabled,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Descanso automático'),
                        subtitle: const Text('Iniciar el temporizador de descanso al completar una serie.'),
                        value: settings.autoRestEnabled,
                        onChanged: notifier.setAutoRestEnabled,
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
                              .map((unit) => DropdownMenuItem(value: unit, child: Text(unit.label.toUpperCase())))
                              .toList(growable: false),
                          onChanged: (unit) {
                            if (unit != null) notifier.setWeightUnit(unit);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      _IncrementSelector(settings: settings, notifier: notifier),
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
                        subtitle: 'Descargar una copia JSON de todos tus datos.',
                        onTap: () => _exportBackup(context),
                      ),
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.download,
                        title: 'Importar backup',
                        subtitle: active.isActive
                            ? 'Finaliza o descarta tu entrenamiento activo antes de restaurar.'
                            : 'Restaurar rutinas, entrenamientos, ejercicios, PRs y ajustes.',
                        onTap: active.isActive ? null : () => _importBackup(context, ref),
                      ),
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.table_chart_outlined,
                        title: 'Exportar entrenamientos a CSV',
                        subtitle: 'Descargar el historial en un archivo compatible con Excel.',
                        onTap: history.isEmpty
                            ? null
                            : () async {
                                try {
                                  await DataExportService().exportWorkoutsToCSV(history);
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
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
                        _SmallStat(label: 'Rutinas', value: '${routines.length}'),
                        _SmallStat(label: 'Entrenos', value: '${history.length}'),
                        _SmallStat(label: 'Ejercicios', value: '${ref.watch(exerciseListProvider).length}'),
                        _SmallStat(label: 'PRs', value: '${ref.watch(personalRecordRepositoryProvider).getAllPRs().length}'),
                      ];
                      if (compact) {
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: cards.map((card) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: card)).toList(growable: false),
                        );
                      }
                      return Row(
                        children: cards
                            .map((card) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: card)))
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

  PresetProgram? _findProgram(String id) {
    for (final program in presetPrograms) {
      if (program.id == id) return program;
    }
    return null;
  }

  Future<void> _previewActiveProgram(BuildContext context, SettingsState settings) async {
    final active = settings.activeProgram;
    if (active == null) return;
    final program = _findProgram(active.presetProgramId);
    if (program == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró la definición del programa actual.')));
      return;
    }
    await _showProgramPreview(context, program);
  }

  Future<void> _chooseProgram(BuildContext context, WidgetRef ref) async {
    if (ref.read(activeWorkoutProvider).isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finaliza o descarta el entrenamiento en curso antes de cambiar de programa.')),
      );
      return;
    }

    final selected = await showDialog<PresetProgram>(
      context: context,
      builder: (_) => const _ProgramPickerDialog(),
    );
    if (selected == null || !context.mounted) return;

    final activate = await _showProgramPreview(context, selected, allowActivate: true);
    if (activate != true || !context.mounted) return;

    final current = ref.read(settingsProvider).activeProgram;
    try {
      if (current == null) {
        await ref.read(programServiceProvider).installProgram(selected);
      } else {
        final keepOld = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cambiar programa'),
            content: const Text(
              'Tus entrenamientos realizados se conservarán. ¿Quieres conservar también las rutinas generadas por el programa actual?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              OutlinedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Conservar rutinas')),
              FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Reemplazar rutinas')),
            ],
          ),
        );
        if (keepOld == null) return;
        await ref.read(programServiceProvider).replaceProgram(selected, keepOld);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Programa ${selected.name} activado.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo activar el programa: $error')));
      }
    }
  }

  Future<void> _removeProgram(BuildContext context, WidgetRef ref) async {
    if (ref.read(activeWorkoutProvider).isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finaliza o descarta el entrenamiento en curso antes de quitar el programa.')),
      );
      return;
    }

    final keepRoutines = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrenar sin programa'),
        content: const Text('Puedes quitar el programa actual y seguir usando rutinas creadas por ti. ¿Qué hacemos con las rutinas generadas por el programa?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          OutlinedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Conservar rutinas')),
          FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Eliminar rutinas del programa')),
        ],
      ),
    );
    if (keepRoutines == null) return;

    await ref.read(programServiceProvider).removeActiveProgram(keepGeneratedRoutines: keepRoutines);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Programa desactivado. Tus entrenamientos anteriores se mantienen.')));
    }
  }

  Future<bool?> _showProgramPreview(BuildContext context, PresetProgram program, {bool allowActivate = false}) {
    const dayNames = {1: 'Lun', 2: 'Mar', 3: 'Mié', 4: 'Jue', 5: 'Vie', 6: 'Sáb', 7: 'Dom'};
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(program.name),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(program.level)),
                    Chip(label: Text('${program.daysPerWeek} días/semana')),
                    Chip(label: Text('${program.durationWeeks} semanas')),
                  ],
                ),
                const SizedBox(height: 12),
                Text(program.description, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 18),
                Text('RUTINAS', style: AppTypography.labelLarge),
                const SizedBox(height: 8),
                ...program.routines.map(
                  (routine) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.md_, border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(routine.name, style: AppTypography.headlineSmall),
                        const SizedBox(height: 3),
                        Text(
                          '${routine.scheduledDays.map((day) => dayNames[day] ?? '$day').join(', ')} · ${routine.exercises.length} ejercicios',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cerrar')),
          if (allowActivate) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Usar este programa')),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final json = _backupService.createBackup();
      await _backupFiles.exportFile(json);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $error')));
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final json = await _backupFiles.pickBackupFile();
    if (json == null || !context.mounted) return;

    final validation = _backupService.validateBackup(json);
    if (!validation.isValid || validation.parsedData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.errorMessage ?? 'El archivo de backup no es válido.')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _backupService.restoreBackup(parsed);
      ref.invalidate(settingsProvider);
      ref.invalidate(routineListProvider);
      ref.invalidate(exerciseListProvider);
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(personalRecordRepositoryProvider);
      ref.invalidate(bodyMeasurementProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restaurado correctamente.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al restaurar: $error')));
      }
    }
  }
}

class _ProgramSection extends StatelessWidget {
  final SettingsState settings;
  final ActiveWorkoutState activeWorkout;
  final VoidCallback? onPreview;
  final VoidCallback onChoose;
  final VoidCallback? onRemove;

  const _ProgramSection({
    required this.settings,
    required this.activeWorkout,
    required this.onPreview,
    required this.onChoose,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final program = settings.activeProgram;
    if (program == null) {
      return _ActionTile(
        icon: Icons.calendar_month_outlined,
        title: 'Elegir programa',
        subtitle: 'Instala un plan predefinido o continúa creando tus propias rutinas.',
        onTap: activeWorkout.isActive ? null : onChoose,
      );
    }

    final week = ((DateTime.now().difference(program.startedAt).inDays / 7).floor() + 1).clamp(1, program.durationWeeks);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
          title: Text(program.programNameSnapshot, style: AppTypography.headlineSmall),
          subtitle: Text('Semana $week de ${program.durationWeeks}'),
        ),
        const Divider(height: 1),
        _ActionTile(icon: Icons.visibility_outlined, title: 'Ver programa', subtitle: 'Consulta duración, días y rutinas incluidas.', onTap: onPreview),
        const Divider(height: 1),
        _ActionTile(
          icon: Icons.autorenew,
          title: 'Cambiar programa',
          subtitle: activeWorkout.isActive ? 'Hay un entrenamiento en curso.' : 'Selecciona otro programa y decide qué hacer con las rutinas actuales.',
          onTap: activeWorkout.isActive ? null : onChoose,
        ),
        const Divider(height: 1),
        _ActionTile(
          icon: Icons.remove_circle_outline,
          title: 'Entrenar sin programa',
          subtitle: 'Quita el programa activo sin borrar tu historial.',
          onTap: activeWorkout.isActive ? null : onRemove,
        ),
      ],
    );
  }
}

class _ProgramPickerDialog extends StatelessWidget {
  const _ProgramPickerDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: const Text('Selecciona un programa'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: presetPrograms.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final program = presetPrograms[index];
            return Material(
              color: AppColors.surface,
              borderRadius: AppRadius.md_,
              child: InkWell(
                borderRadius: AppRadius.md_,
                onTap: () => Navigator.pop(context, program),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(borderRadius: AppRadius.md_, border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.sm_),
                        child: const Icon(Icons.fitness_center, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(program.name, style: AppTypography.headlineSmall),
                            const SizedBox(height: 3),
                            Text('${program.level} · ${program.daysPerWeek} días/semana · ${program.durationWeeks} semanas', style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final SettingsState settings;

  const _ProfileHeader({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.surfaceHigh,
            child: Icon(Icons.person, size: 36, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Atleta Principal', style: AppTypography.headlineLarge),
                const SizedBox(height: 4),
                Text(
                  settings.activeProgram == null ? 'Entrenamiento personalizado' : settings.activeProgram!.programNameSnapshot,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncrementSelector extends StatelessWidget {
  final SettingsState settings;
  final SettingsNotifier notifier;

  const _IncrementSelector({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final unit = settings.weightUnit;
    final options = unit == WeightUnit.kg ? <double>[1.25, 2.5, 5] : <double>[2.5, 5, 10];
    final current = WeightConverter.displayWeight(settings.defaultIncrement, unit);
    var selected = options.first;
    for (final option in options) {
      if ((option - current).abs() < (selected - current).abs()) selected = option;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Incremento por defecto'),
      subtitle: const Text('Paso usado en las sugerencias de progresión.'),
      trailing: DropdownButton<double>(
        value: selected,
        items: options
            .map((value) => DropdownMenuItem(value: value, child: Text('${value % 1 == 0 ? value.toInt() : value} ${unit.label}')))
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
        Text(title.toUpperCase(), style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.lg_, border: Border.all(color: AppColors.border)),
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

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      leading: Icon(icon, color: onTap == null ? AppColors.textDisabled : AppColors.primary),
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
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.md_),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTypography.headlineLarge),
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
