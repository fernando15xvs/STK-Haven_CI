import 'package:gym_tracker/features/coach/presentation/pages/coach_hub_page.dart';
import 'package:core/features/coach_pro/application/coach_pro_entitlement_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:gym_tracker/features/habits/presentation/study_habits_mobile_page.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../ai/presentation/pages/ai_chat_page.dart';
import '../../../faith/presentation/pages/bible_reader_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart';
import '../../../progress/presentation/pages/progress_page.dart';
import '../../../motivation/presentation/motivation_page.dart';
import '../../../motivation/presentation/widgets/motivation_home_mini_player.dart';
import '../../../routines/presentation/pages/routines_page.dart';
import '../../../tools/presentation/training_tools_page.dart';
import 'program_dashboard_page.dart';
import '../widgets/quick_access_menu.dart';
import '../../application/home_tab_return_request.dart';

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
  late final List<Widget?> _pages;
  final GlobalKey _progressSummaryAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pages = <Widget?>[
      ProgramDashboardPage(
        onOpenProgress: _openProgress,
        isVisible: true,
      ),
      null,
      null,
      null,
    ];
  }

  void _openProgress() {
    _selectTab(2);
    // A link from the weekly summary must open Resumen, not whichever
    // analytical subtab (possibly Medidas) was last visited.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchor = _progressSummaryAnchorKey.currentContext;
      if (anchor != null) {
        DefaultTabController.of(anchor).animateTo(0);
      }
    });
  }

  Widget _createPage(int index) {
    return switch (index) {
      0 => ProgramDashboardPage(
        onOpenProgress: _openProgress,
        isVisible: true,
      ),
      1 => const RoutinesPage(),
      2 => ProgressPage(summaryAnchorKey: _progressSummaryAnchorKey),
      3 => const ProfilePage(),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _pages[index] ??= _createPage(index);
      _currentIndex = index;
      // IndexedStack retains the Home widget state. Explicit visibility
      // allows sensor/clock polling to stop on the other tabs.
      _pages[0] = ProgramDashboardPage(
        onOpenProgress: _openProgress,
        isVisible: index == 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeTabReturnRequestProvider, (previous, next) {
      if (previous != next) _selectTab(0);
    });
    final experienceProfile = ref.watch(userExperienceProfileProvider).value;
    final faithEnabled = experienceProfile?.faithEnabled ?? false;
    final coachCapability = experienceProfile?.isCoach ?? false;
    final signedIn = ref.watch(
      appIdentityProvider.select((identity) => identity.signedIn),
    );
    final coachProAccess = signedIn
        ? ref.watch(coachProEntitlementProvider).value?.accessActive ?? false
        : false;
    final coachEnabled = coachCapability || coachProAccess;

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
      // No card, border, background panel or shadow: the tabs float on the
      // same Scaffold background as the page, while honoring iOS safe areas.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Remains in the layout and above the tab row when playing.
            const MotivationHomeMiniPlayer(),
            Padding(
              key: const ValueKey('flat_bottom_navigation'),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _BottomNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Inicio',
                    isSelected: _currentIndex == 0,
                    onTap: () => _selectTab(0),
                  )),
                  Expanded(child: _BottomNavItem(
                    icon: Icons.fitness_center_outlined,
                    activeIcon: Icons.fitness_center,
                    label: 'Entrenar',
                    isSelected: _currentIndex == 1,
                    onTap: () => _selectTab(1),
                  )),
                  _FloatingMenuButton(
                    faithEnabled: faithEnabled,
                    coachEnabled: coachEnabled,
                  ),
                  Expanded(child: _BottomNavItem(
                    icon: Icons.bar_chart_outlined,
                    activeIcon: Icons.bar_chart,
                    label: 'Progreso',
                    isSelected: _currentIndex == 2,
                    onTap: () => _selectTab(2),
                  )),
                  Expanded(child: _BottomNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Perfil',
                    isSelected: _currentIndex == 3,
                    onTap: () => _selectTab(3),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
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
          child: Padding(
              // Reduce the space *below* the labels: icons settle 8 dp lower
              // without approaching the iPhone home indicator.
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? AppColors.of(context).primary
                        : AppColors.of(context).textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: AppTypography.labelSmall.copyWith(
                    color: isSelected
                        ? AppColors.of(context).primary
                        : AppColors.of(context).textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontVariations: [
                      FontVariation('wght', isSelected ? 700 : 600),
                    ],
                    letterSpacing: 0,
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

class _FloatingMenuButton extends StatefulWidget {
  const _FloatingMenuButton({
    required this.faithEnabled,
    required this.coachEnabled,
  });

  final bool faithEnabled;
  final bool coachEnabled;

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
                  child: ColoredBox(
                    key: const ValueKey('quick_access_scrim'),
                    color: QuickAccessMenu.scrimFor(Theme.of(overlayContext).brightness),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.paddingOf(overlayContext).top + 12,
            bottom: MediaQuery.sizeOf(overlayContext).height - offset.dy + 20,
            child: Align(
              alignment: Alignment.bottomCenter,
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
                    child: QuickAccessMenu(
                      children: [
                        if (widget.coachEnabled)
                          QuickAccessOption(
                            icon: Icons.groups_2_outlined,
                            label: 'Coach',
                            onTap: () => _openPage(const CoachHubPage()),
                          ),
                        QuickAccessOption(
                          icon: Icons.task_alt_outlined,
                          label: 'Hábitos',
                          onTap: () => _openPage(const StudyHabitsMobilePage()),
                        ),
                        if (widget.faithEnabled) ...[
                          QuickAccessOption(
                            icon: Icons.menu_book,
                            label: 'La Biblia',
                            onTap: () => _openPage(const BibleReaderPage()),
                          ),
                          QuickAccessOption(
                            icon: Icons.auto_awesome,
                            label: 'Haven Faith',
                            onTap: () => _openPage(const AiChatPage()),
                          ),
                        ],
                        QuickAccessOption(
                          icon: Icons.restaurant_menu_outlined,
                          label: 'Nutrición',
                          onTap: () => _openPage(
                            const NutritionIntelligencePageMobile(),
                          ),
                        ),
                        QuickAccessOption(
                          icon: Icons.headphones_outlined,
                          label: 'Motivation',
                          onTap: () => _openPage(const MotivationPage()),
                        ),
                        QuickAccessOption(
                          icon: Icons.build_circle_outlined,
                          label: 'Herramientas',
                          onTap: () => _openPage(const TrainingToolsPage()),
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
              gradient: LinearGradient(
                colors: [
                  AppColors.of(context).primary,
                  AppColors.of(context).primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.of(context).primary.withValues(alpha: 0.30),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 0.125).animate(_controller),
              child: Icon(
                Icons.add,
                color: AppColors.of(context).onPrimary,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

