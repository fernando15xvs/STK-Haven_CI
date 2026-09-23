import 'recovery_provider.dart';

class RecoveryMetricTrend {
  final double recentAverage;
  final double previousAverage;

  const RecoveryMetricTrend({
    required this.recentAverage,
    required this.previousAverage,
  });

  double get delta => recentAverage - previousAverage;
  bool get isStable => delta.abs() < 0.25;
}

/// Immutable, presentation-ready view of recent recovery check-ins.
///
/// Entries are normalized to one value per calendar day, ordered newest first,
/// and capped to a small period so mobile and web render the same information.
class RecoveryHistorySnapshot {
  final List<RecoveryCheckIn> entries;

  const RecoveryHistorySnapshot._(this.entries);

  factory RecoveryHistorySnapshot.fromEntries(
    Iterable<RecoveryCheckIn> source, {
    int limit = 14,
  }) {
    if (limit <= 0) {
      return const RecoveryHistorySnapshot._(<RecoveryCheckIn>[]);
    }

    final sorted = source.toList()
      ..sort((a, b) {
        final dateComparison = b.date.compareTo(a.date);
        if (dateComparison != 0) return dateComparison;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final selected = <RecoveryCheckIn>[];
    final seenDays = <String>{};
    for (final entry in sorted) {
      final key = _dateKey(entry.date);
      if (!seenDays.add(key)) continue;
      selected.add(entry);
      if (selected.length == limit) break;
    }

    return RecoveryHistorySnapshot._(
      List<RecoveryCheckIn>.unmodifiable(selected),
    );
  }

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;
  int get completedDays => entries.length;

  int get averageScore {
    if (entries.isEmpty) return 0;
    final total = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.score,
    );
    return (total / entries.length).round();
  }

  int get bestScore {
    if (entries.isEmpty) return 0;
    return entries
        .map((entry) => entry.score)
        .reduce((best, score) => score > best ? score : best);
  }

  int countFor(RecoveryStatus status) {
    return entries.where((entry) => entry.status == status).length;
  }

  List<RecoveryCheckIn> get chronological {
    return entries.reversed.toList(growable: false);
  }

  RecoveryMetricTrend? get energyTrend => _trend((entry) => entry.energy);
  RecoveryMetricTrend? get sleepTrend => _trend((entry) => entry.sleep);
  RecoveryMetricTrend? get stressTrend => _trend((entry) => entry.stress);
  RecoveryMetricTrend? get sorenessTrend => _trend((entry) => entry.soreness);

  /// Compares two adjacent windows of up to three daily values each.
  /// Four days is the minimum so a single unusual day is not presented as a
  /// trend. These are descriptive values only; they do not diagnose recovery.
  RecoveryMetricTrend? _trend(int Function(RecoveryCheckIn entry) selector) {
    if (entries.length < 4) return null;
    final window = entries.length >= 6 ? 3 : 2;
    final recent = entries.take(window).toList(growable: false);
    final previous = entries.skip(window).take(window).toList(growable: false);
    if (previous.length < window) return null;

    double average(List<RecoveryCheckIn> source) =>
        source.fold<double>(0, (sum, entry) => sum + selector(entry)) /
        source.length;

    return RecoveryMetricTrend(
      recentAverage: average(recent),
      previousAverage: average(previous),
    );
  }

  static String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
