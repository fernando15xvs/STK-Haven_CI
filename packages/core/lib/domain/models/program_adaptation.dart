/// Persisted exceptions belong to the plan, not to global routines or history.
enum PlanOccurrenceStatus { pending, completed, omitted, expired }

class PlanOccurrence {
  const PlanOccurrence({required this.id, required this.week, required this.routineId,
    this.date, this.notBefore, this.status = PlanOccurrenceStatus.pending,
    this.workoutId, this.archived = false});
  final String id;
  final DateTime week;
  final String routineId;
  final DateTime? date;
  final DateTime? notBefore;
  final PlanOccurrenceStatus status;
  final String? workoutId;
  final bool archived;

  PlanOccurrence copyWith({DateTime? week, DateTime? date, bool clearDate = false,
      DateTime? notBefore, bool clearNotBefore = false,
      PlanOccurrenceStatus? status, String? workoutId, bool? archived}) => PlanOccurrence(
    id: id, week: week ?? this.week, routineId: routineId,
    date: clearDate ? null : date ?? this.date,
    notBefore: clearNotBefore ? null : notBefore ?? this.notBefore,
    status: status ?? this.status, workoutId: workoutId ?? this.workoutId,
    archived: archived ?? this.archived);
  Map<String, dynamic> toJson() => {
    'id': id, 'week': week.toIso8601String(), 'routineId': routineId,
    if (date != null) 'date': date!.toIso8601String(),
    if (notBefore != null) 'notBefore': notBefore!.toIso8601String(),
    'status': status.name, if (workoutId != null) 'workoutId': workoutId,
    if (archived) 'archived': true,
  };
  factory PlanOccurrence.fromJson(Map<String, dynamic> json) => PlanOccurrence(
    id: json['id'] as String, week: DateTime.parse(json['week'] as String),
    routineId: json['routineId'] as String,
    date: DateTime.tryParse(json['date']?.toString() ?? ''),
    notBefore: DateTime.tryParse(json['notBefore']?.toString() ?? ''),
    status: PlanOccurrenceStatus.values.firstWhere((s) => s.name == json['status'],
        orElse: () => PlanOccurrenceStatus.pending), workoutId: json['workoutId'] as String?,
    archived: json['archived'] == true);
}

class PlanPause {
  const PlanPause({required this.id, required this.startedAt, this.endsAt, this.routineId});
  final String id;
  final DateTime startedAt;
  final DateTime? endsAt;
  /// Null pauses the whole program.
  final String? routineId;
  bool activeAt(DateTime now) => !now.isBefore(startedAt) &&
      (endsAt == null || now.isBefore(endsAt!));
  PlanPause endAt(DateTime now) => PlanPause(id: id, startedAt: startedAt,
      endsAt: now, routineId: routineId);
  Map<String, dynamic> toJson() => {'id': id, 'startedAt': startedAt.toIso8601String(),
    if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
    if (routineId != null) 'routineId': routineId};
  factory PlanPause.fromJson(Map<String, dynamic> json) => PlanPause(
    id: json['id'] as String, startedAt: DateTime.parse(json['startedAt'] as String),
    endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? ''),
    routineId: json['routineId'] as String?);
}

class ProgramAdaptation {
  const ProgramAdaptation({required this.week, this.occurrences = const [],
    this.pauses = const [], this.bindings = const {}, this.nextSerial = 0,
    this.nextUnallocatedRotationIndex, this.unavailableDays = const []});
  final DateTime week;
  final List<PlanOccurrence> occurrences;
  final List<PlanPause> pauses;
  /// Workout ID -> occurrence ID; empty string explicitly means independent.
  /// A persisted binding survives draft restart and avoids guessing by routine.
  final Map<String, String> bindings;
  final int nextSerial;
  /// Allocation cursor; null denotes the legacy representation.
  final int? nextUnallocatedRotationIndex;
  /// Civil dates the user explicitly cannot train; never consumes a slot.
  final List<DateTime> unavailableDays;

  bool programPausedAt(DateTime now) => pauses.any((p) => p.routineId == null && p.activeAt(now));
  bool routinePausedAt(String id, DateTime now) => pauses.any((p) =>
      (p.routineId == null || p.routineId == id) && p.activeAt(now));

  Duration pausedDuration(DateTime from, DateTime until) {
    if (!until.isAfter(from)) return Duration.zero;
    final ranges = <(DateTime, DateTime)>[];
    for (final pause in pauses.where((p) => p.routineId == null)) {
      final a = pause.startedAt.isAfter(from) ? pause.startedAt : from;
      final end = pause.endsAt ?? until;
      final b = end.isBefore(until) ? end : until;
      if (b.isAfter(a)) ranges.add((a,b));
    }
    ranges.sort((a,b) => a.$1.compareTo(b.$1));
    var total = Duration.zero;
    var cursor = from;
    for (final range in ranges) {
      final a = range.$1.isAfter(cursor) ? range.$1 : cursor;
      if (range.$2.isAfter(a)) total += range.$2.difference(a);
      if (range.$2.isAfter(cursor)) cursor = range.$2;
    }
    return total;
  }

  ProgramAdaptation copyWith({DateTime? week, List<PlanOccurrence>? occurrences,
      List<PlanPause>? pauses, Map<String,String>? bindings, int? nextSerial,
       int? nextUnallocatedRotationIndex, List<DateTime>? unavailableDays}) =>
    ProgramAdaptation(week: week ?? this.week,
      occurrences: List.unmodifiable(occurrences ?? this.occurrences),
      pauses: List.unmodifiable(pauses ?? this.pauses),
      bindings: Map.unmodifiable(bindings ?? this.bindings),
      nextSerial: nextSerial ?? this.nextSerial,
       nextUnallocatedRotationIndex: nextUnallocatedRotationIndex ?? this.nextUnallocatedRotationIndex,
       unavailableDays: List.unmodifiable(unavailableDays ?? this.unavailableDays));
  Map<String,dynamic> toJson() => {'week': week.toIso8601String(),
    'occurrences': occurrences.map((o) => o.toJson()).toList(),
    'pauses': pauses.map((p) => p.toJson()).toList(),
    'bindings': bindings, 'nextSerial': nextSerial,
    if (nextUnallocatedRotationIndex != null) 'nextUnallocatedRotationIndex': nextUnallocatedRotationIndex,
    if (unavailableDays.isNotEmpty) 'unavailableDays': unavailableDays.map((d) => d.toIso8601String()).toList()};
  factory ProgramAdaptation.fromJson(Map<String,dynamic> json) => ProgramAdaptation(
    week: DateTime.parse(json['week'] as String),
    occurrences: (json['occurrences'] as List? ?? const []).whereType<Map>()
        .map((o) => PlanOccurrence.fromJson(Map<String,dynamic>.from(o))).toList(),
    pauses: (json['pauses'] as List? ?? const []).whereType<Map>()
        .map((p) => PlanPause.fromJson(Map<String,dynamic>.from(p))).toList(),
    bindings: Map<String,String>.from(json['bindings'] as Map? ?? const {}),
    nextSerial: (json['nextSerial'] as num?)?.toInt() ?? 0,
     nextUnallocatedRotationIndex: (json['nextUnallocatedRotationIndex'] as num?)?.toInt(),
     unavailableDays: (json['unavailableDays'] as List? ?? const []).whereType<String>()
       .map(DateTime.tryParse).whereType<DateTime>().toList());
}
