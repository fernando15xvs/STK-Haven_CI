import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:core/features/recovery/application/sleep_diary.dart';

/// Conservative decision support, not physiological measurement or diagnosis.
class RecoverySessionAdvice {
  const RecoverySessionAdvice({
    required this.reasons, required this.affectedIds, required this.globalCaution,
    required this.pain, required this.reducedSets,
  });
  final List<String> reasons;
  final Set<String> affectedIds;
  final bool globalCaution;
  final bool pain;
  final Map<int,int> reducedSets;
  bool get needsReview => reasons.isNotEmpty;
  int? get suggestedRir => needsReview && !pain ? 3 : null;
  bool cautions(String id) => pain || globalCaution || affectedIds.contains(id);

  Routine adapt(Routine routine) => routine.copyWith(exercises: [
    for (var i = 0; i < routine.exercises.length; i++)
      if (reducedSets.containsKey(i))
        routine.exercises[i].copyWith(targetSets: reducedSets[i])
      else routine.exercises[i],
  ]);
}

class MuscleWorkEvidence {
  const MuscleWorkEvidence(this.area, this.primarySets, this.secondarySets, this.lastTrained, this.highEffortSets);
  final String area;
  final int primarySets, secondarySets, highEffortSets;
  final DateTime? lastTrained;
}

class AdaptiveRecovery {
  static const areas = ['Pecho','Espalda','Hombros','Brazos','Piernas','Core'];

  static int? consentedAge(UserExperienceProfile? profile, DateTime now) =>
      profile == null || (profile.eligibilityBirthDate == null &&
        !profile.optionalDemographicsConsented) ? null : profile.ageAt(now);

  /// Observed work over seven local dates; secondary exposure is distinct
  /// from direct work and never represented as a physiological recovery score.
  static List<MuscleWorkEvidence> recentMuscleWork({
    required DateTime now, required Iterable<WorkoutSession> sessions,
    required Iterable<Exercise> exercises, required Iterable<String> selectedAreas,
  }) {
    final cutoff = DateTime(now.year,now.month,now.day-6);
    final byId = {for (final exercise in exercises) exercise.id: exercise};
    final selected = selectedAreas.toSet();
    final primary = <String,int>{}, secondary = <String,int>{}, effort = <String,int>{};
    final dates = <String,DateTime>{};
    for (final session in sessions) {
      if (session.startedAt.isBefore(cutoff) || session.startedAt.isAfter(now)) continue;
      for (final recorded in session.exercises) {
        final exercise=byId[recorded.exerciseId];
        if(exercise==null)continue;
        final sets=recorded.sets.where((s)=>s.completed && s.setType==WorkoutSetType.working).toList();
        if(sets.isEmpty)continue;
        for(final area in selected) {
          final direct=ExerciseLibraryFilter.matchesMuscle(exercise,area,includeSecondary:false);
          if(!direct&&!ExerciseLibraryFilter.matchesMuscle(exercise,area))continue;
          final map=direct?primary:secondary;
          map[area]=(map[area]??0)+sets.length;
          effort[area]=(effort[area]??0)+sets.where((s)=>s.performanceRir!=null&&s.performanceRir!<=1).length;
          if(dates[area]==null||session.startedAt.isAfter(dates[area]!))dates[area]=session.startedAt;
        }
      }
    }
    return [for(final area in selected) MuscleWorkEvidence(area,primary[area]??0,
      secondary[area]??0,dates[area],effort[area]??0)];
  }

  static RecoverySessionAdvice evaluate({
    required DateTime now,
    required Routine routine,
    required Iterable<Exercise> exercises,
    required SleepDiary sleep,
    RecoveryCheckIn? checkIn,
    int? age,
  }) {
    final current = checkIn != null &&
        SleepDiary.dayKey(checkIn.date) == SleepDiary.dayKey(now) &&
        !checkIn.updatedAt.isAfter(now) ? checkIn : null;
    final minutes = sleep.minutesFor(now);
    final goal = sleep.goalMinutes ?? SleepDiary.suggestedMinimumMinutes(age);
    final quality = sleep.qualityFor(now) ?? current?.sleep;
    final reasons = <String>[];
    var global = false;
    final pain = current?.painReported ?? false;
    if (pain) reasons.add('Dolor o lesión declarada: no fuerces la zona afectada.');
    if (minutes != null && (minutes < 360 || (goal != null && goal - minutes >= 120))) {
      reasons.add('Duración de sueño reducida respecto al descanso esperado.');
      global = true;
    }
    if (quality != null && quality <= 2) {
      reasons.add('Calidad de sueño baja.');
      global = true;
    }
    if (current != null && (current.energy <= 2 || current.stress >= 4)) {
      reasons.add('Energía baja o estrés elevado.');
      global = true;
    }
    if (current != null && current.status != RecoveryStatus.ready &&
        current.fatiguedAreas.isEmpty && !global && !pain) {
      reasons.add('La recuperación percibida aconseja prudencia.');
      global = true;
    }
    if (current != null && current.soreness >= 4 && current.fatiguedAreas.isEmpty) {
      if (!global) reasons.add('Fatiga muscular elevada sin zona específica.');
      global = true;
    }
    final byId = {for (final exercise in exercises) exercise.id: exercise};
    final affected = <String>{};
    if (current != null && current.soreness >= 3) {
      for (final target in routine.exercises) {
        final exercise = byId[target.exerciseId];
        if (exercise != null && current.fatiguedAreas.any((area) =>
            ExerciseLibraryFilter.matchesMuscle(exercise, area))) {
          affected.add(target.exerciseId);
        }
      }
      if (affected.isNotEmpty) reasons.add('Fatiga en músculos de esta rutina.');
    }
    final reduced = <int,int>{};
    // No automatic load or RIR changes. Reduce at most one working set per
    // eligible exercise and keep superset structure and at least two sets.
    if (!pain) {
      for (var i = 0; i < routine.exercises.length; i++) {
        final target = routine.exercises[i];
        if (target.phase == RoutineExercisePhase.main && !target.isInSuperset &&
            target.targetSets >= 3 && (global || affected.contains(target.exerciseId))) {
          reduced[i] = target.targetSets - 1;
        }
      }
    }
    return RecoverySessionAdvice(reasons: List.unmodifiable(reasons),
      affectedIds: Set.unmodifiable(affected), globalCaution: global,
      pain: pain, reducedSets: Map.unmodifiable(reduced));
  }

  static bool highEffort(Iterable<WorkoutSet> sets) => sets.any((s) =>
      s.completed && s.setType == WorkoutSetType.working &&
      s.performanceRir != null && s.performanceRir! <= 0);

  /// Signals to review a week, not an automatic deload prescription.
  static bool persistentFatigue(Iterable<RecoveryCheckIn> history, DateTime now) {
    final cutoff = DateTime(now.year,now.month,now.day-6);
    return history.where((e) => !e.date.isBefore(cutoff) &&
        !e.date.isAfter(now) && (e.energy <= 2 || e.soreness >= 4))
        .map((e) => SleepDiary.dayKey(e.date)).toSet().length >= 3;
  }
}
