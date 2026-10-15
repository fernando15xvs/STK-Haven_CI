import 'package:core/features/profile/presentation/pages/appearance_settings_page.dart';
import 'package:core/features/profile/presentation/pages/personal_profile_page.dart';
import 'package:core/features/profile/presentation/widgets/personal_profile_summary.dart';
import 'package:core/core/constants/preset_programs.dart';
import 'package:core/features/coach/presentation/pages/coach_connections_page.dart';
import 'package:core/features/profile/presentation/pages/experience_preferences_page.dart';
import 'package:core/features/profile/presentation/pages/notifications_settings_page.dart';
import 'package:core/features/profile/presentation/pages/training_preferences_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/profile/presentation/widgets/platform_settings_page.dart';
import 'package:core/features/onboarding/application/program_service.dart';
import 'package:core/features/sync/presentation/backup_status_page.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/section_heading.dart';
import 'package:gym_tracker/features/faith/presentation/pages/favorites_page.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/program_preview_modal.dart';
import 'package:gym_tracker/features/profile/presentation/pages/achievements_page.dart';

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
          PersonalProfileSummary(
            onEdit: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PersonalProfilePage()),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeading(title: 'CONFIGURACIÓN'),
          const SizedBox(height: AppSpacing.md),
          const SectionHeading(title: 'PERSONALIZACIÓN'),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.palette_outlined,
                color: AppColors.of(context).primary,
              ),
              title: Text('Aspecto', style: AppTypography.headlineMedium),
              subtitle: const Text('Modo de pantalla, colores y acabado'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppearanceSettingsPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.tune_rounded,
                color: AppColors.of(context).primary,
              ),
              title: Text(
                'Tu experiencia',
                style: AppTypography.headlineMedium,
              ),
              subtitle: Text(
                'Objetivo, días, duración, entorno y Fe',
                style: AppTypography.bodySmall,
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.of(context).textSecondary,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExperiencePreferencesPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.sports_outlined,
                color: AppColors.of(context).primary,
              ),
              title: Text('Mi Coach', style: AppTypography.headlineMedium),
              subtitle: Text(
                'Entrenador vinculado, invitaciones y permisos que compartes',
                style: AppTypography.bodySmall,
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.of(context).textSecondary,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CoachConnectionsPage(clientOnly: true),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeading(title: 'AJUSTES'),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.fitness_center_outlined,
                    color: AppColors.of(context).primary,
                  ),
                  title: Text(
                    'Entrenamiento y unidades',
                    style: AppTypography.headlineMedium,
                  ),
                  subtitle: Text(
                    'RIR, descansos, feedback, unilateral, peso e incrementos',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textSecondary,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrainingPreferencesPage(),
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.of(context).surfaceBorder),
                ListTile(
                  leading: Icon(
                    Icons.notifications_outlined,
                    color: AppColors.of(context).primary,
                  ),
                  title: Text(
                    'Notificaciones',
                    style: AppTypography.headlineMedium,
                  ),
                  subtitle: Text(
                    'Entrenamiento, agua, pasos y fortaleza diaria',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textSecondary,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsSettingsPage(),
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.of(context).surfaceBorder),
                ListTile(
                  leading: Icon(
                    Icons.cloud_sync_outlined,
                    color: AppColors.of(context).primary,
                  ),
                  title: Text(
                    'Datos y sincronización',
                    style: AppTypography.headlineMedium,
                  ),
                  subtitle: Text(
                    'Nube, copias locales, restauración y CSV',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textSecondary,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupStatusPage()),
                  ),
                ),
                Divider(height: 1, color: AppColors.of(context).surfaceBorder),
                ListTile(
                  leading: Icon(
                    Icons.devices_outlined,
                    color: AppColors.of(context).primary,
                  ),
                  title: Text(
                    'App y dispositivo',
                    style: AppTypography.headlineMedium,
                  ),
                  subtitle: Text(
                    'Rendimiento, accesibilidad, sensores y licencias',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textSecondary,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PlatformSettingsPage(),
                    ),
                  ),
                ),
              ],
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
                    title: Text(
                      settings.activeProgram!.programNameSnapshot,
                      style: AppTypography.headlineMedium,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Semana ${(DateTime.now().difference(settings.activeProgram!.startedAt).inDays / 7).floor() + 1} de ${settings.activeProgram!.durationWeeks}',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: AppColors.of(context).surfaceBorder,
                  ),
                  ListTile(
                    title: Text(
                      'Ver programa',
                      style: TextStyle(color: AppColors.of(context).primary),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppColors.of(context).textSecondary,
                    ),
                    onTap: () {
                      final p = presetPrograms.firstWhere(
                        (p) => p.id == settings.activeProgram!.presetProgramId,
                        orElse: () => presetPrograms.first,
                      );
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => ProgramPreviewModal(
                          program: p,
                          mode: ProgramPreviewMode.preview,
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: AppColors.of(context).surfaceBorder,
                  ),
                  ListTile(
                    title: Text(
                      'Cambiar programa',
                      style: TextStyle(color: AppColors.of(context).primary),
                    ),
                    trailing: Icon(
                      Icons.autorenew,
                      color: AppColors.of(context).textSecondary,
                    ),
                    onTap: () {
                      final activeWorkout = ref.read(activeWorkoutProvider);
                      if (activeWorkout.isActive) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Tienes un entrenamiento en curso. Finalízalo o descártalo antes de cambiar tu programa.',
                            ),
                          ),
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
              title: Text(
                'Nivel y Logros',
                style: AppTypography.headlineMedium,
              ),
              subtitle: Text(
                'Revisa tu progreso y medallas',
                style: AppTypography.bodySmall,
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.of(context).textSecondary,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AchievementsPage()),
                );
              },
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
                    title: Text(
                      'Mostrar tarjeta en Inicio',
                      style: AppTypography.headlineMedium,
                    ),
                    subtitle: Text(
                      'Fortaleza de hoy en tu dashboard',
                      style: AppTypography.bodySmall,
                    ),
                    value: settings.showDailyVerse,
                    onChanged: (val) => notifier.setShowDailyVerse(val),
                    activeThumbColor: AppColors.of(context).primary,
                  ),
                  Divider(
                    height: 1,
                    color: AppColors.of(context).surfaceBorder,
                  ),
                  ListTile(
                    title: Text(
                      'Versículos Favoritos',
                      style: AppTypography.headlineMedium,
                    ),
                    subtitle: Text(
                      'Revisa tus reflexiones guardadas',
                      style: AppTypography.bodySmall,
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppColors.of(context).textSecondary,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoritesPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          const SizedBox(height: AppSpacing.xxxl),
          Center(
            child: Text(
              'STK Haven v1.0.0 (RC)\nConstruido para ti',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.of(
                  context,
                ).textSecondary.withValues(alpha: 0.5),
                fontSize: 12,
              ),
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
        backgroundColor: AppColors.of(context).surfaceHigh,
        title: Text(
          'Cambiar programa',
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Tus entrenamientos realizados NO se eliminarán.\n\n¿Qué hacemos con las rutinas del programa actual?',
          style: TextStyle(
            color: AppColors.of(context).textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showProgramSelection(context, ref, keepOld: true);
            },
            child: Text(
              'CONSERVAR',
              style: TextStyle(color: AppColors.of(context).textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showProgramSelection(context, ref, keepOld: false);
            },
            child: Text(
              'REEMPLAZAR',
              style: TextStyle(
                color: AppColors.of(context).primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProgramSelection(
    BuildContext context,
    WidgetRef ref, {
    required bool keepOld,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  'Selecciona un programa',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...presetPrograms.map(
                (p) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${p.daysPerWeek} días • ${p.level}',
                    style: TextStyle(color: AppColors.of(context).primary),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textSecondary,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref
                        .read(programServiceProvider)
                        .replaceProgram(
                          p,
                          keepOld,
                          trainingDaysPerWeek: ref
                              .read(userExperienceProfileProvider)
                              .value
                              ?.trainingDaysPerWeek,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Programa ${p.name} activado')),
                      );
                    }
                  },
                ),
              ),
              Divider(color: AppColors.of(context).surfaceBorder),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                title: Text(
                  'Crear desde cero',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
                subtitle: Text(
                  'No instalar ninguna rutina nueva',
                  style: TextStyle(color: AppColors.of(context).textSecondary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(programServiceProvider)
                      .removeActiveProgram(keepGeneratedRoutines: keepOld);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
