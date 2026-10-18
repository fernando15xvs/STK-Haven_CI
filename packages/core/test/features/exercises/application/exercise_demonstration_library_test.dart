import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/features/exercises/application/exercise_demonstration_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guides are specific and available for common exercises', () {
    const ids = [
      'ex_bench_press', 'ex_incline_db_press', 'ex_lat_pulldown',
      'ex_pullups', 'ex_barbell_row', 'ex_cable_row', 'ex_ohp',
      'ex_lateral_raises', 'ex_rdl', 'ex_squat', 'ex_leg_press',
      'ex_leg_extension', 'ex_leg_curl', 'ex_hip_thrust',
      'ex_calf_raise', 'ex_crunch', 'ex_barbell_curl', 'ex_hammer_curl',
      'ex_tricep_pushdown', 'ex_face_pull',
      'exv2_flat_db_press', 'exv2_incline_barbell_press',
      'exv2_nordic_curl', 'exv2_cable_crunch', 'exv2_pallof_press',
      'exv2_sumo_deadlift',
    ];
    for (final id in ids) {
      final exercise = presetExercises.firstWhere((e) => e.id == id);
      final guide = ExerciseDemonstrationLibrary.guideFor(exercise);
      expect(guide, isNotNull, reason: id);
      expect(guide!.setup.trim(), isNotEmpty, reason: id);
      expect(guide.movement.trim(), isNotEmpty, reason: id);
      expect(guide.safety.trim(), isNotEmpty, reason: id);
    }
    final bench = ExerciseDemonstrationLibrary.guideFor(
      presetExercises.firstWhere((e) => e.id == 'ex_bench_press'),
    )!;
    final squat = ExerciseDemonstrationLibrary.guideFor(
      presetExercises.firstWhere((e) => e.id == 'ex_squat'),
    )!;
    expect(bench.movement, isNot(squat.movement));
  });

  test('all 229 presets preserve guides and have no fake Lottie assets', () {
    expect(presetExercises, hasLength(229));
    expect(ExerciseDemonstrationLibrary.approvedMedia, isEmpty);
    for (final exercise in presetExercises) {
      expect(ExerciseDemonstrationLibrary.guideFor(exercise), isNotNull,
          reason: exercise.id);
      expect(ExerciseDemonstrationLibrary.mediaFor(exercise), isNull);
      expect(exercise.media, isEmpty);
    }
  });

  test('media contract accepts Lottie and posters, never GIF', () {
    expect(ExerciseMediaFormat.values.map((format) => format.name),
        containsAll(['lottie', 'poster']));
    expect(ExerciseMediaFormat.values.any((format) => format.name == 'gif'),
        isFalse);
    expect(ExerciseDemonstrationLibrary.approvedMedia, isEmpty);
  });

  test('custom exercise keeps its author instructions and no invented guide', () {
    final custom = Exercise(
      id: 'custom_history_1', name: 'Ejercicio personal',
      muscleGroup: 'Hombros',
      instructions: 'Texto personal intacto',
      media: 'https://unknown.example/foo.gif',
    );
    expect(ExerciseDemonstrationLibrary.guideFor(custom), isNull);
    expect(ExerciseDemonstrationLibrary.mediaFor(custom), isNull);
    expect(custom.instructions, 'Texto personal intacto');
    expect(custom.media, 'https://unknown.example/foo.gif');
  });
}
