import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/onboarding/application/onboarding_recommendation_service.dart';
import 'package:core/features/onboarding/application/program_service.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WebOnboardingPage extends ConsumerStatefulWidget {
  const WebOnboardingPage({super.key});

  @override
  ConsumerState<WebOnboardingPage> createState() => _WebOnboardingPageState();
}

class _WebOnboardingPageState extends ConsumerState<WebOnboardingPage> {
  static const int _pageCount = 6;

  final PageController _controller = PageController();
  int _index = 0;

  TrainingGoal? _goal;
  TrainingExperience? _experience;
  int? _days;
  SessionDurationPreference _duration = SessionDurationPreference.variable;
  TrainingEnvironment? _environment;
  PlanningPreference _planning = PlanningPreference.recommendation;
  WeightUnit _weightUnit = WeightUnit.kg;
  bool _reminders = false;
  FaithContentPreference _faith = FaithContentPreference.undecided;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= _pageCount) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  UserExperienceProfile _profile() {
    return UserExperienceProfile(
      trainingGoal: _goal,
      trainingExperience: _experience,
      trainingDaysPerWeek: _days,
      sessionDuration: _duration,
      trainingEnvironment: _environment,
      planningPreference: _planning,
      weightUnit: _weightUnit,
      workoutRemindersWanted: _reminders,
      faithPreference: _faith,
      habitsEnabled: false,
      onboardingVersion: UserExperienceProfile.currentOnboardingVersion,
    );
  }

  Future<void> _finish({required bool installRecommended}) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final profile = _profile();
      await ref
          .read(userExperienceProfileProvider.notifier)
          .updateProfile(profile);

      final settings = ref.read(settingsProvider);
      ref.read(settingsProvider.notifier).updateSettings(
            settings.copyWith(
              weightUnit: profile.weightUnit,
              showDailyVerse: profile.faithEnabled,
              dailyVerseNotifications: false,
            ),
          );

      final recommended =
          OnboardingRecommendationService.recommend(profile);
      if (installRecommended && recommended != null) {
        await ref.read(programServiceProvider).installProgram(recommended);
      } else {
        await ref.read(programServiceProvider).completeOnboardingFromScratch();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_index > 0)
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Atrás',
                          onPressed: _saving ? null : () => _go(_index - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: _index / (_pageCount - 1),
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${_index + 1}/$_pageCount'),
                      ],
                    ),
                  if (_index > 0) const SizedBox(height: 18),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      color: colors.surfaceContainerLow,
                      child: PageView(
                        controller: _controller,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (value) =>
                            setState(() => _index = value),
                        children: [
                          _welcome(),
                          _goalAndExperience(),
                          _schedule(),
                          _preferences(),
                          _faithStep(),
                          _summary(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _page({
    required String title,
    required String subtitle,
    required List<Widget> children,
    required String actionLabel,
    required VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                runSpacing: 10,
                children: children,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : onAction,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcome() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tune_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Haz que STK Haven se adapte a ti',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Configura entrenamiento, preferencias y contenido opcional. Todo puede editarse después.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 34),
          FilledButton.icon(
            onPressed: () => _go(1),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Comenzar'),
          ),
        ],
      ),
    );
  }

  Widget _goalAndExperience() {
    return _page(
      title: 'Tu entrenamiento',
      subtitle: 'Objetivo principal y experiencia actual.',
      actionLabel: 'Siguiente',
      onAction: _goal != null && _experience != null ? () => _go(2) : null,
      children: [
        _sectionTitle('Objetivo'),
        _choice(
          value: TrainingGoal.hypertrophy,
          selected: _goal,
          title: 'Ganar masa muscular',
          onTap: (value) => setState(() => _goal = value),
        ),
        _choice(
          value: TrainingGoal.strength,
          selected: _goal,
          title: 'Ganar fuerza',
          onTap: (value) => setState(() => _goal = value),
        ),
        _choice(
          value: TrainingGoal.activeLifestyle,
          selected: _goal,
          title: 'Mantenerme activo',
          onTap: (value) => setState(() => _goal = value),
        ),
        _choice(
          value: TrainingGoal.conditioning,
          selected: _goal,
          title: 'Mejorar condición física',
          onTap: (value) => setState(() => _goal = value),
        ),
        _choice(
          value: TrainingGoal.selfDirected,
          selected: _goal,
          title: 'Crear mis propias rutinas',
          onTap: (value) => setState(() {
            _goal = value;
            _planning = PlanningPreference.selfDirected;
          }),
        ),
        const SizedBox(height: 14),
        _sectionTitle('Experiencia'),
        _choice(
          value: TrainingExperience.beginner,
          selected: _experience,
          title: 'Principiante',
          onTap: (value) => setState(() => _experience = value),
        ),
        _choice(
          value: TrainingExperience.intermediate,
          selected: _experience,
          title: 'Intermedio',
          onTap: (value) => setState(() => _experience = value),
        ),
        _choice(
          value: TrainingExperience.advanced,
          selected: _experience,
          title: 'Avanzado',
          onTap: (value) => setState(() => _experience = value),
        ),
      ],
    );
  }

  Widget _schedule() {
    return _page(
      title: 'Tiempo y entorno',
      subtitle: 'Ajustamos la experiencia a tu disponibilidad.',
      actionLabel: 'Siguiente',
      onAction: _environment != null ? () => _go(3) : null,
      children: [
        _sectionTitle('Días por semana'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final day in [2, 3, 4, 5, 6])
              ChoiceChip(
                label: Text('$day'),
                selected: _days == day,
                onSelected: (_) => setState(() => _days = day),
              ),
            ChoiceChip(
              label: const Text('Aún no lo sé'),
              selected: _days == null,
              onSelected: (_) => setState(() => _days = null),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Duración habitual'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _durationChip(SessionDurationPreference.minutes30, '30 min'),
            _durationChip(SessionDurationPreference.minutes45, '45 min'),
            _durationChip(SessionDurationPreference.minutes60, '60 min'),
            _durationChip(SessionDurationPreference.minutes75Plus, '75+ min'),
            _durationChip(SessionDurationPreference.variable, 'Variable'),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Lugar / equipamiento'),
        _choice(
          value: TrainingEnvironment.fullGym,
          selected: _environment,
          title: 'Gimnasio completo',
          onTap: (value) => setState(() => _environment = value),
        ),
        _choice(
          value: TrainingEnvironment.homeWeights,
          selected: _environment,
          title: 'Casa con pesas',
          onTap: (value) => setState(() => _environment = value),
        ),
        _choice(
          value: TrainingEnvironment.minimalEquipment,
          selected: _environment,
          title: 'Equipamiento mínimo',
          onTap: (value) => setState(() => _environment = value),
        ),
        _choice(
          value: TrainingEnvironment.mixed,
          selected: _environment,
          title: 'Mixto',
          onTap: (value) => setState(() => _environment = value),
        ),
      ],
    );
  }

  Widget _preferences() {
    return _page(
      title: 'Preferencias',
      subtitle: 'Cómo quieres que se comporte STK Haven.',
      actionLabel: 'Siguiente',
      onAction: () => _go(4),
      children: [
        _sectionTitle('Planificación'),
        _choice(
          value: PlanningPreference.recommendation,
          selected: _planning,
          title: 'Quiero una recomendación',
          onTap: (value) => setState(() => _planning = value),
        ),
        _choice(
          value: PlanningPreference.selfDirected,
          selected: _planning,
          title: 'Crearé mis propias rutinas',
          onTap: (value) => setState(() => _planning = value),
        ),
        _choice(
          value: PlanningPreference.decideLater,
          selected: _planning,
          title: 'Decidir después',
          onTap: (value) => setState(() => _planning = value),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Unidad de peso'),
        SegmentedButton<WeightUnit>(
          segments: const [
            ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
            ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
          ],
          selected: {_weightUnit},
          onSelectionChanged: (value) =>
              setState(() => _weightUnit = value.first),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _reminders,
          onChanged: (value) => setState(() => _reminders = value),
          title: const Text('Quiero recordatorios de entrenamiento'),
          subtitle: const Text(
            'La hora y permisos se configuran después del onboarding.',
          ),
        ),
      ],
    );
  }

  Widget _faithStep() {
    return _page(
      title: 'Fe, solo si tú quieres',
      subtitle: '¿Quieres incluir contenido de fe cristiana?',
      actionLabel: 'Ver resumen',
      onAction: () => _go(5),
      children: [
        _choice(
          value: FaithContentPreference.enabled,
          selected: _faith,
          title: 'Sí, quiero incluirlo',
          subtitle: 'Biblia, versículo diario, Haven Faith y estudio.',
          onTap: (value) => setState(() => _faith = value),
        ),
        _choice(
          value: FaithContentPreference.disabled,
          selected: _faith,
          title: 'No, prefiero mantenerlo oculto',
          subtitle: 'No se cargarán módulos ni recursos de Fe.',
          onTap: (value) => setState(() => _faith = value),
        ),
        _choice(
          value: FaithContentPreference.undecided,
          selected: _faith,
          title: 'Decidir después',
          subtitle: 'Podrás activarlo más adelante desde Perfil.',
          onTap: (value) => setState(() => _faith = value),
        ),
      ],
    );
  }

  Widget _summary() {
    final profile = _profile();
    final recommended =
        OnboardingRecommendationService.recommend(profile);
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _summaryRow('Objetivo', _goalLabel(_goal)),
                  _summaryRow('Experiencia', _experienceLabel(_experience)),
                  _summaryRow(
                    'Frecuencia',
                    _days == null ? 'Por decidir' : '$_days días/semana',
                  ),
                  _summaryRow('Duración', _durationLabel(_duration)),
                  _summaryRow('Entorno', _environmentLabel(_environment)),
                  _summaryRow('Peso', _weightUnit.label),
                  _summaryRow('Fe', _faithLabel(_faith)),
                  if (recommended != null) ...[
                    const SizedBox(height: 18),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.stars_rounded),
                        title: Text(recommended.name),
                        subtitle: Text(recommended.description),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              if (recommended != null)
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _finish(installRecommended: true),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Usar programa recomendado'),
                ),
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => _finish(installRecommended: false),
                child: Text(
                  recommended == null
                      ? 'Entrar a STK Haven'
                      : 'Continuar sin instalar programa',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice<T>({
    required T value,
    required T? selected,
    required String title,
    String? subtitle,
    required ValueChanged<T> onTap,
  }) {
    final active = value == selected;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: active
            ? colors.primaryContainer.withValues(alpha: 0.45)
            : colors.surfaceContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(value),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  active
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: active ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _durationChip(
    SessionDurationPreference value,
    String label,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: _duration == value,
      onSelected: (_) => setState(() => _duration = value),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      );

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  String _goalLabel(TrainingGoal? value) => switch (value) {
        TrainingGoal.hypertrophy => 'Masa muscular',
        TrainingGoal.strength => 'Fuerza',
        TrainingGoal.activeLifestyle => 'Mantenerme activo',
        TrainingGoal.conditioning => 'Condición física',
        TrainingGoal.selfDirected => 'Rutinas propias',
        null => 'Por decidir',
      };

  String _experienceLabel(TrainingExperience? value) => switch (value) {
        TrainingExperience.beginner => 'Principiante',
        TrainingExperience.intermediate => 'Intermedio',
        TrainingExperience.advanced => 'Avanzado',
        null => 'Por decidir',
      };

  String _durationLabel(SessionDurationPreference value) => switch (value) {
        SessionDurationPreference.minutes30 => '30 min',
        SessionDurationPreference.minutes45 => '45 min',
        SessionDurationPreference.minutes60 => '60 min',
        SessionDurationPreference.minutes75Plus => '75+ min',
        SessionDurationPreference.variable => 'Variable',
      };

  String _environmentLabel(TrainingEnvironment? value) => switch (value) {
        TrainingEnvironment.fullGym => 'Gimnasio',
        TrainingEnvironment.homeWeights => 'Casa con pesas',
        TrainingEnvironment.minimalEquipment => 'Equipamiento mínimo',
        TrainingEnvironment.mixed => 'Mixto',
        null => 'Por decidir',
      };

  String _faithLabel(FaithContentPreference value) => switch (value) {
        FaithContentPreference.enabled => 'Incluida',
        FaithContentPreference.disabled => 'Oculta',
        FaithContentPreference.undecided => 'Decidir después',
      };
}
