import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'dart:async';

import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/onboarding/application/stk_age_eligibility.dart';
import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:core/features/onboarding/data/stk_legal_server_receipt_service.dart';
import 'package:core/features/onboarding/application/onboarding_recommendation_service.dart';
import 'package:core/features/onboarding/application/program_service.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';
import 'package:gym_tracker/features/onboarding/data/stk_mobile_legal_receipt_store.dart';
import 'package:gym_tracker/features/onboarding/presentation/stk_mobile_legal_config.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/stk_legal_document_page.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/stk_legal_acceptance_panel.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/program_preview_modal.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({
    super.key,
    this.enable15Plus,
    this.legalDocuments,
  });

  /// Tests may inject an approved fixture; production defaults to OFF until
  /// published HTTPS documents and their hashes have been configured.
  final bool? enable15Plus;
  final StkLegalDocumentSet? legalDocuments;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  // Existing users keep the 7-step legacy onboarding until the 15+ legal
  // release gate is explicitly enabled. No web app onboarding is changed.
  static const int _legacyPageCount = 7;
  bool get _legalFlowRequested =>
      widget.enable15Plus ?? StkMobileLegalConfig.enabled;
  StkLegalDocumentSet get _legalDocs =>
      widget.legalDocuments ?? StkMobileLegalConfig.documents;
  int get _pageCount => _legalFlowRequested ? 9 : _legacyPageCount;

  Future<String>? _guestIdFuture;
  Future<String> get _guestId => _guestIdFuture ??=
      StkMobileLegalReceiptStore(Hive.box<dynamic>(HiveBoxes.metadata))
          .getOrCreateGuestId();

  bool _installRecommendedAfterLegal = false;
  bool _legalDeclined = false;

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
  DateTime? _birthDate;
  DateTime? _eligibilityBirthDate;
  GenderIdentity? _genderIdentity;
  EnergyEquationSex? _equationSexForEnergy;
  bool _demographicConsent=false;
  DateTime? _demographicConsentedAt;
  bool _saveFirstMeasurement = false;
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
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

  void _reviewOrFinish({required bool installRecommended}) {
    if (!_legalFlowRequested) {
      unawaited(_finish(installRecommended: installRecommended));
      return;
    }
    // The summary precedes a dedicated final legal step in the 15+ flow.
    _installRecommendedAfterLegal = installRecommended;
    _next();
  }

  void _declineLegal() {
    setState(() => _legalDeclined = true);
    unawaited(Navigator.of(context).maybePop());
  }

  Future<bool> _openLegalDocument(
    String title, String url, String expectedSha256,
  ) async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StkLegalDocumentPage(
          title: title,
          httpsUrl: url,
          expectedSha256: expectedSha256,
        ),
      ),
    );
    return verified == true;
  }

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
      dateOfBirth: _demographicConsent
          ? (_legalFlowRequested ? _eligibilityBirthDate : _birthDate)
          : null,
      eligibilityBirthDate:
          _legalFlowRequested ? _eligibilityBirthDate : null,
      genderIdentity: _demographicConsent?_genderIdentity:null,
      equationSexForEnergy: _demographicConsent?_equationSexForEnergy:null,
      optionalDemographicsConsented:_demographicConsent,
      optionalDemographicsConsentedAt:_demographicConsentedAt,
      optionalDemographicsUpdatedAt:_demographicConsent &&
        (_birthDate!=null || _genderIdentity!=null ||
         _equationSexForEnergy!=null)
        ?DateTime.now():null,
      onboardingVersion: UserExperienceProfile.currentOnboardingVersion,
    );
  }

  Future<void> _finish({
    required bool installRecommended,
    StkLegalAcceptanceReceipt? legalReceipt,
  }) async {
    if (_saving) return;
    // A checkbox or DOB alone never authorizes adult numeric nutrition.
    // Fail closed if a caller skips the final legal step.
    if (_legalFlowRequested) {
      final activeUid = Supabase.instance.client.auth.currentUser?.id;
      final actualType = activeUid == null
          ? StkLegalSubjectType.guest
          : StkLegalSubjectType.authenticated;
      final actualSubjectId = activeUid ?? await _guestId;
      if (!_legalDocs.canCollectAcceptance ||
          !StkAgeEligibility.canBeginNewAccount(
            birthDate: _eligibilityBirthDate,
            today: DateTime.now(),
          ) ||
          legalReceipt == null ||
          !legalReceipt.isCurrentFor(
            documents: _legalDocs,
            subjectType: actualType,
            subjectId: actualSubjectId,
          )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Revisa tu edad y acepta los documentos vigentes.'),
          ));
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _saving = true);

    try {
      final rawWeight = _weightController.text.trim();
      final rawHeight = _heightController.text.trim();
      final weight = double.tryParse(rawWeight.replaceAll(',', '.'));
      final height = double.tryParse(rawHeight.replaceAll(',', '.'));
      final weightKg = weight == null ? null :
          WeightConverter.toCanonicalKg(weight, _weightUnit);
      if (_saveFirstMeasurement &&
          ((rawWeight.isNotEmpty && (weightKg == null || !weightKg.isFinite ||
              weightKg <= 0 || weightKg > 500)) ||
           (rawHeight.isNotEmpty && (height == null || !height.isFinite ||
              height < 40 || height > 250)) ||
           (rawWeight.isEmpty && rawHeight.isEmpty))) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Revisa peso y altura antes de guardarlos en Medidas.'),
        ));
        return;
      }
      if (_legalFlowRequested && legalReceipt != null) {
        final store = StkMobileLegalReceiptStore(
          Hive.box<dynamic>(HiveBoxes.metadata),
        );
        // Recheck after async validation: a sign-in/sign-out/account switch
        // must never write a receipt or profile under a different identity.
        final activeUid = Supabase.instance.client.auth.currentUser?.id;
        // The live 15+ rollout requires a remotely stamped receipt.
        // Local Hive acknowledgements and a self-declared DOB are NOT grants.
        // Widget-only QA fixtures can opt into the flow without publishing
        // documents; production builds stay disabled until approved.
        if (StkMobileLegalConfig.enabled && activeUid != null) {
          final recorded = await StkLegalServerReceiptService(
            Supabase.instance.client,
          ).recordAcceptance(
            receipt: legalReceipt,
            documents: _legalDocs,
            declaredBirthDate: _eligibilityBirthDate!,
          );
          if (!recorded) {
            throw StateError('No se pudo confirmar la versión legal con el servidor.');
          }
          if (activeUid != Supabase.instance.client.auth.currentUser?.id) {
            throw StateError('La cuenta cambió durante la aceptación.');
          }
        }
        if (legalReceipt.subjectType == StkLegalSubjectType.authenticated) {
          await store.saveAuthenticated(
            legalReceipt,
            activeUserId: activeUid,
          );
        } else {
          if (activeUid != null) {
            throw StateError('La cuenta cambió durante la aceptación.');
          }
          await store.saveGuest(legalReceipt);
        }
        if (activeUid != Supabase.instance.client.auth.currentUser?.id) {
          throw StateError('La cuenta cambió durante el registro.');
        }
      }
      final profile = _buildProfile();
      await ref
          .read(userExperienceProfileProvider.notifier)
          .updateProfile(profile);

      // One first measurement only, with explicit opt-in; never a duplicate
      // weight/height table in the experience profile or nutrition planner.
      if (_saveFirstMeasurement) {
        const id = 'stk_onboarding_first_measurement_v3';
        if (!ref.read(bodyMeasurementProvider).any((m) => m.id == id)) {
          await ref.read(bodyMeasurementProvider.notifier).saveMeasurement(
            BodyMeasurement(
              id: id, date: DateTime.now(),
              weightKg: rawWeight.isEmpty ? null : weightKg,
              heightCm: rawHeight.isEmpty ? null : height,
            ),
          );
        }
      }

      final settings = ref.read(settingsProvider);
      ref
          .read(settingsProvider.notifier)
          .updateSettings(
            settings.copyWith(
              weightUnit: profile.weightUnit,
              showDailyVerse: profile.faithEnabled,
              dailyVerseNotifications: false,
            ),
          );

      // One source of truth for minors and users who omit their birth date.
      // Neither group is auto-enrolled in a high-frequency adult preset.
      final recommended = OnboardingRecommendationService.recommend(profile);
      if (installRecommended && recommended != null) {
        await ref
            .read(programServiceProvider)
            .installProgram(
              recommended,
              trainingDaysPerWeek: profile.trainingDaysPerWeek,
            );
      } else {
        await ref.read(programServiceProvider).completeOnboardingFromScratch();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo guardar tu configuración. Inténtalo otra vez.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_legalFlowRequested && !_legalDocs.canCollectAcceptance) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 40),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Documentos pendientes', style: AppTypography.headlineLarge),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'La versión 15+ estará disponible cuando los Términos '
                    'y la Política de Privacidad hayan sido aprobados y publicados.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Salir'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_legalDeclined) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No completaste el registro',
                      style: AppTypography.headlineLarge),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Puedes cerrar la app o revisar los documentos '
                    'y decidir después. No se ha guardado una aceptación.'),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => setState(() => _legalDeclined = false),
                    child: const Text('Volver a revisar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
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
                      onPressed: _saving
                          ? null
                          : () => _goTo(_currentIndex - 1),
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
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: [
                  _welcomeStep(context),
                  if (_legalFlowRequested) _ageStep(),
                  _goalStep(),
                  _scheduleStep(),
                  _preferencesStep(),
                  _personalStep(),
                  _faithStep(),
                  _summaryStep(context),
                  if (_legalFlowRequested) _legalStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepShell(
    BuildContext context, {
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
              color: AppColors.of(context).textSecondary,
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

  Widget _welcomeStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.of(context).primaryFaded,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 48,
              color: AppColors.of(context).primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Haz que STK Haven\nse adapte a ti',
            textAlign: TextAlign.center,
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Son unas pocas preguntas. Podrás cambiar todo después desde tu perfil.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.of(context).textSecondary,
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

  Widget _ageStep() {
    final colors = AppColors.of(context);
    final age = StkAgeEligibility.ageOn(
      _eligibilityBirthDate,
      DateTime.now(),
    );
    final eligible = StkAgeEligibility.canBeginNewAccount(
      birthDate: _eligibilityBirthDate,
      today: DateTime.now(),
    );
    final dob = _eligibilityBirthDate;
    return _stepShell(
      context,
      title: 'Tu edad, tu experiencia',
      subtitle: 'STK Haven está diseñado para personas de 15 años o más.',
      actionLabel: 'Continuar',
      onAction: eligible ? _next : null,
      children: [
        Text('Fecha de nacimiento', style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Indica tu fecha real. Adaptaremos el entrenamiento y la '
          'orientación nutricional a tu etapa; esta declaración no '
          'verifica tu identidad.',
          style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          key: const ValueKey('stk_15plus_birth_date'),
          icon: const Icon(Icons.cake_outlined),
          onPressed: () async {
            final today = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              helpText: 'Selecciona tu fecha de nacimiento real',
              initialDate: dob ?? DateTime(
                today.year - 15, today.month, today.day,
              ),
              firstDate: DateTime(1900),
              lastDate: today,
            );
            if (picked != null && mounted) {
              setState(() => _eligibilityBirthDate = picked);
            }
          },
          label: Text(
            dob == null
                ? 'Seleccionar fecha de nacimiento'
                : '${dob.day.toString().padLeft(2, '0')}/'
                    '${dob.month.toString().padLeft(2, '0')}/'
                    '${dob.year} · ${age ?? '?'} años',
          ),
        ),
        if (age != null && age < 15) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Debes tener al menos 15 años cumplidos para continuar.',
            key: const ValueKey('stk_15plus_underage_message'),
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        if (age != null && age >= 15 && age < 18) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Las herramientas nutricionales estarán adaptadas a tu '
            'etapa de crecimiento, sin déficits automáticos.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _legalStep() {
    final activeUid = Supabase.instance.client.auth.currentUser?.id;
    return FutureBuilder<String>(
      future: activeUid == null ? _guestId : Future<String>.value(activeUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudo preparar tu registro.'),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        return StkLegalAcceptancePanel(
          key: const ValueKey('stk_onboarding_legal_step'),
          birthDate: _eligibilityBirthDate,
          documents: _legalDocs,
          subjectType: activeUid == null
              ? StkLegalSubjectType.guest
              : StkLegalSubjectType.authenticated,
          subjectId: snapshot.data!,
          locale: 'es-PE',
          onViewTerms: () => _openLegalDocument(
            'Términos y Condiciones', _legalDocs.termsUrl,
            _legalDocs.termsSha256,
          ),
          onViewPrivacy: () => _openLegalDocument(
            'Política de Privacidad', _legalDocs.privacyUrl,
            _legalDocs.privacySha256,
          ),
          onAccepted: (receipt) => unawaited(_finish(
            installRecommended: _installRecommendedAfterLegal,
            legalReceipt: receipt,
          )),
          onDecline: _declineLegal,
        );
      },
    );
  }

  Widget _goalStep() {
    return _stepShell(
      context,
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
      context,
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
      context,
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

  Widget _personalStep() {
    final dob = _birthDate;
    final age = _buildProfile().ageAt(DateTime.now());
    final colors = AppColors.of(context);
    return _stepShell(
      context,
      title: 'Tu perfil básico',
      subtitle: 'Estos datos son opcionales. Te evitan repetir preguntas.',
      actionLabel: 'Continuar',
      onAction: _next,
      children: [
        if (!_legalFlowRequested) ...[
        Text('Fecha de nacimiento (opcional)', style: AppTypography.labelLarge),
        const SizedBox(height: 6),
        Text(
          'La usamos para adaptar la experiencia, no como prueba de mayoría de edad.',
          style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height:8),
        ],
        CheckboxListTile(
          key:const ValueKey('onboarding_optional_demographic_consent'),
          contentPadding:EdgeInsets.zero,
          title:const Text('Autorizo guardar estos datos opcionales'),
          subtitle:const Text('Se usan para adaptar la experiencia y '
            'cálculos adultos opcionales. Pueden aparecer en una copia '
            'de seguridad que exportes o subas voluntariamente. '
            'No verifican la mayoría de edad. Puedes continuar sin ellos.'),
          value:_demographicConsent,
          onChanged:(value)=>setState((){
            _demographicConsent=value??false;
            _demographicConsentedAt=_demographicConsent?DateTime.now():null;
            if(!_demographicConsent){
              _birthDate=null;
              _genderIdentity=null;
              _equationSexForEnergy=null;
            }
          }),
        ),
        const SizedBox(height: 8),
        if (!_legalFlowRequested) ...[
        OutlinedButton.icon(
          key: const ValueKey('onboarding_birth_date'),
          icon: const Icon(Icons.cake_outlined),
          label: Text(dob == null
              ? 'Indicar fecha'
              : '${dob.day.toString().padLeft(2, '0')}/'
                '${dob.month.toString().padLeft(2, '0')}/${dob.year}'
                ' · ${age ?? '?'} años'),
          onPressed: !_demographicConsent?null:() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: dob ?? DateTime(now.year - 18, now.month, now.day),
              firstDate: DateTime(1900),
              lastDate: now,
            );
            if (picked != null && mounted) setState(() => _birthDate = picked);
          },
        ),
        if (dob != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _birthDate = null),
              child: const Text('No indicar'),
            ),
          ),
        ],
        if (age != null && age < 18)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'STK Haven mantiene tus rutinas y hábitos. '
              'Los objetivos calóricos personalizados no están disponibles '
              'para menores; priorizamos técnica, descanso y alimentación variada.',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<GenderIdentity>(
          initialValue: _genderIdentity,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Género (opcional)'),
          items: const [
            DropdownMenuItem(value: GenderIdentity.woman, child: Text('Mujer')),
            DropdownMenuItem(value: GenderIdentity.man, child: Text('Hombre')),
            DropdownMenuItem(value: GenderIdentity.nonBinary,
              child: Text('No binario / otra identidad')),
            DropdownMenuItem(value: GenderIdentity.preferNotToSay,
              child: Text('Prefiero no decirlo')),
          ],
          onChanged: !_demographicConsent?null:
            (value) => setState(() => _genderIdentity = value),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<EnergyEquationSex>(
          initialValue: _equationSexForEnergy,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Parámetro para cálculo energético (opcional)',
            helperText: 'Solo para estimaciones adultas; independiente del género.',
          ),
          items: const [
            DropdownMenuItem(value: EnergyEquationSex.female,
              child: Text('Referencia femenina')),
            DropdownMenuItem(value: EnergyEquationSex.male,
              child: Text('Referencia masculina')),
          ],
          onChanged: !_demographicConsent?null:
            (value) => setState(() => _equationSexForEnergy = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Primer registro en Medidas (opcional)',
          style: AppTypography.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'El peso y la altura solo se guardarán en Medidas si lo autorizas. '
          'No se crean campos duplicados en Nutrición.',
          style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Peso (${_weightUnit.label})'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _heightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Altura (cm)'),
        ),
        CheckboxListTile(
          key: const ValueKey('onboarding_save_first_measurement'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Guardar como primera medida'),
          subtitle: const Text('Opcional. Se guardará solo una vez.'),
          value: _saveFirstMeasurement,
          onChanged: (v) => setState(() => _saveFirstMeasurement = v ?? false),
        ),
      ],
    );
  }

  Widget _faithStep() {
    return _stepShell(
      context,
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

  Widget _summaryStep(BuildContext context) {
    final profile = _buildProfile();
    final age=profile.ageAt(DateTime.now());
    final recommended = OnboardingRecommendationService.recommend(profile);

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
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _summaryRow(context, 'Objetivo', _goalLabel(_goal)),
                  _summaryRow(
                    context,
                    'Experiencia',
                    _experienceLabel(_experience),
                  ),
                  _summaryRow(
                    context,
                    'Frecuencia',
                    _daysPerWeek == null
                        ? 'Por decidir'
                        : '$_daysPerWeek días/semana',
                  ),
                  _summaryRow(context, 'Duración', _durationLabel(_duration)),
                  _summaryRow(
                    context,
                    'Entorno',
                    _environmentLabel(_environment),
                  ),
                  _summaryRow(context, 'Unidad de peso', _weightUnit.label),
                  _summaryRow(context,'Datos demográficos opcionales',
                    _demographicConsent?'Autorizados':'Omitidos'),
                  if (_birthDate != null ||
                      (_legalFlowRequested && _eligibilityBirthDate != null))
                    _summaryRow(context, 'Edad indicada',
                      '${_buildProfile().ageAt(DateTime.now()) ?? 'Sin dato'} años'),
                  _summaryRow(context, 'Primeras medidas',
                    _saveFirstMeasurement ? 'Se guardarán en Medidas' : 'No guardar'),
                  _summaryRow(context, 'Fe', switch (_faith) {
                    FaithContentPreference.enabled => 'Incluida',
                    FaithContentPreference.disabled => 'Oculta',
                    FaithContentPreference.undecided => 'Decidir después',
                  }),
                  if (age != null && age < 18) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Tus rutinas podrán configurarse de forma gradual. '
                      'No instalamos automáticamente un programa de alta exigencia '
                      'para menores.',
                      style:AppTypography.bodySmall),
                  ] else if(age==null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Puedes entrenar y crear tus propias rutinas sin '
                      'indicar fecha de nacimiento. Para evitar asignarte un '
                      'programa adulto sin conocer tu etapa de desarrollo, '
                      'no instalaremos uno automáticamente. '
                      'Puedes configurar rutinas después en Entrenar.',
                      key:const ValueKey('onboarding_unknown_age_safe_training'),
                      style:AppTypography.bodySmall),
                  ],
                  if (recommended != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.of(context).primaryFaded,
                        borderRadius: AppRadius.lg_,
                        border: Border.all(
                          color: AppColors.of(
                            context,
                          ).primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROGRAMA RECOMENDADO',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.of(context).primary,
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
                    : () => _reviewOrFinish(installRecommended: true),
              ),
            ),
          if (recommended != null) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _saving
                  ? null
                  : () => _reviewOrFinish(installRecommended: false),
              child: Text(
                _legalFlowRequested
                    ? 'Revisar Términos y Privacidad'
                    : recommended == null
                        ? 'Entrar a STK Haven'
                        : 'Continuar sin instalar programa',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationChip(SessionDurationPreference value, String label) {
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
        color: active
            ? AppColors.of(context).primaryFaded
            : AppColors.of(context).surface,
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
                    ? AppColors.of(context).primary
                    : AppColors.of(context).surfaceBorder,
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
                      ? AppColors.of(context).primary
                      : AppColors.of(context).textSecondary,
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
                            color: AppColors.of(context).textSecondary,
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

  Widget _summaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.of(context).textSecondary,
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
