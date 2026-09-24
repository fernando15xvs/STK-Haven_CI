import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/habits/presentation/pages/study_habits_page.dart';
import 'package:core/features/profile/presentation/pages/training_preferences_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/profile/presentation/widgets/platform_settings_page.dart';
import 'package:core/features/programs/presentation/pages/training_programs_page.dart';
import 'package:core/features/progress/presentation/pages/progress_intelligence_page.dart';
import 'package:core/features/sync/presentation/backup_status_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../ai/presentation/pages/ai_chat_page.dart';
import '../../../faith/presentation/pages/bible_reader_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../progress/presentation/pages/progress_page.dart';
import '../../../routines/presentation/pages/routines_page.dart';
import '../../../tools/presentation/training_tools_page.dart';
import 'program_dashboard_page.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  // Only Home is constructed on first paint. Tabs are created on first visit
  // and then retained in IndexedStack so navigation preserves their state
  // without paying the cost of building Progress/Profile/Routines up front.
  final List<Widget?> _pages = <Widget?>[
    const ProgramDashboardPage(),
    null,
    null,
    null,
  ];

  Widget _createPage(int index) {
    return switch (index) {
      0 => const ProgramDashboardPage(),
      1 => const RoutinesPage(),
      2 => const ProgressPage(),
      3 => const ProfilePage(),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _pages[index] ??= _createPage(index);
      _currentIndex = index;
    });
  }

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

    return Scaffold(
      // Keeping the body out from underneath the navigation surface avoids an
      // extra translucent compositing layer while scrolling on Android.
      extendBody: false,
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          _pages.length,
          (index) => _pages[index] ?? const SizedBox.shrink(),
          growable: false,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
          child: _BottomBarSurface(
            savings: savings,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Inicio',
                  isSelected: _currentIndex == 0,
                  onTap: () => _selectTab(0),
                ),
                _BottomNavItem(
                  icon: Icons.fitness_center_outlined,
                  activeIcon: Icons.fitness_center,
                  label: 'Entrenar',
                  isSelected: _currentIndex == 1,
                  onTap: () => _selectTab(1),
                ),
                _FloatingMenuButton(faithEnabled: faithEnabled),
                _BottomNavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Progreso',
                  isSelected: _currentIndex == 2,
                  onTap: () => _selectTab(2),
                ),
                _BottomNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Perfil',
                  isSelected: _currentIndex == 3,
                  onTap: () => _selectTab(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarSurface extends StatelessWidget {
  const _BottomBarSurface({required this.savings, required this.child});

  final bool savings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: savings
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingMenuButton extends StatefulWidget {
  const _FloatingMenuButton({required this.faithEnabled});

  final bool faithEnabled;

  @override
  State<_FloatingMenuButton> createState() => _FloatingMenuButtonState();
}

class _FloatingMenuButtonState extends State<_FloatingMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isOpen = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _controller.dispose();
    super.dispose();
  }

  void _closeImmediately() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.value = 0;
    if (mounted) setState(() => _isOpen = false);
  }

  void _toggleMenu() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_isOpen) {
      if (reduceMotion) {
        _closeImmediately();
      } else {
        _controller.reverse().then((_) => _closeImmediately());
      }
      return;
    }

    setState(() => _isOpen = true);
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _openPage(Widget page) {
    _closeImmediately();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    return OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Cerrar accesos rápidos',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleMenu,
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.sizeOf(overlayContext).height - offset.dy + 20,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Material(
                  color: Colors.transparent,
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeOutCubic,
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      runAlignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MenuOption(
                          icon: Icons.layers_outlined,
                          label: 'Programas',
                          onTap: () =>
                              _openPage(const TrainingProgramsPage()),
                        ),
                        _MenuOption(
                          icon: Icons.insights_rounded,
                          label: 'Inteligencia',
                          onTap: () =>
                              _openPage(const ProgressIntelligencePage()),
                        ),
                        _MenuOption(
                          icon: Icons.tune_rounded,
                          label: 'Preferencias',
                          onTap: () =>
                              _openPage(const TrainingPreferencesPage()),
                        ),
                        _MenuOption(
                          icon: Icons.settings_backup_restore_rounded,
                          label: 'Copias',
                          onTap: () => _openPage(const BackupStatusPage()),
                        ),
                        _MenuOption(
                          icon: Icons.task_alt_outlined,
                          label: 'Hábitos',
                          onTap: () => _openPage(const StudyHabitsPage()),
                        ),
                        if (widget.faithEnabled) ...[
                          _MenuOption(
                            icon: Icons.menu_book,
                            label: 'La Biblia',
                            onTap: () => _openPage(const BibleReaderPage()),
                          ),
                          _MenuOption(
                            icon: Icons.auto_awesome,
                            label: 'Haven Faith',
                            onTap: () => _openPage(const AiChatPage()),
                          ),
                        ],
                        _MenuOption(
                          icon: Icons.build_circle_outlined,
                          label: 'Herramientas',
                          onTap: () => _openPage(const TrainingToolsPage()),
                        ),
                        _MenuOption(
                          icon: Icons.devices_outlined,
                          label: 'Plataforma',
                          onTap: () =>
                              _openPage(const PlatformSettingsPage()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _isOpen ? 'Cerrar accesos rápidos' : 'Abrir accesos rápidos',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: _toggleMenu,
          customBorder: const CircleBorder(),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF00B4D8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.30),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 0.125).animate(_controller),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 86,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surfaceBorder,
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 25),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
