import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Identity stays centered at every width and text scale.
class PersonalProfileSummary extends ConsumerWidget {
  final VoidCallback onEdit;
  const PersonalProfileSummary({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userExperienceProfileProvider).value;
    return Center(
      child: Column(
        key: const ValueKey('profile_centered_identity'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileAvatar(profile: profile, radius: 54, previewEnabled: true),
          const SizedBox(height: AppSpacing.sm),
          Text(profile?.preferredName ?? 'Tu perfil', textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(onPressed: onEdit, child: const Text('Editar perfil')),
        ],
      ),
    );
  }
}
