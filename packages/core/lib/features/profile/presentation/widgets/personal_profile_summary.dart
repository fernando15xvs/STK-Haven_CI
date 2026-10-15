import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared identity/achievements surface for mobile and web.
class PersonalProfileSummary extends ConsumerWidget {
  final VoidCallback onEdit;
  const PersonalProfileSummary({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userExperienceProfileProvider).value;
    final sessions = ref.watch(workoutHistoryProvider);
    final prs = ref.watch(personalRecordRepositoryProvider).getAllPRs().length;
    final totalSeconds = sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final duration = hours > 0 ? '${hours} h ${minutes} min' : '${minutes} min';
    final name = profile?.preferredName ?? 'Tu perfil';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 36,
                child: profile?.avatarEmoji == null
                    ? const Icon(Icons.person_outline, size: 36)
                    : Text(profile!.avatarEmoji!, style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(_trainingLabel(profile), style: Theme.of(context).textTheme.bodyMedium),
                ],
              )),
            ]),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar perfil'),
            ),
            const Divider(height: 28),
            Text('Mi recorrido', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(spacing: 18, runSpacing: 8, children: [
              _Stat(label: 'Sesiones realizadas', value: '${sessions.length}'),
              _Stat(label: 'Tiempo entrenando', value: duration),
              _Stat(label: 'Récords personales', value: '$prs'),
            ]),
            const SizedBox(height: 10),
            Text(
              'Este resumen es privado. Solo se comparte información de entrenamiento con un entrenador al conceder permisos explícitos en Mis entrenadores.',
              style: Theme.of(context).textTheme.bodySmall,
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
