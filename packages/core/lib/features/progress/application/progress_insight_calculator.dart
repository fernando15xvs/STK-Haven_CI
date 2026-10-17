import 'dart:math' as math;

import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:core/features/progress/application/muscle_balance_calculator.dart';

/// Observaciones basadas en reglas transparentes, no en IA generativa ni en
/// diagnósticos. Ninguna recomendación prescribe series, cargas o recuperación.
enum ProgressInsightType { consistency, exercise, muscle }

class ProgressInsight {
  final String id;
  final ProgressInsightType type;
  final String title;
  final String explanation;
  final String evidence;
  final String periodLabel;

  const ProgressInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.explanation,
    required this.evidence,
    required this.periodLabel,
  });
}

class ProgressInsightCalculator {
  const ProgressInsightCalculator._();

  static DateTime _day(DateTime date) {
    final d = date.toLocal();
    return DateTime(d.year, d.month, d.day);
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _keyDate(DateTime d) =>
      '${d.year}-${d.month}-${d.day}';

  static bool _hasWorkingSet(WorkoutSession session) =>
      session.exercises.any((exercise) =>
          exercise.sets.any((set) =>
              set.completed && set.setType == WorkoutSetType.working));

  /// Calcula hasta tres hallazgos en un orden fijo: frecuencia, ejercicio y
  /// músculo. Los ID dependen de la evidencia y del filtro (no del reloj al
  /// segundo); al cambiar los datos se puede volver a mostrar un hallazgo.
  static List<ProgressInsight> calculate({
    required List<WorkoutSession> history,
    required List<Exercise> exercises,
    required DateTime from,
    required DateTime now,
    required String periodKey,
  }) {
    if (from.isAfter(now)) return const [];
    final eligible = history.where((session) =>
        !session.finishedAt.isAfter(now) &&
        !session.finishedAt.isBefore(from) &&
        _hasWorkingSet(session)).toList(growable: false);
    if (eligible.isEmpty) return const [];

    final observations = <ProgressInsight>[];
    final today = _day(now);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final priorMonday = lastMonday.subtract(const Duration(days: 7));
    // Both Monday–Sunday ranges must fall inside the selected filter.
    final completeWeeksCovered = !from.isAfter(priorMonday);
    Set<String> daysForWeek(DateTime start, DateTime end) =>
        eligible.where((session) {
          final date = _day(session.finishedAt);
          return !date.isBefore(start) && date.isBefore(end);
        }).map((session) => _keyDate(_day(session.finishedAt))).toSet();

    final previousDays = completeWeeksCovered
        ? daysForWeek(priorMonday, lastMonday)
        : <String>{};
    final recentDays = completeWeeksCovered
        ? daysForWeek(lastMonday, thisMonday)
        : <String>{};
    final comparisonWindow =
        '${_date(priorMonday)}–${_date(thisMonday.subtract(const Duration(days: 1)))}';

    if (previousDays.length >= 2 && recentDays.isNotEmpty &&
        previousDays.length + recentDays.length >= 4) {
      final before = previousDays.length;
      final after = recentDays.length;
      observations.add(ProgressInsight(
        id: 'consistency:$periodKey:${_keyDate(lastMonday)}:$before:$after',
        type: ProgressInsightType.consistency,
        title: before == after
            ? 'Frecuencia registrada estable'
            : 'Cambio de frecuencia entre semanas',
        explanation:
            'Registraste $before días de entrenamiento en la semana anterior '
            'y $after en la más reciente. Es un registro de actividad, '
            'no una valoración de tu esfuerzo.',
        evidence: '$before → $after días con al menos una serie efectiva completada.',
        periodLabel: 'Semanas completas · $comparisonWindow',
      ));
    }

    // Build a set of real candidate IDs first, avoiding a full trend
    // calculation for every preinstalled but unused exercise in the catalogue.
    final ids = <String, Set<String>>{};
    for (final session in eligible) {
      for (final exercise in session.exercises) {
        if (!exercise.sets.any((s) =>
            s.completed && s.setType == WorkoutSetType.working)) continue;
        ids.putIfAbsent(exercise.exerciseId, () => <String>{}).add(session.id);
      }
    }
    final catalogue = {for (final e in exercises) e.id: e};
    ProgressInsight? strongestExercise;
    var bestScore = -1.0;
    final historyInPeriod = eligible;
    final matchingIds = ids.entries
        .where((item) => item.value.length >= 3)
        .map((item) => item.key)
        .toList()..sort();
    for (final exerciseId in matchingIds) {
      final trend = ExerciseProgressCalculator.calculateTrend(
        historyInPeriod, exerciseId, maxChartPoints: 12,
      );
      final valid = trend.sessions.where((s) =>
          s.estimated1RM > 0 && s.estimated1RM.isFinite).toList();
      if (valid.length < 3) continue;
      final lastThree = valid.sublist(valid.length - 3);
      final first = lastThree.first;
      final middle = lastThree[1];
      final last = lastThree.last;
      if (last.date.difference(first.date).inDays < 14) continue;
      // Repeated sessions on the same day don't make independent evidence.
      final dates = lastThree.map((e) => _keyDate(_day(e.date))).toSet();
      if (dates.length != 3) continue;
      final percent = (last.estimated1RM - first.estimated1RM) /
          first.estimated1RM * 100;
      final high = lastThree.map((s) => s.estimated1RM).reduce(math.max);
      final low = lastThree.map((s) => s.estimated1RM).reduce(math.min);
      final rangePercent = (high - low) / high * 100;
      final stable = rangePercent <= 2;
      // Growth requires a consistent direction without a large intermediate
      // setback, not a single unusually high final observation.
      final growth = percent >= 5 &&
          middle.estimated1RM >= first.estimated1RM * 0.95 &&
          last.estimated1RM >= middle.estimated1RM * 0.95;
      if (!stable && !growth) continue;
      final score = growth ? percent : 2.0;
      if (score <= bestScore) continue;
      final name = catalogue[exerciseId]?.name ??
          eligible.expand((s) => s.exercises)
              .firstWhere((e) => e.exerciseId == exerciseId)
              .exerciseNameSnapshot;
      final title = growth
          ? 'Mejora estimada en $name'
          : 'Rendimiento estimado estable en $name';
      final explanation = growth
          ? 'El 1RM estimado fue mayor entre la primera y la última de '
            'tres sesiones comparadas. Es una estimación, no una medición '
            'directa de fuerza ni de masa muscular.'
          : 'Las tres estimaciones de 1RM quedaron dentro de un rango '
            'del 2 %. Esto no prueba estancamiento ni exige modificar tu rutina.';
      strongestExercise = ProgressInsight(
        id: 'exercise:$periodKey:$exerciseId:${first.sessionId}:'
            '${last.sessionId}:${first.estimated1RM.toStringAsFixed(1)}:'
            '${middle.estimated1RM.toStringAsFixed(1)}:'
            '${last.estimated1RM.toStringAsFixed(1)}',
        type: ProgressInsightType.exercise,
        title: title,
        explanation: explanation,
        evidence: growth
            ? '1RM estimado: +${percent.toStringAsFixed(1)} % entre '
                '${_date(first.date)} y ${_date(last.date)} (3 sesiones).'
            : 'Variación máxima: ${rangePercent.toStringAsFixed(1)} % '
                'entre ${_date(first.date)} y ${_date(last.date)} (3 sesiones).',
        periodLabel: 'Dentro del período seleccionado · $periodKey',
      );
      bestScore = score;
    }
    if (strongestExercise != null) observations.add(strongestExercise);

    // This compares direct primary-muscle work only (not indirect estimates).
    // To avoid comparing an empty week with a busy week, both weeks must have
    // registered working-set activity in at least two distinct days.
    if (completeWeeksCovered && previousDays.length >= 2 &&
        recentDays.length >= 2) {
      final report = MuscleBalanceCalculator.calculate(
        history: eligible,
        exercises: exercises,
        from: from,
        now: now,
      );
      MuscleBalanceItem? selected;
      var highestChange = 0;
      for (final item in report.groups) {
        final before = item.previousFullWeekSets;
        final after = item.recentFullWeekSets;
        if (before < 4 || after * 2 > before) continue;
        final change = before - after;
        if (change > highestChange) {
          highestChange = change;
          selected = item;
        }
      }
      if (selected != null) {
        final before = selected.previousFullWeekSets;
        final after = selected.recentFullWeekSets;
        observations.add(ProgressInsight(
          id: 'muscle:$periodKey:${selected.name.toLowerCase()}:'
              '${_keyDate(lastMonday)}:$before:$after',
          type: ProgressInsightType.muscle,
          title: 'Cambió el reparto de trabajo de ${selected.name}',
          explanation: 'En ${selected.name} se registraron menos series '
              'directas en la última semana completa. Puede deberse a la '
              'rotación de tu rutina u otros cambios planificados.',
          evidence: '$before → $after series efectivas directas. '
              'No incluye trabajo secundario estimado.',
          periodLabel: 'Semanas completas · $comparisonWindow',
        ));
      }
    }

    return List.unmodifiable(observations);
  }
}
