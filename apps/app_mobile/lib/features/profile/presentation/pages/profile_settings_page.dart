import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/app_ui_styles.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/section_heading.dart';
import 'package:gym_tracker/features/coach/presentation/pages/coach_connections_page.dart';
import 'package:gym_tracker/features/faith/presentation/pages/favorites_page.dart';
import 'package:gym_tracker/features/profile/presentation/pages/appearance_settings_page.dart';
import 'package:gym_tracker/features/profile/presentation/pages/notifications_settings_page.dart';
import 'package:gym_tracker/features/profile/presentation/pages/training_preferences_page.dart';
import 'package:gym_tracker/features/profile/presentation/pages/stk_mobile_privacy_page.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/platform_settings_page.dart';
import 'package:gym_tracker/features/sync/presentation/backup_status_page.dart';

/// Central owner of configuration. The Perfil tab remains a read-only identity
/// dashboard with a secondary Editar action, not a list of preferences.
class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _changeTheme(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode mode,
  ) async {
    try {
      final current = ref.read(settingsProvider).appearance;
      await ref.read(settingsProvider.notifier).setAppearance(
        current.copyWith(mode: mode),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo cambiar el tema. Inténtalo de nuevo.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );
    final colors = AppColors.of(context);
    final tokens = AppUiTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: tokens.pageHorizontalPadding),
          children: [
            const SizedBox(height: 12),
            Text('Aspecto rápido', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('settings_quick_light'),
                  avatar: const Icon(Icons.light_mode_outlined, size: 18),
                  label: const Text('Claro'),
                  selected: settings.appearance.mode == AppThemeMode.light,
                  onSelected: (_) => _changeTheme(context, ref, AppThemeMode.light),
                ),
                ChoiceChip(
                  key: const ValueKey('settings_quick_dark'),
                  avatar: const Icon(Icons.dark_mode_outlined, size: 18),
                  label: const Text('Oscuro'),
                  selected: settings.appearance.mode == AppThemeMode.dark,
                  onSelected: (_) => _changeTheme(context, ref, AppThemeMode.dark),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              settings.appearance.mode == AppThemeMode.system
                  ? 'Modo automático activo. Puedes cambiarlo en Aspecto.'
                  : 'Puedes activar el modo automático dentro de Aspecto.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: tokens.sectionGap),
            const SectionHeading(title: 'PREFERENCIAS'),
            const SizedBox(height: 10),
            _SettingsGroup(entries: [
              _SettingsLink(
                icon: Icons.palette_outlined,
                title: 'Aspecto',
                subtitle: 'Estilos, tipografía, tamaño, claro, oscuro y OLED',
                onTap: () => _open(context, const AppearanceSettingsPage()),
              ),
              _SettingsLink(
                icon: Icons.fitness_center_outlined,
                title: 'Entrenamiento y unidades',
                subtitle: 'Peso, RIR, descanso y registro de series',
                onTap: () => _open(context, const TrainingPreferencesPage()),
              ),
              _SettingsLink(
                icon: Icons.notifications_none_rounded,
                title: 'Notificaciones',
                subtitle: 'Entrenamiento, agua, pasos y avisos',
                onTap: () => _open(context, const NotificationsSettingsPage()),
              ),
            ]),
            SizedBox(height: tokens.sectionGap),
            const SectionHeading(title: 'SERVICIOS Y PRIVACIDAD'),
            const SizedBox(height: 10),
            _SettingsGroup(entries: [
              _SettingsLink(
                icon: Icons.sports_outlined,
                title: 'Mi Coach',
                subtitle: 'Vínculos y permisos para compartir datos',
                onTap: () => _open(context, const CoachConnectionsPage(clientOnly: true)),
              ),
              _SettingsLink(
                icon: Icons.cloud_sync_outlined,
                title: 'Datos y sincronización',
                subtitle: 'Copias, cuenta y exportación',
                onTap: () => _open(context, const BackupStatusPage()),
              ),
              _SettingsLink(
                icon: Icons.policy_outlined,
                title: 'Legal y privacidad',
                subtitle: 'Términos y uso de datos',
                onTap: () => _open(context, const StkMobilePrivacyPage()),
              ),
            ]),
            if (faithEnabled) ...[
              SizedBox(height: tokens.sectionGap),
              const SectionHeading(title: 'FE'),
              const SizedBox(height: 10),
              PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsLink(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Versículos favoritos',
                      subtitle: 'Tus versículos guardados',
                      onTap: () => _open(context, const FavoritesPage()),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: tokens.sectionGap),
            const SectionHeading(title: 'APP'),
            const SizedBox(height: 10),
            _SettingsGroup(entries: [
              _SettingsLink(
                icon: Icons.devices_outlined,
                title: 'App y dispositivo',
                subtitle: 'Rendimiento, accesibilidad y licencias',
                onTap: () => _open(context, const PlatformSettingsPage()),
              ),
            ]),
            SizedBox(height: tokens.sectionGap),
            Center(child: Text('STK Haven',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.entries});
  final List<_SettingsLink> entries;

  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: EdgeInsets.zero,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Divider(height: 1, color: AppColors.of(context).surfaceBorder),
          entries[i],
        ],
      ],
    ),
  );
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
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
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppUiTokens.of(context).cardPadding),
      leading: Icon(icon, color: colors.primary, size: 23),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.textSecondary,
        )),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
      onTap: onTap,
    );
  }
}
