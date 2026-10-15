import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/domain/models/verse.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/faith/data/contextual_passage_catalog.dart';
import 'package:core/features/faith/presentation/widgets/workout_closing_reflection_card.dart';
import 'package:core/features/workout/application/workout_summary_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession session(String id, DateTime start, {bool completed = true}) {
  return WorkoutSession(
    id: id,
    routineNameSnapshot: 'Entreno',
    startedAt: start,
    finishedAt: start.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: [
      WorkoutExercise(
        exerciseId: 'exercise-1',
        exerciseNameSnapshot: 'Ejercicio',
        muscleGroupSnapshot: 'Espalda',
        sets: [
          WorkoutSet(weight: 10, reps: 10, completed: completed),
        ],
      ),
    ],
  );
}

void main() {
  test('personal identity is optional, local-model roundtrip is safe', () {
    const blank = UserExperienceProfile();
    expect(blank.preferredName, 'Tu perfil');
    expect(blank.avatarEmoji, isNull);
    expect(blank.showWorkoutReflections, isTrue);

    final edited = blank.copyWith(
      displayName: '  Ada  ',
      avatarEmoji: '🌱',
      showWorkoutReflections: false,
    );
    final restored = UserExperienceProfile.fromJson(edited.toJson());
    expect(restored.preferredName, 'Ada');
    expect(restored.avatarEmoji, '🌱');
    expect(restored.showWorkoutReflections, isFalse);
    expect(restored.copyWith(clearAvatar: true).avatarEmoji, isNull);

    final withPhoto = restored.copyWith(
      avatarPhotoBase64: 'AQID',
      clearAvatar: true,
    );
    final photoRoundTrip = UserExperienceProfile.fromJson(withPhoto.toJson());
    expect(photoRoundTrip.avatarPhotoBase64, 'AQID');
    expect(photoRoundTrip.avatarEmoji, isNull);
    expect(photoRoundTrip.copyWith(clearAvatarPhoto: true).avatarPhotoBase64, isNull);
    expect(UserExperienceProfile.fromJson(const {}).avatarPhotoBase64, isNull);
  });

  test('original single-verse favorite identifiers remain compatible', () {
    const single = Verse(book: 'Mateo', chapter: 1, verse: 1, text: 'texto');
    const passage = Verse(
      book: 'Mateo', chapter: 11, verse: 28, endVerse: 30, text: 'texto',
      explanation: 'Explicación no bíblica.',
    );
    expect(single.id, 'Mateo-1-1');
    expect(passage.reference, 'Mateo 11:28-30');
    expect(passage.id, 'Mateo-11-28-30');
  });

  test('daily passage is deterministic for the calendar day', () {
    final morning = ContextualPassageCatalog.forDay(DateTime(2026, 10, 15, 7));
    final evening = ContextualPassageCatalog.forDay(DateTime(2026, 10, 15, 23));
    expect(morning.key, evening.key);
    expect(morning.end - morning.start + 1, inInclusiveRange(2, 5));
    for (final entry in ContextualPassageCatalog.passages) {
      expect(entry.end - entry.start + 1, inInclusiveRange(2, 5));
      expect(entry.meaning, isNotEmpty);
      expect(entry.question, isNotEmpty);
    }
  });

  test('completion, return and partial completion use distinct moments', () {
    final now = DateTime(2026, 10, 15, 18);
    final current = session('current', now);
    final summary = WorkoutSummarySnapshot.fromSession(current);
    expect(classifyClosingMoment(summary, current, []), ClosingMoment.completed);

    final old = session('old', now.subtract(const Duration(days: 18)));
    expect(classifyClosingMoment(summary, current, [old]), ClosingMoment.returning);

    final incomplete = session('partial', now, completed: false);
    expect(
      classifyClosingMoment(WorkoutSummarySnapshot.fromSession(incomplete), incomplete, [old]),
      ClosingMoment.incomplete,
    );
  });

  test('closing message rotation has several themes and avoids verbatim Scripture in editorial notes', () {
    for (final theme in ['completed', 'return', 'incomplete']) {
      final pool = ContextualPassageCatalog.forWorkoutTheme(theme);
      expect(pool.length, greaterThanOrEqualTo(3));
      expect(pool.map((item) => item.key).toSet().length, pool.length);
      expect(pool.every((item) => item.closingThought.isNotEmpty), isTrue);
    }
  });
}
