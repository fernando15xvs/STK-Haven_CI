import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identity belongs to Perfil. Historic sessions, volume and PRs belong
/// to Progreso; do not repeat their calculations in this header.
class PersonalProfileSummary extends ConsumerWidget {
  final VoidCallback onEdit;
  const PersonalProfileSummary({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userExperienceProfileProvider).value;
    final colors = AppColors.of(context);
    final name = profile?.preferredName ?? 'Tu perfil';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(profile: profile),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _trainingLabel(profile),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar perfil'),
            ),
          ],
        ),
      ),
    );
  }

  String _trainingLabel(UserExperienceProfile? profile) {
    if (profile == null) return 'Tu espacio personal de entrenamiento';
    final goal = switch (profile.trainingGoal) {
      TrainingGoal.hypertrophy => 'Ganar músculo',
      TrainingGoal.strength => 'Ganar fuerza',
      TrainingGoal.activeLifestyle => 'Vida activa',
      TrainingGoal.conditioning => 'Acondicionamiento',
      TrainingGoal.selfDirected => 'Entrenamiento libre',
      null => 'Objetivo por definir',
    };
    final level = switch (profile.trainingExperience) {
      TrainingExperience.beginner => 'Principiante',
      TrainingExperience.intermediate => 'Intermedia',
      TrainingExperience.advanced => 'Avanzada',
      null => 'Experiencia por definir',
    };
    return '$goal · $level';
  }
}
