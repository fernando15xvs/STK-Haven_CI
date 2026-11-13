import 'package:core/domain/models/active_program_state.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/training_program_legacy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 11, 13);
  final legacy = ActiveProgramState(
    presetProgramId: 'preset', presetVersion: 1,
    programNameSnapshot: 'Upper Lower', startedAt: at,
    durationWeeks: 8, generatedRoutineIds: const ['a', 'b'],
  );
  TrainingProgram plan({bool active = true, List<String> ids = const ['a','b']}) =>
      TrainingProgram(id: 'modern', name: 'Moderno', routineIds: ids,
        createdAt: at, startedAt: at, isActive: active);

  test('modern active or paused suppresses legacy even when other plans exist', () {
    expect(TrainingProgramLegacyPolicy.dashboardFallback(
      programs: [plan()], legacy: legacy), isNull);
    expect(TrainingProgramLegacyPolicy.dashboardFallback(
      programs: [plan(active: false)], legacy: legacy), isNull);
    expect(TrainingProgramLegacyPolicy.dashboardFallback(
      programs: const [], legacy: legacy), same(legacy));
  });

  test('deleting matching onboarding plan clears only corresponding snapshot', () {
    expect(TrainingProgramLegacyPolicy.shouldClearLegacyOnDelete(
      deleted: plan(), legacy: legacy), isTrue);
    expect(TrainingProgramLegacyPolicy.shouldClearLegacyOnDelete(
      deleted: plan(ids: const ['different']), legacy: legacy), isFalse);
  });
}
