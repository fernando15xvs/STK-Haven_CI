import 'package:core/domain/models/program_adaptation.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/application/program_week_plan.dart';

/// Deterministic, pure Dart exception engine. Commands return a new program;
/// the caller persists it before the UI acknowledges success.
class ProgramAdaptationPolicy {
  static DateTime day(DateTime now) {
    final local = now.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static bool _pending(PlanOccurrence o) => !o.archived && o.status == PlanOccurrenceStatus.pending;

  static TrainingProgram prepare(TrainingProgram program, Iterable<Routine> routines, DateTime now) {
    final week = TrainingProgram.localWeekStart(now);
    final old = program.adaptation;
    if (old != null && !week.isAfter(old.week)) return program;
    final rolling = program.scheduleMode != ProgramScheduleMode.fixed && !program.repeatsWeekly;
    final target = ProgramScheduleProjector.effectiveTargetSessionsPerWeek(program, routines);
    var serial = old?.nextSerial ?? 0;
    var cursor = program.normalizedNextRotationIndex;
    final records = <PlanOccurrence>[];
    final current = <PlanOccurrence>[];
    PlanOccurrence make(String id, {DateTime? date, ProgramCompletion? completion}) =>
      PlanOccurrence(id: '${program.id}:occ:${serial++}', week: week,
        routineId: id, date: date,
        status: completion == null ? PlanOccurrenceStatus.pending : PlanOccurrenceStatus.completed,
        workoutId: completion?.workoutSessionId);

    if (old == null) {
      final base = ProgramWeekPlan.calculateBase(program: program, routines: routines, now: now);
      for (final slot in base.slots) {
        current.add(make(slot.routineId, date: slot.date, completion: slot.completion));
        if (rolling && !slot.isCompleted && program.routineIds.isNotEmpty) {
          cursor = (cursor + 1) % program.routineIds.length;
        }
      }
    } else {
      // Carry only unfulfilled rolling positions, bounded by the target.
      // Weekly/fixed plans expire missed positions instead of creating debt.
      final reserved = old.bindings.values.toSet();
      for (final o in old.occurrences) {
        if (_pending(o) && o.week == old.week && rolling &&
            current.length < target && program.routineIds.contains(o.routineId)) {
          current.add(o.copyWith(week: week, clearDate: true));
        } else if (_pending(o) && !reserved.contains(o.id)) {
          records.add(o.copyWith(status: PlanOccurrenceStatus.expired));
        } else {
          records.add(o);
        }
      }
      if (program.scheduleMode == ProgramScheduleMode.fixed) {
        for (final slot in ProgramScheduleProjector.projectWeek(program: program,
            routines: routines, weekStart: week)) {
          current.add(make(slot.routineId, date: slot.date));
        }
      } else if (program.repeatsWeekly) {
        for (final id in program.weeklySequence) {
          current.add(make(id));
        }
      } else if (program.routineIds.isNotEmpty) {
        while (current.length < target) {
          current.add(make(program.routineIds[cursor]));
          cursor = (cursor + 1) % program.routineIds.length;
        }
      }
    }
    // Rebuild the dated opportunity labels after rollover for continuous plans.
    if (old != null && program.scheduleMode == ProgramScheduleMode.continuous) {
      final dates = ProgramScheduleProjector.projectWeek(program: program, routines: routines,
        weekStart: week).map((o) => o.date).toList();
      for (var i = 0; i < current.length && i < dates.length; i++) {
        if (current[i].notBefore == null) current[i] = current[i].copyWith(date: dates[i]);
      }
    }
    final adaptation = (old ?? ProgramAdaptation(week: week)).copyWith(
      week: week, occurrences: [...records, ...current], nextSerial: serial);
    return program.copyWith(adaptation: adaptation, nextRotationIndex: cursor);
  }

  static List<PlanOccurrence> current(TrainingProgram program) =>
    program.adaptation!.occurrences.where((o) => !o.archived && o.week == program.adaptation!.week).toList();

  /// Replace only future, unbound occurrences when the template changes.
  /// Retain pauses, history, old bindings and archived identities.
  static TrainingProgram rebase(TrainingProgram existing, TrainingProgram edited,
      Iterable<Routine> routines, DateTime now) {
    final old = existing.adaptation!;
    final bound = old.bindings.values.toSet();
    if (old.occurrences.any((o) => _pending(o) && bound.contains(o.id))) {
      throw StateError('Finaliza o descarta el entrenamiento vinculado antes de editar.');
    }
    final next = prepare(edited.copyWith(clearAdaptation: true), routines, now);
    final fresh = next.adaptation!;
    var serial = old.nextSerial;
    final rows = <PlanOccurrence>[
      for (final o in old.occurrences)
        o.copyWith(archived: true, status: _pending(o) ? PlanOccurrenceStatus.expired : o.status),
      for (final o in fresh.occurrences)
        PlanOccurrence(id: '${edited.id}:occ:${serial++}', week: o.week,
          routineId: o.routineId, date: o.date, notBefore: o.notBefore,
          status: o.status, workoutId: o.workoutId),
    ];
    return next.copyWith(adaptation: old.copyWith(week: fresh.week,
      occurrences: rows, nextSerial: serial));
  }

  static DateTime? availableDate(TrainingProgram program, Iterable<Routine> routines,
      PlanOccurrence occurrence, DateTime now) {
    var candidate = day(now);
    final fixed = program.scheduleMode == ProgramScheduleMode.fixed;
    final flexible = program.scheduleMode == ProgramScheduleMode.flexible;
    final lower = occurrence.notBefore ?? (fixed ? occurrence.date : null);
    if (lower != null && lower.isAfter(candidate)) candidate = day(lower);
    if (fixed && occurrence.notBefore == null && occurrence.date != null &&
        occurrence.date!.isBefore(day(now))) return null;
    final pauses = program.adaptation!.pauses;
    for (var i = 0; i < 370; i++) {
      final relevant = pauses.where((p) => (p.routineId == null ||
          p.routineId == occurrence.routineId) && p.activeAt(candidate == day(now) ? now : candidate));
      if (relevant.any((p) => p.endsAt == null)) return null;
      // A user-confirmed recovery can explicitly use a normally free day.
      final explicitDay = occurrence.notBefore != null && candidate == day(occurrence.notBefore!);
      if (relevant.isEmpty && (flexible || fixed || explicitDay ||
          ProgramScheduleProjector.isTrainingDay(program, routines, candidate))) {
        if (!program.repeatsWeekly || TrainingProgram.localWeekStart(candidate) == occurrence.week) {
          return candidate;
        }
        return null;
      }
      candidate = TrainingProgram.shiftCalendarDays(candidate, 1);
    }
    return null;
  }

  /// Forecast the next week assuming the remaining available positions are
  /// completed. Real rollover still retains genuinely uncompleted positions.
  /// A paused or explicitly deferred position is not silently forecast as done.
  static List<String> forecastNextWeek(TrainingProgram p, Iterable<Routine> routines,
      DateTime now) {
    final state = p.adaptation!;
    final nextMonday = TrainingProgram.shiftCalendarDays(state.week, 7);
    final rolling = p.scheduleMode != ProgramScheduleMode.fixed && !p.repeatsWeekly;
    if (!rolling) {
      return List.unmodifiable(current(prepare(p, routines, nextMonday)).map((o) => o.routineId));
    }
    final target = ProgramScheduleProjector.effectiveTargetSessionsPerWeek(p, routines);
    final ids = p.routineIds;
    if (ids.isEmpty) return const [];
    final retained = <String>[];
    for (final o in current(p).where(_pending)) {
      if (!ids.contains(o.routineId)) continue;
      final available = availableDate(p, routines, o, now);
      if (available == null || !available.isBefore(nextMonday)) {
        retained.add(o.routineId);
      }
    }
    return List.unmodifiable([
      ...retained.take(target),
      for (var i = 0; i < target - retained.length; i++)
        ids[(p.normalizedNextRotationIndex + i) % ids.length],
    ]);
  }

  static PlanOccurrence? nextOccurrence(TrainingProgram program, Iterable<Routine> routines, DateTime now) {
    if (program.adaptation!.programPausedAt(now)) return null;
    final candidates = current(program).where((o) => _pending(o) &&
      program.routineIds.contains(o.routineId) &&
      !program.adaptation!.routinePausedAt(o.routineId, now) &&
      !program.adaptation!.bindings.containsValue(o.id)).toList();
    PlanOccurrence? result;
    DateTime? earliest;
    for (final occurrence in candidates) {
      final date = availableDate(program, routines, occurrence, now);
      if (date == null) continue;
      if (earliest == null || date.isBefore(earliest)) {
        earliest = date;
        result = occurrence;
      }
    }
    return result;
  }

  static TrainingProgram _replace(TrainingProgram p, List<PlanOccurrence> rows) =>
    p.copyWith(adaptation: p.adaptation!.copyWith(occurrences: rows));

  static int _index(TrainingProgram p, String slotId) {
    final i = p.adaptation!.occurrences.indexWhere((o) => o.id == slotId &&
        o.week == p.adaptation!.week && _pending(o));
    if (i < 0) throw StateError('La sesión ya no está pendiente.');
    if (p.adaptation!.bindings.containsValue(slotId)) {
      throw StateError('La sesión ya está vinculada a un entrenamiento.');
    }
    return i;
  }

  static TrainingProgram postpone(TrainingProgram program, Iterable<Routine> routines,
      String slotId, DateTime now, DateTime until) {
    final p = prepare(program, routines, now);
    final rows = p.adaptation!.occurrences.toList();
    final index = _index(p, slotId);
    if (day(until).isBefore(day(now))) throw ArgumentError('Fecha anterior a hoy.');
    final date = day(until);
    if ((p.repeatsWeekly || p.scheduleMode == ProgramScheduleMode.fixed) &&
        TrainingProgram.localWeekStart(date) != p.adaptation!.week) {
      throw ArgumentError('Recupera esta sesión dentro de la semana actual.');
    }
    final slot = rows.removeAt(index).copyWith(notBefore: date,
      date: p.scheduleMode == ProgramScheduleMode.flexible ? null : date);
    rows.add(slot);
    return _replace(p, rows);
  }

  /// Swap two pending positions, including dates; no historical row changes.
  static TrainingProgram exchange(TrainingProgram program, Iterable<Routine> routines,
      String first, String second, DateTime now) {
    final p = prepare(program, routines, now);
    final rows = p.adaptation!.occurrences.toList();
    final a = _index(p, first), b = _index(p, second);
    final x = rows[a], y = rows[b];
    rows[a] = y.copyWith(date: x.date, clearDate: x.date == null,
        notBefore: x.notBefore, clearNotBefore: x.notBefore == null);
    rows[b] = x.copyWith(date: y.date, clearDate: y.date == null,
        notBefore: y.notBefore, clearNotBefore: y.notBefore == null);
    return _replace(p, rows);
  }

  static TrainingProgram omit(TrainingProgram program, Iterable<Routine> routines,
      String slotId, DateTime now) {
    final p = prepare(program, routines, now);
    final rows = p.adaptation!.occurrences.toList();
    final index = _index(p, slotId);
    rows[index] = rows[index].copyWith(status: PlanOccurrenceStatus.omitted);
    return _replace(p, rows);
  }

  /// Recover a missed fixed slot today, optionally displacing today's slot.
  /// The original weekly template is not edited.
  static TrainingProgram recover(TrainingProgram program, Iterable<Routine> routines,
      String slotId, DateTime now, {bool shiftFollowing = false}) {
    final p = prepare(program, routines, now);
    final rows = p.adaptation!.occurrences.toList();
    final index = _index(p, slotId);
    final today = day(now);
    final recovered = rows.removeAt(index).copyWith(
      notBefore: today, date: p.scheduleMode == ProgramScheduleMode.flexible ? null : today);
    if (shiftFollowing && p.scheduleMode != ProgramScheduleMode.flexible) {
      var nextDay = today;
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row.week != p.adaptation!.week || !_pending(row) ||
            p.adaptation!.bindings.containsValue(row.id) ||
            (row.date != null && row.date!.isBefore(today))) continue;
        do {
          nextDay = TrainingProgram.shiftCalendarDays(nextDay, 1);
        } while (p.scheduleMode == ProgramScheduleMode.continuous &&
            !ProgramScheduleProjector.isTrainingDay(p, routines, nextDay));
        rows[i] = row.copyWith(date: nextDay, notBefore: nextDay);
      }
    }
    rows.insert(0, recovered);
    return _replace(p, rows);
  }

  /// A previous week's expired/omitted position may be explicitly recovered.
  /// Replace one unbound pending position in the current week; the displaced
  /// occurrence is omitted, never falsely completed. No unbounded debt.
  static TrainingProgram recoverPrevious(TrainingProgram program, Iterable<Routine> routines,
      String previousId, String replaceId, DateTime now) {
    final p = prepare(program, routines, now);
    final rows = p.adaptation!.occurrences.toList();
    final old = rows.indexWhere((o) => o.id == previousId && !o.archived &&
        o.week.isBefore(p.adaptation!.week) &&
        (o.status == PlanOccurrenceStatus.expired || o.status == PlanOccurrenceStatus.omitted));
    if (old < 0 || !p.routineIds.contains(rows[old].routineId)) {
      throw StateError('La sesión anterior ya no se puede recuperar.');
    }
    final index = _index(p, replaceId);
    final replaced = rows[index];
    final restored = rows[old].copyWith(week: p.adaptation!.week,
        status: PlanOccurrenceStatus.pending, date: replaced.date,
        clearDate: replaced.date == null, notBefore: day(now));
    rows[index] = replaced.copyWith(status: PlanOccurrenceStatus.omitted);
    // Retain unique occurrence identity; move rather than clone.
    rows.removeAt(old);
    final at = rows.indexWhere((o) => o.id == replaceId);
    rows.insert(at, restored);
    return _replace(p, rows);
  }

  static TrainingProgram pause(TrainingProgram program, Iterable<Routine> routines,
      DateTime now, {Set<String>? routineIds, DateTime? until}) {
    if (until != null && !until.isAfter(now)) throw ArgumentError('La pausa debe terminar después de ahora.');
    if (routineIds != null && (routineIds.isEmpty || !routineIds.every(program.routineIds.contains))) {
      throw ArgumentError('Selecciona rutinas del programa.');
    }
    final p = prepare(program, routines, now);
    final state = p.adaptation!;
    var serial = state.nextSerial;
    final targets = routineIds == null ? <String?>[null] : routineIds.cast<String?>();
    return p.copyWith(adaptation: state.copyWith(nextSerial: serial + targets.length,
      pauses: [...state.pauses, for (final id in targets)
        PlanPause(id: '${p.id}:pause:${serial++}', startedAt: now, endsAt: until, routineId: id)]));
  }

  static TrainingProgram resume(TrainingProgram program, DateTime now, {Set<String>? routineIds}) {
    final state = program.adaptation;
    if (state == null) return program;
    return program.copyWith(adaptation: state.copyWith(pauses: [
      for (final pause in state.pauses)
        if (pause.activeAt(now) && (routineIds == null ? pause.routineId == null :
            routineIds.contains(pause.routineId))) pause.endAt(now) else pause,
    ]));
  }

  /// Cancel an unexecuted change by resetting the current pending dates/order
  /// is intentionally not implicit: callers can reverse an exchange or move
  /// a pending slot. Omitted slots can be restored while the week is current.
  static TrainingProgram restoreOmitted(TrainingProgram program, Iterable<Routine> routines,
      String slotId, DateTime now) {
    final p = prepare(program, routines, now);
    final rows = p.adaptation!.occurrences.toList();
    final i = rows.indexWhere((o) => o.id == slotId && o.week == p.adaptation!.week && !o.archived &&
        o.status == PlanOccurrenceStatus.omitted);
    if (i < 0) throw StateError('La sesión no se puede recuperar.');
    rows[i] = rows[i].copyWith(status: PlanOccurrenceStatus.pending);
    return _replace(p, rows);
  }

  static TrainingProgram bind(TrainingProgram program, Iterable<Routine> routines,
      String workoutId, String routineId, DateTime now, {String? slotId, bool independent = false}) {
    final p = prepare(program, routines, now);
    final state = p.adaptation!;
    if (state.bindings.containsKey(workoutId)) return p;
    String binding = '';
    if (!independent) {
      final target = ProgramScheduleProjector.effectiveTargetSessionsPerWeek(p, routines);
      final completed = p.completionsInLocalWeek(now).where((c) => !c.completedAt.isAfter(now)).length;
      if (target <= 0 || completed >= target) {
        throw StateError('Objetivo semanal cumplido. Entrena de forma independiente.');
      }
      final selected = slotId == null ? nextOccurrence(p, routines, now) :
          state.occurrences[_index(p, slotId)];
      if (selected == null || selected.routineId != routineId ||
          state.routinePausedAt(routineId, now) ||
          state.bindings.containsValue(selected.id)) {
        throw StateError('Adapta la planificación o inicia una sesión independiente.');
      }
      final date = availableDate(p, routines, selected, now);
      if (date == null || date.isAfter(day(now))) {
        throw StateError('La sesión todavía no está disponible.');
      }
      binding = selected.id;
    }
    return p.copyWith(adaptation: state.copyWith(bindings: {...state.bindings, workoutId: binding}));
  }

  static TrainingProgram reconcile(TrainingProgram program, Iterable<WorkoutSession> history) {
    final state = program.adaptation!;
    final rows = state.occurrences.toList();
    final completions = program.completions.toList();
    final seen = completions.map((c) => c.workoutSessionId).toSet();
    for (final session in history) {
      final binding = state.bindings[session.id];
      if (binding == null || binding.isEmpty || seen.contains(session.id)) continue;
      final sets = session.exercises.expand((e) => e.sets)
          .where((s) => s.setType == WorkoutSetType.working).toList();
      if (sets.isEmpty || !sets.every((s) => s.completed)) continue;
      final i = rows.indexWhere((o) => o.id == binding && _pending(o) && o.routineId == session.routineId);
      if (i < 0) continue;
      final row = rows[i];
      rows[i] = row.copyWith(status: PlanOccurrenceStatus.completed, workoutId: session.id);
      completions.add(ProgramCompletion(workoutSessionId: session.id,
        routineId: row.routineId, completedAt: session.finishedAt,
        rotationIndex: i, programWeek: program.weekAt(session.finishedAt)));
      seen.add(session.id);
    }
    if (completions.length == program.completions.length) return program;
    return program.copyWith(completions: List.unmodifiable(completions),
      adaptation: state.copyWith(occurrences: rows));
  }
}
