/// A single inactivity nudge plus one later follow-up, without auto-finishing.
class UnfinishedWorkoutReminderPolicy {
  const UnfinishedWorkoutReminderPolicy._();
  static const firstDelay = Duration(hours: 3);
  static const followUpDelay = Duration(hours: 24);

  static bool isStale(DateTime lastActivityAt, DateTime now) =>
      !now.isBefore(lastActivityAt.add(firstDelay));

  static List<DateTime> upcoming({
    required DateTime lastActivityAt,
    required DateTime now,
  }) => [
        lastActivityAt.add(firstDelay),
        lastActivityAt.add(followUpDelay),
      ].where((date) => date.isAfter(now)).toList(growable: false);
}
