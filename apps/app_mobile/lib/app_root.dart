import 'dart:async';

import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/features/home/presentation/pages/home_screen.dart';
import 'package:gym_tracker/features/onboarding/presentation/pages/onboarding_page.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  Timer? _bibleInitTimer;
  bool _bibleInitSchedulePending = false;
  bool _bibleInitStarted = false;

  void _syncBibleInitialization(bool faithEnabled) {
    if (!faithEnabled) {
      _bibleInitTimer?.cancel();
      _bibleInitTimer = null;
      return;
    }

    if (_bibleInitStarted ||
        _bibleInitTimer != null ||
        _bibleInitSchedulePending) {
      return;
    }

    _bibleInitSchedulePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bibleInitSchedulePending = false;
      if (!mounted || _bibleInitStarted || _bibleInitTimer != null) return;

      final stillEnabled =
          ref.read(userExperienceProfileProvider).value?.faithEnabled == true;
      if (!stillEnabled) return;

      // The Bible database can require network + SQLite work on a fresh install.
      // Keep it away from the first-interaction window and never start it when
      // the user has not opted into Faith.
      _bibleInitTimer = Timer(const Duration(seconds: 6), () {
        _bibleInitTimer = null;
        if (!mounted) return;

        final enabled =
            ref.read(userExperienceProfileProvider).value?.faithEnabled == true;
        if (!enabled) return;

        _bibleInitStarted = true;
        unawaited(ref.read(bibleInitProvider.notifier).initialize());
      });
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
    final experienceProfile = ref.watch(userExperienceProfileProvider);
    _syncBibleInitialization(
      experienceProfile.value?.faithEnabled == true,
    );

    return hasCompletedOnboarding
        ? const HomeScreen()
        : const OnboardingPage();
  }
}
