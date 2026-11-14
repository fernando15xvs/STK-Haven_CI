import 'package:core/features/coach/presentation/pages/coach_connections_page.dart';
import 'package:core/features/profile/presentation/pages/appearance_settings_page.dart';
import 'package:core/features/profile/presentation/pages/experience_preferences_page.dart';
import 'package:core/features/profile/presentation/pages/notifications_settings_page.dart';
import 'package:core/features/profile/presentation/pages/personal_profile_page.dart';
import 'package:core/features/profile/presentation/pages/training_preferences_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/profile/presentation/widgets/personal_profile_summary.dart';
import 'package:core/features/profile/presentation/widgets/platform_settings_page.dart';
import 'package:core/features/sync/presentation/backup_status_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/section_heading.dart';
import 'package:gym_tracker/features/faith/presentation/pages/favorites_page.dart';
import 'package:gym_tracker/features/profile/presentation/pages/achievements_page.dart';

/// Identity and app preferences. Routines/programs live in Entrenar,
/// performance metrics in Progreso and Motivation in the global + menu.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );

    return Scaffold(
      // The bottom dock identifies Perfil; preserve only the device safe area.
      body: SafeArea(
        bottom: false,
        child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          const SizedBox(height: AppSpacing.md),
          PersonalProfileSummary(
            onEdit: () => _open(context, const PersonalProfilePage()),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeading(title: 'PREFERENCIAS'),
          const SizedBox(height: AppSpacing.sm),
          _ProfileGroup(
            entries: [
              _ProfileLink(
                icon: Icons.palette_outlined,
                title: 'Aspecto',
                subtitle: 'Modo claro, oscuro, OLED y colores',
                onTap: () => _open(context, const AppearanceSettingsPage()),
              ),
              _ProfileLink(
                icon: Icons.tune_rounded,
                title: 'Tu experiencia',
                subtitle: 'Objetivos, recomendaciones y contenido de Fe',
                onTap: () => _open(context, const ExperiencePreferencesPage()),
              ),
              _ProfileLink(
                icon: Icons.fitness_center_outlined,
                title: 'Entrenamiento y unidades',
                subtitle: 'Peso, RIR, descanso y registro de series',
                onTap: () => _open(context, const TrainingPreferencesPage()),
              ),
              _ProfileLink(
                icon: Icons.notifications_none_rounded,
                title: 'Notificaciones',
                subtitle: 'Entrenamiento, agua, pasos y avisos',
                onTap: () => _open(context, const NotificationsSettingsPage()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeading(title: 'SERVICIOS Y PRIVACIDAD'),
          const SizedBox(height: AppSpacing.sm),
          _ProfileGroup(
            entries: [
              _ProfileLink(
                icon: Icons.sports_outlined,
                title: 'Mi Coach',
                subtitle: 'Vínculos y permisos para compartir datos',
                onTap: () =>
                    _open(context, const CoachConnectionsPage(clientOnly: true)),
              ),
              _ProfileLink(
                icon: Icons.cloud_sync_outlined,
                title: 'Datos y sincronización',
                subtitle: 'Copias de seguridad, cuenta y exportación',
                onTap: () => _open(context, const BackupStatusPage()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeading(title: 'RECONOCIMIENTOS'),
          const SizedBox(height: AppSpacing.sm),
          _ProfileGroup(
            entries: [
              _ProfileLink(
                icon: Icons.emoji_events_outlined,
                title: 'Nivel y logros',
                subtitle: 'Tu nivel, XP y medallas desbloqueadas',
                onTap: () => _open(context, const AchievementsPage()),
              ),
            ],
          ),
          if (faithEnabled) ...[
            const SizedBox(height: AppSpacing.xl),
            const SectionHeading(title: 'FE'),
            const SizedBox(height: AppSpacing.sm),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    title: Text(
                      'Mostrar tarjeta en Inicio',
                      style: AppTypography.headlineMedium,
                    ),
                    subtitle: const Text('Versículo diario de Fortaleza'),
                    value: settings.showDailyVerse,
                    onChanged: ref
                        .read(settingsProvider.notifier)
                        .setShowDailyVerse,
                  ),
                  Divider(height: 1, color: AppColors.of(context).surfaceBorder),
                  _ProfileLink(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Versículos favoritos',
                    subtitle: 'Tus versículos guardados',
                    onTap: () => _open(context, const FavoritesPage()),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const SectionHeading(title: 'APP'),
          const SizedBox(height: AppSpacing.sm),
          _ProfileGroup(
            entries: [
              _ProfileLink(
                icon: Icons.devices_outlined,
                title: 'App y dispositivo',
                subtitle: 'Rendimiento, accesibilidad y licencias',
                onTap: () => _open(context, const PlatformSettingsPage()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Center(
            child: Text(
              'STK Haven',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        ),
      ),
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.entries});

  final List<_ProfileLink> entries;

  @override
  Widget build(BuildContext context) => PremiumCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < entries.length; index++) ...[
              if (index > 0)
                Divider(height: 1, color: AppColors.of(context).surfaceBorder),
              entries[index],
            ],
          ],
        ),
      );
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(icon, color: colors.primary, size: 23),
      title: Text(title, style: AppTypography.headlineMedium),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
      onTap: onTap,
    );
  }
}
