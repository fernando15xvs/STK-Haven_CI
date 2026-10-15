import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Personal identity stays local. Coach access is managed separately through
/// explicit relationship permissions; editing this page does not share data.
class PersonalProfilePage extends ConsumerStatefulWidget {
  const PersonalProfilePage({super.key});

  @override
  ConsumerState<PersonalProfilePage> createState() => _PersonalProfilePageState();
}

class _PersonalProfilePageState extends ConsumerState<PersonalProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  UserExperienceProfile? _draft;
  bool _saving = false;

  static const _avatars = <String>['💪', '🌱', '🏋️', '🏃', '⭐', '🧘', '🔥', '🦁'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userExperienceProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('No se pudo cargar el perfil: $error')),
        data: (saved) {
          if (_draft == null) {
            _draft = saved;
            _name.text = saved.displayName;
          }
          final draft = _draft!;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Cómo quieres aparecer', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o apodo',
                    hintText: '¿Cómo quieres que te llamemos?',
                    border: OutlineInputBorder(),
                  ),
                  validator: (text) {
                    if ((text ?? '').trim().length > 40) return 'Máximo 40 caracteres.';
                    if ((text ?? '').contains(RegExp(r'[\x00-\x1F]'))) {
                      return 'El nombre contiene caracteres no permitidos.';
                    }
                    return null; // El nombre es opcional.
                  },
                ),
                const SizedBox(height: 14),
                Text('Avatar (opcional)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Sin avatar'),
                      selected: draft.avatarEmoji == null,
                      onSelected: (_) => setState(() => _draft = draft.copyWith(clearAvatar: true)),
                    ),
                    for (final avatar in _avatars)
                      ChoiceChip(
                        label: Text(avatar, style: const TextStyle(fontSize: 24)),
                        selected: draft.avatarEmoji == avatar,
                        onSelected: (_) => setState(() => _draft = draft.copyWith(avatarEmoji: avatar)),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Mi entrenamiento', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<TrainingGoal>(
                  value: draft.trainingGoal,
                  decoration: const InputDecoration(labelText: 'Objetivo principal', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: TrainingGoal.hypertrophy, child: Text('Ganar músculo')),
                    DropdownMenuItem(value: TrainingGoal.strength, child: Text('Ganar fuerza')),
                    DropdownMenuItem(value: TrainingGoal.activeLifestyle, child: Text('Vida activa')),
                    DropdownMenuItem(value: TrainingGoal.conditioning, child: Text('Acondicionamiento')),
                    DropdownMenuItem(value: TrainingGoal.selfDirected, child: Text('Entrenamiento libre')),
                  ],
                  onChanged: (value) => setState(() => _draft = draft.copyWith(
                    trainingGoal: value, clearTrainingGoal: value == null,
                  )),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TrainingExperience>(
                  value: draft.trainingExperience,
                  decoration: const InputDecoration(labelText: 'Experiencia entrenando', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: TrainingExperience.beginner, child: Text('Principiante')),
                    DropdownMenuItem(value: TrainingExperience.intermediate, child: Text('Intermedia')),
                    DropdownMenuItem(value: TrainingExperience.advanced, child: Text('Avanzada')),
                  ],
                  onChanged: (value) => setState(() => _draft = draft.copyWith(
                    trainingExperience: value, clearTrainingExperience: value == null,
                  )),
                ),
                const SizedBox(height: 24),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reflexiones al terminar de entrenar'),
                  subtitle: const Text('Aparecen solo en el resumen final si activaste el contenido de Fe. Puedes desactivarlas aquí.'),
                  value: draft.showWorkoutReflections,
                  onChanged: (value) => setState(() => _draft = draft.copyWith(showWorkoutReflections: value)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Privacidad: el nombre y avatar son personales y no se comparten automáticamente con el entrenador. '
                  'Los permisos de entrenamientos, progreso y medidas se eligen en Mis entrenadores.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar perfil'),
                  onPressed: _saving ? null : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _saving = true);
                    try {
                      await ref.read(userExperienceProfileProvider.notifier).updateProfile(
                        _draft!.copyWith(displayName: _name.text.trim()),
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No se pudo guardar el perfil. Inténtalo de nuevo.')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
