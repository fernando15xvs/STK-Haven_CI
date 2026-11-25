import 'package:flutter/material.dart';
import 'package:gym_tracker/features/profile/presentation/pages/personal_profile_page.dart';

/// Compatibility entry point only. There is no second editor or draft.
class ExperiencePreferencesPage extends StatelessWidget {
  const ExperiencePreferencesPage({super.key});
  @override
  Widget build(BuildContext context) => const PersonalProfilePage(openTraining: true);
}
