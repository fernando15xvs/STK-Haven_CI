import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Immediate identity view: large local photo, name and secondary edit action.
/// No duplicate metrics, workout history, goal or XP.
class PersonalProfileSummary extends ConsumerWidget {
  final VoidCallback onEdit;
  const PersonalProfileSummary({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userExperienceProfileProvider).value;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile?.preferredName ?? 'Tu perfil',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: onEdit,
          child: const Text('Editar perfil'),
        ),
      ],
    );
    final avatar = ProfileAvatar(profile: profile, radius: 54);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
          if (constraints.maxWidth < 340 || largeText) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(height: AppSpacing.md),
                identity,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(width: AppSpacing.md),
              Expanded(child: identity),
            ],
          );
        },
      ),
    );
  }
}
