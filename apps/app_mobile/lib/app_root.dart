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
  bool _bibleInitScheduled = false;

  void _syncBibleInitialization(bool faithEnabled) {
    if (!faithEnabled || _bibleInitScheduled) return;
    _bibleInitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bibleInitScheduled = false;
      if (!mounted ||
          ref.read(userExperienceProfileProvider).value?.faithEnabled != true) {
        return;
      }
      // Start without an artificial 6-second delay. The cached verse remains
      // visible even if loading the full Bible SQLite database takes longer.
      ref.read(bibleInitProvider.notifier).initialize();
    });
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
