import 'package:core/features/nutrition/application/hydration_context_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown context never fabricates a target or a prescription',(){
    const guidance=HydrationContextGuidance();
    expect(guidance.canReviewManualGoal,isTrue);
    expect(guidance.factorsSummary,'No indicaste factores adicionales.');
    expect(guidance.guidance,contains('no se puede inferir una cantidad personalizada'));
    expect(guidance.guidance,contains('Tu meta actual se conservará'));
  });

  test('activity, heat and sweating provide explanation, not milliliters',(){
    const guidance=HydrationContextGuidance(
      prolongedActivity:true,hotEnvironment:true,heavySweating:true,
    );
    expect(guidance.factorsSummary,contains('actividad prolongada'));
    expect(guidance.factorsSummary,contains('ambiente caluroso'));
    expect(guidance.factorsSummary,contains('sudoración elevada'));
    expect(guidance.canReviewManualGoal,isTrue);
    expect(guidance.guidance,contains('No hay datos suficientes'));
    expect(guidance.guidance,isNot(contains('ml/día')));
  });

  test('fluid restriction stops a self-directed target review',(){
    const guidance=HydrationContextGuidance(
      prolongedActivity:true,fluidRestriction:true);
    expect(guidance.canReviewManualGoal,isFalse);
    expect(guidance.guidance,contains('consulta con el profesional'));
    // The sensitive medical-context answer is ephemeral: this model has
    // no preferences, remote writes or calorie calculation.
  });

}
