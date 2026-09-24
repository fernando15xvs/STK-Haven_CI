import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/pages/training_preferences_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/profile/presentation/widgets/platform_settings_page.dart';
import 'package:core/features/programs/presentation/pages/training_programs_page.dart';
import 'package:core/features/progress/presentation/pages/progress_intelligence_page.dart';
import 'package:core/features/sync/presentation/backup_status_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/faith/presentation/ai_chat_page_web.dart';
import '../../features/faith/presentation/bible_reader_page_web.dart';
import '../../features/faith/presentation/faith_hub_page_web.dart';
import '../../features/home/presentation/home_page_web.dart';
import '../../features/profile/presentation/profile_page_web.dart';
import '../../features/progress/presentation/progress_page_web.dart';
import '../../features/routines/presentation/routines_page_web.dart';
import '../../features/tools/presentation/training_tools_page_web.dart';

class WebLayout extends ConsumerStatefulWidget {
  const WebLayout({super.key});

  @override
  ConsumerState<WebLayout> createState() => _WebLayoutState();
}

class _WebLayoutState extends ConsumerState<WebLayout> {
  int _selectedIndex = 0;
  final Set<int> _visited = <int>{0};

  static const List<Widget> _pages = [
    HomePageWeb(),
    RoutinesPageWeb(),
    TrainingProgramsPage(),
    ProgressPageWeb(),
    FaithHubPageWeb(),
    ProfilePageWeb(),
    TrainingToolsPageWeb(),
  ];

  static const List<NavigationRailDestination> _desktopDestinations = [
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Inicio'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.fitness_center_outlined),
      selectedIcon: Icon(Icons.fitness_center),
      label: Text('Rutinas'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.layers_outlined),
      selectedIcon: Icon(Icons.layers),
      label: Text('Programas'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: Text('Progreso'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome),
      label: Text('Fe'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Perfil'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.build_outlined),
      selectedIcon: Icon(Icons.build),
      label: Text('Herramientas'),
    ),
  ];

  void _select(int index) {
    if (index < 0 || index >= _pages.length || index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      _visited.add(index);
    });
  }

