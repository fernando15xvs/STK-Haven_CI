import 'package:core/domain/models/study_plan.dart';
import 'package:core/features/habits/application/study_plan_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudyPlanEnrollment', () {
    final start = DateTime(2026, 9, 24);

    test('advances to first incomplete step without erasing history', () {
      final enrollment = StudyPlanEnrollment(
        id: 'e1',
        planId: 'john_7_sessions',
        startedAt: start,
        updatedAt: start,
        completedStepIndices: const {0, 1, 3},
      );

      expect(enrollment.nextStepIndex(7), 2);
      expect(enrollment.isComplete(7), isFalse);
    });

    test('detects a completed plan', () {
      final enrollment = StudyPlanEnrollment(
        id: 'e1',
        planId: 'john_7_sessions',
        startedAt: start,
        updatedAt: start,
        completedStepIndices: const {0, 1, 2},
      );

      expect(enrollment.nextStepIndex(3), isNull);
      expect(enrollment.isComplete(3), isTrue);
    });

    test('pause round-trip keeps completed sessions', () {
      final original = StudyPlanEnrollment(
        id: 'e1',
        planId: 'psalms_7_sessions',
        startedAt: start,
        updatedAt: start,
        completedStepIndices: const {0, 1},
        paused: true,
      );

      final restored = StudyPlanEnrollment.fromJson(original.toJson());

      expect(restored.paused, isTrue);
      expect(restored.completedStepIndices, {0, 1});
    });
  });

  group('StudyPlanCatalog', () {
    test('stores references rather than Bible text payloads', () {
      for (final plan in StudyPlanCatalog.plans) {
        expect(plan.steps, isNotEmpty);
        for (final step in plan.steps) {
          expect(step.reference, isNotEmpty);
          expect(step.title, isNotEmpty);
        }
      }
    });

    test('resolves known plans by id', () {
      expect(StudyPlanCatalog.byId('john_7_sessions')?.steps.length, 7);
      expect(StudyPlanCatalog.byId('missing'), isNull);
    });
  });
}
