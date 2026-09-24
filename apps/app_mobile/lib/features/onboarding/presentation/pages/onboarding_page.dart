import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/onboarding/application/onboarding_recommendation_service.dart';
import 'package:core/features/onboarding/application/program_service.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/program_preview_modal.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const int _pageCount = 6;

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  TrainingGoal? _goal;
  TrainingExperience? _experience;
  int? _daysPerWeek;
  SessionDurationPreference _duration = SessionDurationPreference.variable;
  TrainingEnvironment? _environment;
  PlanningPreference _planning = PlanningPreference.recommendation;
  WeightUnit _weightUnit = WeightUnit.kg;
  bool _remindersWanted = false;
  FaithContentPreference _faith = FaithContentPreference.undecided;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _pageCount) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() => _goTo(_currentIndex + 1);

  UserExperienceProfile _buildProfile() {
    return UserExperienceProfile(
      trainingGoal: _goal,
      trainingExperience: _experience,
      trainingDaysPerWeek: _daysPerWeek,
      sessionDuration: _duration,
      trainingEnvironment: _environment,
      planningPreference: _planning,
      weightUnit: _weightUnit,
      workoutRemindersWanted: _remindersWanted,
      faithPreference: _faith,
      habitsEnabled: false,
      onboardingVersion: UserExperienceProfile.currentOnboardingVersion,
    );
  }

  Future<void> _finish({required bool installRecommended}) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final profile = _buildProfile();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (_currentIndex > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Atrás',
                      onPressed: _saving ? null : () => _goTo(_currentIndex - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _currentIndex / (_pageCount - 1),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_currentIndex + 1}/$_pageCount',
                      style: AppTypography.labelSmall,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) =>
                    setState(() => _currentIndex = index),
                children: [
                  _welcomeStep(),
                  _goalStep(),
                  _scheduleStep(),
                  _preferencesStep(),
                  _faithStep(),
                  _summaryStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepShell({
    required String title,
    required String subtitle,
    required List<Widget> children,
    required String actionLabel,
    required VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.displaySmall),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: actionLabel,
              onPressed: _saving ? null : onAction,
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryFaded,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Haz que STK Haven\nse adapte a ti',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Son unas pocas preguntas. Podrás cambiar todo después desde tu perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(label: 'Comenzar', onPressed: _next),
          ),
        ],
      ),
    );
  }

  Widget _goalStep() {
    return _stepShell(
      title: 'Tu entrenamiento',
      subtitle: 'Primero, cuéntanos qué buscas y tu nivel actual.',
      actionLabel: 'Siguiente',
      onAction: _goal != null && _experience != null ? _next : null,
      children: [
        Text('Objetivo principal', style: AppTypography.headlineMedium),
        const SizedBox(height: 10),
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
          title: 'Mejorar mi condición física',
          onTap: (value) => setState(() => _goal = value),
        ),
        _choice(
          value: TrainingGoal.selfDirected,
          selected: _goal,
          title: 'Crear mis propias rutinas',
          onTap: (value) {
            setState(() {
              _goal = value;
              _planning = PlanningPreference.selfDirected;
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Experiencia', style: AppTypography.headlineMedium),
        const SizedBox(height: 10),
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

  Widget _scheduleStep() {
    return _stepShell(
      title: 'Tiempo y entorno',
      subtitle: 'Esto ayuda a que las recomendaciones sean realistas.',
      actionLabel: 'Siguiente',
      onAction: _environment != null ? _next : null,
      children: [
        Text('Días por semana', style: AppTypography.headlineMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final days in [2, 3, 4, 5, 6])
              ChoiceChip(
                label: Text('$days'),
                selected: _daysPerWeek == days,
                onSelected: (_) => setState(() => _daysPerWeek = days),
              ),
            ChoiceChip(
              label: const Text('Aún no lo sé'),
              selected: _daysPerWeek == null,
              onSelected: (_) => setState(() => _daysPerWeek = null),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Duración habitual', style: AppTypography.headlineMedium),
        const SizedBox(height: 10),
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
        const SizedBox(height: AppSpacing.lg),
        Text('¿Dónde entrenas?', style: AppTypography.headlineMedium),
        const SizedBox(height: 10),
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
          title: 'Casa / equipamiento mínimo',
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

  Widget _preferencesStep() {
    return _stepShell(
      title: 'Tus preferencias',
      subtitle: 'Puedes modificarlas cuando quieras.',
      actionLabel: 'Siguiente',
      onAction: _next,
      children: [
        Text('Planificación', style: AppTypography.headlineMedium),
        const SizedBox(height: 10),
        _choice(
          value: PlanningPreference.recommendation,
          selected: _planning,
          title: 'Quiero una recomendación',
          onTap: (value) => setState(() => _planning = value),
        ),
        _choice(
          value: PlanningPreference.selfDirected,
          selected: _planning,
          title: 'Quiero crear mis propias rutinas',
          onTap: (value) => setState(() => _planning = value),
        ),
        _choice(
          value: PlanningPreference.decideLater,
          selected: _planning,
          title: 'Decidir después',
          onTap: (value) => setState(() => _planning = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Unidad de peso', style: AppTypography.headlineMedium),
        const SizedBox(height: 10),
        SegmentedButton<WeightUnit>(
          segments: const [
            ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
            ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
          ],
          selected: {_weightUnit},
          onSelectionChanged: (value) =>
              setState(() => _weightUnit = value.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _remindersWanted,
          onChanged: (value) => setState(() => _remindersWanted = value),
          title: const Text('Quiero recordatorios de entrenamiento'),
          subtitle: const Text(
            'La hora y el permiso del sistema se configurarán después.',
          ),
        ),
      ],
    );
  }

  Widget _faithStep() {
    return _stepShell(
      title: 'Fe, solo si tú quieres',
      subtitle: '¿Quieres incluir contenido de fe cristiana en STK Haven?',
      actionLabel: 'Ver resumen',
      onAction: _next,
      children: [
        _choice(
          value: FaithContentPreference.enabled,
          selected: _faith,
          title: 'Sí, quiero incluirlo',
          subtitle: 'Versículo diario, Biblia, Haven Faith y estudio.',
          onTap: (value) => setState(() => _faith = value),
        ),
        _choice(
          value: FaithContentPreference.disabled,
          selected: _faith,
          title: 'No, prefiero mantenerlo oculto',
          subtitle: 'No se cargarán recursos de Fe en segundo plano.',
          onTap: (value) => setState(() => _faith = value),
        ),
        _choice(
          value: FaithContentPreference.undecided,
          selected: _faith,
          title: 'Decidir después',
          subtitle: 'Podrás activarlo desde Perfil cuando quieras.',
          onTap: (value) => setState(() => _faith = value),
        ),
      ],
    );
  }

  Widget _summaryStep() {
    final profile = _buildProfile();
    final recommended =
        OnboardingRecommendationService.recommend(profile);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Todo listo', style: AppTypography.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Estas son tus preferencias iniciales.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _summaryRow('Objetivo', _goalLabel(_goal)),
                  _summaryRow('Experiencia', _experienceLabel(_experience)),
                  _summaryRow(
                    'Frecuencia',
                    _daysPerWeek == null
                        ? 'Por decidir'
                        : '$_daysPerWeek días/semana',
                  ),
                  _summaryRow('Duración', _durationLabel(_duration)),
                  _summaryRow('Entorno', _environmentLabel(_environment)),
                  _summaryRow('Peso', _weightUnit.label),
                  _summaryRow(
                    'Fe',
                    switch (_faith) {
                      FaithContentPreference.enabled => 'Incluida',
                      FaithContentPreference.disabled => 'Oculta',
                      FaithContentPreference.undecided => 'Decidir después',
                    },
                  ),
                  if (recommended != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFaded,
                        borderRadius: AppRadius.lg_,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROGRAMA RECOMENDADO',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            recommended.name,
                            style: AppTypography.headlineLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recommended.description,
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  ProgramPreviewModal(program: recommended),
                            ),
                            child: const Text('Ver rutinas'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (recommended != null)
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: _saving ? 'Guardando…' : 'Usar programa recomendado',
                onPressed: _saving
                    ? null
                    : () => _finish(installRecommended: true),
              ),
            ),
          if (recommended != null) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed:
                  _saving ? null : () => _finish(installRecommended: false),
              child: Text(
                recommended == null
                    ? 'Entrar a STK Haven'
                    : 'Continuar sin instalar programa',
              ),
            ),
          ),
        ],
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

  Widget _choice<T>({
    required T value,
    required T? selected,
    required String title,
    String? subtitle,
    required ValueChanged<T> onTap,
  }) {
    final active = value == selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: active ? AppColors.primaryFaded : AppColors.surface,
        borderRadius: AppRadius.md_,
        child: InkWell(
          borderRadius: AppRadius.md_,
          onTap: () => onTap(value),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: AppRadius.md_,
              border: Border.all(
                color: active
                    ? AppColors.primary
                    : AppColors.surfaceBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  active
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: active
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.bodyLarge),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
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

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(value, style: AppTypography.labelMedium),
        ],
      ),
    );
  }

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
}
