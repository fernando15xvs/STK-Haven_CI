import 'dart:convert';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExperiencePreferencesPage extends ConsumerStatefulWidget {
  const ExperiencePreferencesPage({super.key});

  @override
  ConsumerState<ExperiencePreferencesPage> createState() =>
      _ExperiencePreferencesPageState();
}

class _ExperiencePreferencesPageState
    extends ConsumerState<ExperiencePreferencesPage> {
  UserExperienceProfile? _draft;
  UserExperienceProfile? _original;
  bool _saving = false;

  bool get _hasUnsavedChanges {
    final draft = _draft, original = _original;
    if (draft == null || original == null) return false;
    return jsonEncode(draft.toJson()) != jsonEncode(original.toJson());
  }

  Future<void> _requestDiscard(bool didPop) async {
    if (didPop || !_hasUnsavedChanges || _saving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text('Hay cambios en tus preferencias sin guardar. ¿Quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _draft = _original);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncProfile = ref.watch(userExperienceProfileProvider);
    final identity = ref.watch(appIdentityProvider);

    return PopScope(
      canPop: !_hasUnsavedChanges && !_saving,
      onPopInvokedWithResult: (didPop, _) => _requestDiscard(didPop),
      child: Scaffold(
      appBar: AppBar(title: const Text('Personalización')),
      body: asyncProfile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo cargar la personalización: $error'),
          ),
        ),
        data: (profile) {
          _original ??= profile;
          _draft ??= profile;
          final draft = _draft!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [
              Text(
                'Entrenamiento',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              _dropdown<TrainingGoal>(
                label: 'Objetivo principal',
                value: draft.trainingGoal,
                values: TrainingGoal.values,
                labelFor: _goalLabel,
                onChanged: (value) =>
                    setState(() => _draft = draft.copyWith(
                          trainingGoal: value,
                          clearTrainingGoal: value == null,
                        )),
              ),
              const SizedBox(height: 12),
              _dropdown<TrainingExperience>(
                label: 'Experiencia',
                value: draft.trainingExperience,
                values: TrainingExperience.values,
                labelFor: _experienceLabel,
                onChanged: (value) =>
                    setState(() => _draft = draft.copyWith(
                          trainingExperience: value,
                          clearTrainingExperience: value == null,
                        )),
              ),
              const SizedBox(height: 12),
              _daysSelector(draft),
              const SizedBox(height: 12),
              _dropdown<SessionDurationPreference>(
                label: 'Duración habitual',
                value: draft.sessionDuration,
                values: SessionDurationPreference.values,
                labelFor: _durationLabel,
                allowNull: false,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _draft = draft.copyWith(
                        sessionDuration: value,
                      ));
                },
              ),
              const SizedBox(height: 12),
              _dropdown<TrainingEnvironment>(
                label: 'Lugar / equipamiento',
                value: draft.trainingEnvironment,
                values: TrainingEnvironment.values,
                labelFor: _environmentLabel,
                onChanged: (value) =>
                    setState(() => _draft = draft.copyWith(
                          trainingEnvironment: value,
                          clearTrainingEnvironment: value == null,
                        )),
              ),
              const SizedBox(height: 12),
              _dropdown<PlanningPreference>(
                label: 'Planificación',
                value: draft.planningPreference,
                values: PlanningPreference.values,
                labelFor: _planningLabel,
                allowNull: false,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _draft = draft.copyWith(
                        planningPreference: value,
                      ));
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Modo de uso',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes usar STK Haven para ti, como entrenador, o en ambos modos. '
                'El modo entrenador no da acceso a ningún cliente por sí solo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Atleta'),
                    selected:
                        draft.capabilities.contains(UserCapability.athlete),
                    onSelected: (selected) => _toggleCapability(
                      draft,
                      UserCapability.athlete,
                      selected,
                    ),
                  ),
                  FilterChip(
                    label: const Text('Entrenador'),
                    selected:
                        draft.capabilities.contains(UserCapability.coach),
                    onSelected: (selected) => _toggleCapability(
                      draft,
                      UserCapability.coach,
                      selected,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                identity.signedIn
                    ? 'Cuenta STK Haven: ${identity.email ?? 'sesión permanente'}'
                    : 'Sin cuenta permanente: esta preferencia se mantiene local.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Text(
                'Experiencia de la app',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Las unidades se configuran en Entrenamiento y unidades. '
                'Los recordatorios reales se activan desde Notificaciones.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              Text(
                'Contenido de Fe',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              _faithChoice(
                draft,
                FaithContentPreference.enabled,
                'Sí, incluirlo',
                'Biblia, versículo diario, Haven Faith y estudio.',
              ),
              _faithChoice(
                draft,
                FaithContentPreference.disabled,
                'No, mantenerlo oculto',
                'No se cargarán módulos de Fe.',
              ),
              _faithChoice(
                draft,
                FaithContentPreference.undecided,
                'Decidir después',
                'Se mantiene oculto hasta que elijas activarlo.',
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  void _toggleCapability(
    UserExperienceProfile draft,
    UserCapability capability,
    bool selected,
  ) {
    final next = Set<UserCapability>.from(draft.capabilities);
    if (selected) {
      next.add(capability);
    } else {
      next.remove(capability);
    }
    if (next.isEmpty) {
      next.add(UserCapability.athlete);
    }
    setState(() => _draft = draft.copyWith(capabilities: next));
  }

  Future<void> _save() async {
    final draft = _draft;
    final original = _original;
    if (draft == null || original == null || _saving) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(userExperienceProfileProvider.notifier)
          .updateProfile(draft);

      final settingsNotifier = ref.read(settingsProvider.notifier);

      if (!original.faithEnabled && draft.faithEnabled) {
        settingsNotifier.setShowDailyVerse(true);
      } else if (original.faithEnabled && !draft.faithEnabled) {
        settingsNotifier.setShowDailyVerse(false);
        await settingsNotifier.setDailyVerseNotifications(false);
      }

      _original = draft;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personalización actualizada.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'No se pudieron guardar las preferencias. Inténtalo de nuevo.',
          )),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _daysSelector(UserExperienceProfile draft) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Frecuencia preferida',
        helperText: 'Solo para recomendaciones. El plan activo se edita en Entrenar.',
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final day in [2, 3, 4, 5, 6])
            ChoiceChip(
              label: Text('$day'),
              selected: draft.trainingDaysPerWeek == day,
              onSelected: (_) => setState(
                () => _draft = draft.copyWith(trainingDaysPerWeek: day),
              ),
            ),
          ChoiceChip(
            label: const Text('No lo sé'),
            selected: draft.trainingDaysPerWeek == null,
            onSelected: (_) =>
                setState(() => _draft = draft.copyWith(clearTrainingDays: true)),
          ),
        ],
      ),
    );
  }

  Widget _faithChoice(
    UserExperienceProfile draft,
    FaithContentPreference value,
    String title,
    String subtitle,
  ) {
    return RadioListTile<FaithContentPreference>(
      contentPadding: EdgeInsets.zero,
      value: value,
      groupValue: draft.faithPreference,
      onChanged: (next) {
        if (next == null) return;
        setState(() => _draft = draft.copyWith(faithPreference: next));
      },
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T) labelFor,
    required ValueChanged<T?> onChanged,
    bool allowNull = true,
  }) {
    return DropdownButtonFormField<T?>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowNull)
          DropdownMenuItem<T?>(
            value: null,
            child: const Text('Por decidir'),
          ),
        ...values.map(
          (item) => DropdownMenuItem<T?>(
            value: item,
            child: Text(labelFor(item)),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  String _goalLabel(TrainingGoal value) => switch (value) {
        TrainingGoal.hypertrophy => 'Ganar masa muscular',
        TrainingGoal.strength => 'Ganar fuerza',
        TrainingGoal.activeLifestyle => 'Mantenerme activo',
        TrainingGoal.conditioning => 'Mejorar condición física',
        TrainingGoal.selfDirected => 'Crear mis propias rutinas',
      };

  String _experienceLabel(TrainingExperience value) => switch (value) {
        TrainingExperience.beginner => 'Principiante',
        TrainingExperience.intermediate => 'Intermedio',
        TrainingExperience.advanced => 'Avanzado',
      };

  String _durationLabel(SessionDurationPreference value) => switch (value) {
        SessionDurationPreference.minutes30 => '30 min',
        SessionDurationPreference.minutes45 => '45 min',
        SessionDurationPreference.minutes60 => '60 min',
        SessionDurationPreference.minutes75Plus => '75+ min',
        SessionDurationPreference.variable => 'Variable',
      };

  String _environmentLabel(TrainingEnvironment value) => switch (value) {
        TrainingEnvironment.fullGym => 'Gimnasio completo',
        TrainingEnvironment.homeWeights => 'Casa con pesas',
        TrainingEnvironment.minimalEquipment => 'Equipamiento mínimo',
        TrainingEnvironment.mixed => 'Mixto',
      };

  String _planningLabel(PlanningPreference value) => switch (value) {
        PlanningPreference.recommendation => 'Quiero una recomendación',
        PlanningPreference.selfDirected => 'Crear mis propias rutinas',
        PlanningPreference.decideLater => 'Decidir después',
      };
}
