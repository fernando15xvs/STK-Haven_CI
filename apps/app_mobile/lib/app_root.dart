import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:gym_tracker/features/home/presentation/pages/home_screen.dart';
import 'package:gym_tracker/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:core/features/faith/application/bible_init_provider.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  Timer? _bibleInitTimer;

  @override
  void initState() {
    super.initState();

    // The Bible database can require network + SQLite work on a fresh install.
    // Keep that non-critical work away from the Home first-interaction window.
    _bibleInitTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      unawaited(ref.read(bibleInitProvider.notifier).initialize());
    });
  }

  @override
  void dispose() {
    _bibleInitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCompletedOnboarding = ref.watch(
      settingsProvider.select((settings) => settings.hasCompletedOnboarding),
    );

    return hasCompletedOnboarding
        ? const HomeScreen()
        : const OnboardingPage();
  }
}