  Widget _content([int? selectedIndex]) => IndexedStack(
        index: selectedIndex ?? _selectedIndex,
        children: List<Widget>.generate(
          _pages.length,
          (index) =>
              _visited.contains(index) ? _pages[index] : const SizedBox.shrink(),
          growable: false,
        ),
      );

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openQuickMenu({required bool faithEnabled}) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        void open(Widget page) {
          Navigator.of(sheetContext).pop();
          _open(page);
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accesos rápidos',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _QuickMenuTile(
                  icon: Icons.layers_outlined,
                  title: 'Programas 2.0',
                  subtitle: 'Rotación A/B/C, mesociclos y descarga.',
                  onTap: () => open(const TrainingProgramsPage()),
                ),
                const SizedBox(height: 10),
                _QuickMenuTile(
                  icon: Icons.insights_rounded,
                  title: 'Inteligencia de progreso',
                  subtitle: 'Última vs anterior, tendencias y unilateral.',
                  onTap: () => open(const ProgressIntelligencePage()),
                ),
                if (faithEnabled) ...[
                  const SizedBox(height: 10),
                  _QuickMenuTile(
                    icon: Icons.menu_book_outlined,
                    title: 'La Biblia',
                    subtitle: 'Lee por libro y capítulo.',
                    onTap: () => open(const BibleReaderPageWeb()),
                  ),
                  const SizedBox(height: 10),
                  _QuickMenuTile(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Haven Faith',
                    subtitle: 'Abre tu chat de acompañamiento.',
                    onTap: () => open(const AiChatPageWeb()),
                  ),
                ],
                const SizedBox(height: 10),
                _QuickMenuTile(
                  icon: Icons.build_outlined,
                  title: 'Herramientas',
                  subtitle: '1RM, temporizador y discos.',
                  onTap: () => open(const TrainingToolsPageWeb()),
                ),
                const SizedBox(height: 10),
                _QuickMenuTile(
                  icon: Icons.tune_rounded,
                  title: 'Preferencias de entrenamiento',
                  subtitle: 'RIR, descanso, memoria, sonido, vibración y unilateral.',
                  onTap: () => open(const TrainingPreferencesPage()),
                ),
                const SizedBox(height: 10),
                _QuickMenuTile(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Estado de copias',
                  subtitle: 'Última copia local, nube y dirección de restauración.',
                  onTap: () => open(const BackupStatusPage()),
                ),
                const SizedBox(height: 10),
                _QuickMenuTile(
                  icon: Icons.devices_outlined,
                  title: 'Plataforma y sincronización',
                  subtitle: 'Cuenta, recordatorios, rendimiento y accesibilidad.',
                  onTap: () => open(const PlatformSettingsPage()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showShortcutHelp({required bool faithEnabled}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Atajos de teclado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ctrl/⌘ + 1  Inicio'),
            const Text('Ctrl/⌘ + 2  Rutinas'),
            const Text('Ctrl/⌘ + 3  Programas'),
            const Text('Ctrl/⌘ + 4  Progreso'),
            if (faithEnabled) const Text('Ctrl/⌘ + 5  Fe'),
            const Text('Ctrl/⌘ + 6  Perfil'),
            const Text('Ctrl/⌘ + 7  Herramientas'),
            const SizedBox(height: 8),
            const Text('Ctrl/⌘ + K  Accesos rápidos'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Map<ShortcutActivator, Intent> get _shortcuts => <ShortcutActivator, Intent>{
        for (var index = 0; index < 7; index++) ...{
          SingleActivator(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
              LogicalKeyboardKey.digit5,
              LogicalKeyboardKey.digit6,
              LogicalKeyboardKey.digit7,
            ][index],
            control: true,
          ): _SelectSectionIntent(index),
          SingleActivator(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
              LogicalKeyboardKey.digit5,
              LogicalKeyboardKey.digit6,
              LogicalKeyboardKey.digit7,
            ][index],
            meta: true,
          ): _SelectSectionIntent(index),
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const _QuickMenuIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const _QuickMenuIntent(),
      };

  @override
  Widget build(BuildContext context) {
    final performanceMode = ref.watch(
      settingsProvider.select((settings) => settings.performanceMode),
    );
    final savings = performanceMode == PerformanceMode.savings;
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );
    final visiblePageIndices = <int>[
      0,
      1,
      2,
      3,
      if (faithEnabled) 4,
      5,
      6,
    ];
    final effectiveSelectedIndex =
        !faithEnabled && _selectedIndex == 4 ? 0 : _selectedIndex;
    final railSelectedIndex =
        visiblePageIndices.indexOf(effectiveSelectedIndex);

    if (effectiveSelectedIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedIndex != 4) return;
        setState(() {
          _selectedIndex = 0;
          _visited.add(0);
        });
      });
    }

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SelectSectionIntent: CallbackAction<_SelectSectionIntent>(
            onInvoke: (intent) {
              if (intent.index == 4 && !faithEnabled) return null;
              _select(intent.index);
              return null;
            },
          ),
          _QuickMenuIntent: CallbackAction<_QuickMenuIntent>(
            onInvoke: (_) {
              _openQuickMenu(faithEnabled: faithEnabled);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final content = _content(effectiveSelectedIndex);
              if (compact) {
                return Scaffold(
                  body: SafeArea(bottom: false, child: content),
                  bottomNavigationBar: _CompactNavigationBar(
                    selectedPageIndex: effectiveSelectedIndex,
                    onSelectPage: _select,
                    onOpenQuickMenu: () =>
                        _openQuickMenu(faithEnabled: faithEnabled),
                  ),
                );
              }

              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: railSelectedIndex < 0 ? 0 : railSelectedIndex,
                        onDestinationSelected: (railIndex) =>
                            _select(visiblePageIndices[railIndex]),
                        labelType: constraints.maxWidth >= 1180
                            ? NavigationRailLabelType.all
                            : NavigationRailLabelType.selected,
                        leading: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IconButton(
                            tooltip: 'Atajos de teclado',
                            onPressed: () =>
                                _showShortcutHelp(faithEnabled: faithEnabled),
                            icon: const Icon(Icons.keyboard_outlined),
                          ),
                        ),
                        destinations: [
                          for (final index in visiblePageIndices)
                            _desktopDestinations[index],
                        ],
                      ),
                      const VerticalDivider(thickness: 1, width: 1),
                      Expanded(
                        child: RepaintBoundary(
                          child: savings
                              ? content
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: KeyedSubtree(
                                    key: ValueKey(effectiveSelectedIndex),
                                    child: content,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SelectSectionIntent extends Intent {
  const _SelectSectionIntent(this.index);
  final int index;
}

class _QuickMenuIntent extends Intent {
  const _QuickMenuIntent();
}

class _CompactNavigationBar extends StatelessWidget {
  const _CompactNavigationBar({
    required this.selectedPageIndex,
    required this.onSelectPage,
    required this.onOpenQuickMenu,
  });

  final int selectedPageIndex;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onOpenQuickMenu;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 10,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 6),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 7, 4, 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _CompactNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Inicio',
                  selected: selectedPageIndex == 0,
                  onTap: () => onSelectPage(0),
                ),
              ),
              Expanded(
                child: _CompactNavItem(
                  icon: Icons.fitness_center_outlined,
                  selectedIcon: Icons.fitness_center,
                  label: 'Rutinas',
                  selected: selectedPageIndex == 1,
                  onTap: () => onSelectPage(1),
                ),
              ),
              Expanded(child: _QuickActionButton(onTap: onOpenQuickMenu)),
              Expanded(
                child: _CompactNavItem(
                  icon: Icons.show_chart_outlined,
                  selectedIcon: Icons.show_chart,
                  label: 'Progreso',
                  selected: selectedPageIndex == 3,
                  onTap: () => onSelectPage(3),
                ),
              ),
              Expanded(
                child: _CompactNavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Perfil',
                  selected: selectedPageIndex == 5,
                  onTap: () => onSelectPage(5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactNavItem extends StatelessWidget {
  const _CompactNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: foreground, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: colors.onPrimary, size: 30),
            ),
            const SizedBox(height: 2),
            Text(
              'Más',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMenuTile extends StatelessWidget {
  const _QuickMenuTile({
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
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
