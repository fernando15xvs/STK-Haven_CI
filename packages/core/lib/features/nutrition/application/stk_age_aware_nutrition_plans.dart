import 'package:core/features/onboarding/application/stk_age_eligibility.dart';

/// Age-adapted intent labels and education for STK Haven nutrition.
///
/// This does NOT calculate energy, weight-loss targets or clinical advice.
/// Adult numerical nutrition remains authorized exclusively by the server.
enum StkNutritionIntent { maintenance, volume, deficit }

/// Exactly two age-specific nutrition experiences for eligible users.
/// Neither mode represents age/identity verification or a server grant.
enum StkNutritionAgeMode { adolescent15To17, adult18Plus }

extension StkNutritionAgeModeLabels on StkNutritionAgeMode {
  String get label => switch (this) {
    StkNutritionAgeMode.adolescent15To17 => 'Nutrición 15–17 años',
    StkNutritionAgeMode.adult18Plus => 'Nutrición 18+',
  };
}

enum StkNutritionAudience {
  under15,
  teen15To17,
  adultDeclared,
  adultVerified,
  unknownAge;

  bool get canUseAdultPlanner => this == StkNutritionAudience.adultVerified;
  bool get isAdolescent => this == StkNutritionAudience.teen15To17;

  /// Ineligible and legacy/unknown-age accounts have no age-specific mode.
  StkNutritionAgeMode? get ageMode => switch (this) {
    StkNutritionAudience.teen15To17 =>
      StkNutritionAgeMode.adolescent15To17,
    StkNutritionAudience.adultDeclared ||
    StkNutritionAudience.adultVerified =>
      StkNutritionAgeMode.adult18Plus,
    _ => null,
  };
}

class StkNutritionGoalExplanation {
  const StkNutritionGoalExplanation({
    required this.title,
    required this.introduction,
    required this.guidance,
    required this.disclaimer,
    required this.calorieTargetAllowed,
  });

  final String title;
  final String introduction;
  final String guidance;
  final String disclaimer;
  /// A UI hint, NOT a server grant. The numeric planner checks the backend.
  final bool calorieTargetAllowed;
}

class StkAgeAwareNutritionPlans {
  const StkAgeAwareNutritionPlans._();

  static StkNutritionAudience audience({
    required int? declaredAge,
    required bool backendVerifiedAdult,
  }) {
    return switch (StkAgeEligibility.classifyYears(declaredAge)) {
      StkDeclaredAgeBand.unknownLegacy => StkNutritionAudience.unknownAge,
      StkDeclaredAgeBand.under15 => StkNutritionAudience.under15,
      StkDeclaredAgeBand.teen15To17 => StkNutritionAudience.teen15To17,
      StkDeclaredAgeBand.adult18PlusDeclared => backendVerifiedAdult
          ? StkNutritionAudience.adultVerified
          : StkNutritionAudience.adultDeclared,
    };
  }

  static String label(StkNutritionIntent intent) => switch (intent) {
    StkNutritionIntent.maintenance => 'Mantenimiento',
    StkNutritionIntent.volume => 'Volumen',
    StkNutritionIntent.deficit => 'Déficit',
  };

  /// The adolescent cards never turn a selected intent into a calorie
  /// budget, eating restriction, automatic body-weight target or adult
  /// equation. The "déficit" name is only an educational navigation label.
  static StkNutritionGoalExplanation describe({
    required StkNutritionAudience audience,
    required StkNutritionIntent intent,
  }) {
    final title = label(intent);

    if (audience == StkNutritionAudience.under15) {
      return StkNutritionGoalExplanation(
        title: title,
        introduction: 'STK Haven está diseñado para personas de 15 años o más.',
        guidance: 'La orientación nutricional de la app no está habilitada '
            'para edades inferiores a la mínima.',
        disclaimer: 'No se ha generado ningún objetivo.',
        calorieTargetAllowed: false,
      );
    }

    if (audience == StkNutritionAudience.unknownAge) {
      return StkNutritionGoalExplanation(
        title: title,
        introduction: 'Conoce los objetivos sin cálculos automáticos.',
        guidance: 'Indica tu edad real en Perfil para adaptar la experiencia. '
            'Mientras tanto, Food Vision ofrece identificación descriptiva '
            'de alimentos si el servicio está disponible.',
        disclaimer: 'La fecha declarada no verifica la mayoría de edad.',
        calorieTargetAllowed: false,
      );
    }

    if (audience.isAdolescent) {
      final message = switch (intent) {
        StkNutritionIntent.maintenance => (
          'Energía para tus actividades',
          'Prioriza comidas variadas, horarios regulares, hidratación, '
              'descanso y suficiente energía para crecer y entrenar.',
        ),
        StkNutritionIntent.volume => (
          'Fuerza y recuperación',
          'Desarrolla fuerza con entrenamiento progresivo, comidas '
              'variadas y descanso suficiente. No se fija un superávit '
              'calórico automático durante el crecimiento.',
        ),
        StkNutritionIntent.deficit => (
          'Hábitos y bienestar',
          'Este apartado te ayuda a revisar hábitos saludables, '
              'sin dietas restrictivas, objetivos automáticos de '
              'pérdida de peso ni compensar alimentos con ejercicio.',
        ),
      };
      return StkNutritionGoalExplanation(
        title: title,
        introduction: message.$1,
        guidance: message.$2,
        disclaimer: 'En menores de 18 años, cualquier cambio de peso que '
            'requiera intervención debe evaluarse con un profesional. '
            'La IA puede equivocarse al interpretar fotografías.',
        calorieTargetAllowed: false,
      );
    }

    final adultCopy = switch (intent) {
      StkNutritionIntent.maintenance => (
        'Equilibrio y constancia',
        'Observa tus hábitos de alimentación, actividad y recuperación. '
            'Los rangos energéticos, cuando estén habilitados, son '
            'orientativos y se revisan voluntariamente.',
      ),
      StkNutritionIntent.volume => (
        'Desarrollo muscular gradual',
        'Acompaña la fuerza progresiva con alimentación y descanso. '
            'Si tienes acceso al plan adulto, podrás revisar una '
            'estimación de superávit gradual antes de guardarla.',
      ),
      StkNutritionIntent.deficit => (
        'Ajustes graduales',
        'Prioriza hábitos sostenibles. Si tienes acceso al plan adulto, '
            'podrás revisar un rango orientativo y ajustarlo de forma '
            'gradual, sin recomendaciones extremas.',
      ),
    };

    return StkNutritionGoalExplanation(
      title: title,
      introduction: adultCopy.$1,
      guidance: adultCopy.$2,
      disclaimer: audience.canUseAdultPlanner
          ? 'La estimación no sustituye orientación profesional. '
              'Seleccionar un objetivo nunca lo guarda automáticamente.'
          : 'Los cálculos personalizados requieren autorización '
              'válida del servidor; declarar una edad no la concede.',
      calorieTargetAllowed: audience.canUseAdultPlanner,
    );
  }
}
