import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/settings_state.dart';
import '../providers/settings_provider.dart';

class AppearanceSettingsPage extends ConsumerStatefulWidget {
  const AppearanceSettingsPage({super.key});
  @override
  ConsumerState<AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState
    extends ConsumerState<AppearanceSettingsPage> {
  bool _saving = false;
  Future<void> _save(AppearanceSettings value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).setAppearance(value);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el aspecto. Inténtalo de nuevo.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final appearance = settings.appearance;
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    const labels = {
      AppAccent.blue: 'Zafiro',
      AppAccent.violet: 'Amatista',
      AppAccent.emerald: 'Esmeralda',
      AppAccent.teal: 'Océano',
      AppAccent.rose: 'Rosa',
      AppAccent.amber: 'Ámbar',
      AppAccent.coral: 'Coral',
      AppAccent.slate: 'Pizarra',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Aspecto')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Tu espacio, a tu estilo',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Los cambios se aplican y guardan al elegirlos.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.surfaceBorder),
                  boxShadow: colors.shadows,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'VISTA PREVIA',
                            style: theme.textTheme.labelMedium?.copyWith(
                              letterSpacing: 1.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Cada día cuenta.',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Entrena. Registra. Sigue creciendo.'),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: .65,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                      backgroundColor: colors.primaryFaded,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Chip(
                          avatar: Icon(
                            Icons.check_circle_outline,
                            color: colors.primary,
                            size: 18,
                          ),
                          label: const Text('3 de 4 sesiones'),
                        ),
                        FilledButton(
                          onPressed: () {},
                          child: const Text('Continuar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Modo de pantalla', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in [
                    (AppThemeMode.light, 'Claro', Icons.light_mode_outlined),
                    (AppThemeMode.dark, 'Oscuro', Icons.dark_mode_outlined),
                    (
                      AppThemeMode.system,
                      'Automático',
                      Icons.brightness_auto_outlined,
                    ),
                  ])
                    ChoiceChip(
                      label: Text(entry.$2),
                      avatar: Icon(entry.$3, size: 18),
                      selected: appearance.mode == entry.$1,
                      onSelected: _saving
                          ? null
                          : (_) => _save(appearance.copyWith(mode: entry.$1)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Automático sigue el modo claro u oscuro de tu dispositivo.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Text('Color de acento', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final accent in AppAccent.values)
                    ChoiceChip(
                      label: Text(labels[accent]!),
                      avatar: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.from(
                            appearance.copyWith(accent: accent),
                            theme.brightness,
                          ).primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      selected: appearance.accent == accent,
                      onSelected: _saving
                          ? null
                          : (_) => _save(appearance.copyWith(accent: accent)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Acabado', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: const Text('Negro puro OLED'),
                      subtitle: const Text(
                        'Fondo negro en modo oscuro. El modo claro conserva su fondo suave.',
                      ),
                      value: appearance.oledBlack,
                      onChanged: _saving
                          ? null
                          : (v) => _save(appearance.copyWith(oledBlack: v)),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: const Text('Relieve sutil en tarjetas'),
                      subtitle: const Text(
                        'Desactívalo para un acabado plano y minimalista.',
                      ),
                      value: appearance.cardStyle == AppCardStyle.elevated,
                      onChanged: _saving
                          ? null
                          : (v) => _save(
                              appearance.copyWith(
                                cardStyle: v
                                    ? AppCardStyle.elevated
                                    : AppCardStyle.flat,
                              ),
                            ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: const Text('Reducir animaciones'),
                      subtitle: const Text(
                        'Una interfaz más tranquila. También respeta la preferencia del dispositivo.',
                      ),
                      value: settings.reduceMotion,
                      onChanged: ref
                          .read(settingsProvider.notifier)
                          .setReduceMotion,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => _save(const AppearanceSettings()),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restablecer colores y acabado'),
              ),
              if (_saving) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
