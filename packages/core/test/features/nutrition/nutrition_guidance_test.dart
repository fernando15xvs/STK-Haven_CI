import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NutritionGuidancePlan', () {
    test('editor payload contains only non-clinical guidance fields', () {
      final plan = NutritionGuidancePlan(
        id: 'plan-1',
        relationshipId: 'rel-1',
        coachUserId: 'coach-1',
        clientUserId: 'client-1',
        status: NutritionGuidanceStatus.active,
        currentVersion: 2,
        version: 2,
        title: 'Guía general',
        overview: 'Organización de comidas.',
        hydrationNotes: 'Mantener hidratación habitual.',
        generalNotes: 'Ajustar según preferencias.',
        createdAt: DateTime(2026, 9, 24),
        meals: const [
          NutritionGuidanceMeal(
            position: 0,
            name: 'Desayuno',
            timingLabel: 'Mañana',
            items: [
              NutritionGuidanceItem(
                position: 0,
                foodExample: 'Avena con fruta',
                servingNote: 'Ejemplo flexible',
              ),
            ],
          ),
        ],
      );

      final payload = plan.toEditorPayload();
      final serialized = payload.toString().toLowerCase();

      expect(payload['title'], 'Guía general');
      expect(payload['meals'], hasLength(1));
      expect(serialized, isNot(contains('calorie')));
      expect(serialized, isNot(contains('caloría')));
      expect(serialized, isNot(contains('macro_target')));
      expect(serialized, isNot(contains('weight_target')));
      expect(serialized, isNot(contains('deficit')));
    });

    test('parses immutable version independently from current version', () {
      final plan = NutritionGuidancePlan.fromJson({
        'id': 'plan-1',
        'relationship_id': 'rel-1',
        'coach_user_id': 'coach-1',
        'client_user_id': 'client-1',
        'status': 'active',
        'current_version': 3,
        'version': 1,
        'title': 'Versión inicial',
        'scope_notice': NutritionGuidancePlan.defaultScopeNotice,
        'created_at': '2026-09-24T10:00:00Z',
        'meals': const [],
      });

      expect(plan.currentVersion, 3);
      expect(plan.version, 1);
      expect(plan.title, 'Versión inicial');
    });

    test('unknown status fails closed to archived', () {
      final summary = NutritionGuidanceSummary.fromJson({
        'id': 'plan-1',
        'relationship_id': 'rel-1',
        'coach_user_id': 'coach-1',
        'client_user_id': 'client-1',
        'status': 'unexpected',
        'current_version': 1,
        'title': 'Plan',
        'updated_at': '2026-09-24T10:00:00Z',
      });

      expect(summary.status, NutritionGuidanceStatus.archived);
    });
  });
}
