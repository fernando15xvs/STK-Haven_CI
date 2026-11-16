/// Voluntary, ephemeral context for reviewing a manually entered water goal.
/// Never infers milliliters, calorie phase, age, or a medical prescription.
class HydrationContextGuidance {
  const HydrationContextGuidance({
    this.prolongedActivity=false,
    this.hotEnvironment=false,
    this.heavySweating=false,
    this.fluidRestriction=false,
  });

  final bool prolongedActivity;
  final bool hotEnvironment;
  final bool heavySweating;
  /// True when the user reports a professional fluid limit. This flag is
  /// deliberately not persisted or uploaded to any user profile.
  final bool fluidRestriction;

  bool get canReviewManualGoal => !fluidRestriction;

  String get factorsSummary {
    final factors=<String>[
      if(prolongedActivity)'actividad prolongada',
      if(hotEnvironment)'ambiente caluroso',
      if(heavySweating)'sudoración elevada',
    ];
    return factors.isEmpty
      ?'No indicaste factores adicionales.'
      :'Factores señalados: ${factors.join(', ')}.';
  }

  String get guidance {
    if(fluidRestriction) {
      return 'Has indicado una restricción de líquidos. '
        'Antes de cambiar esta meta, consulta con el profesional '
        'que te dio esa indicación.';
    }
    if(prolongedActivity || hotEnvironment || heavySweating){
      return 'La actividad, el calor o la sudoración pueden cambiar '
        'tus necesidades. No hay datos suficientes para calcular '
        'una cantidad personalizada de agua: revisa tu situación '
        'sin asumir que más siempre es mejor.';
    }
    return 'Sin datos sobre actividad, calor o sudoración no se '
      'puede inferir una cantidad personalizada. '
      'Tu meta actual se conservará si cancelas.';
  }
}
