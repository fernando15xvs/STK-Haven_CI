import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immediate identity view: large local photo, name and secondary edit action.
/// No duplicate metrics, workout history, goal or XP.
class PersonalProfileSummary extends ConsumerWidget {
  final VoidCallback onEdit;
  const PersonalProfileSummary({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userExperienceProfileProvider).value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProfileAvatar(profile: profile, radius: 54),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.preferredName ?? 'Tu perfil',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar perfil'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
