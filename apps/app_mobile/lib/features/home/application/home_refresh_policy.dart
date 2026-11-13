/// Pure local-time and visibility rules shared by Inicio's retained tabs.
class HomeRefreshPolicy {
  const HomeRefreshPolicy._();

  static bool sameLocalDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  static int greetingPeriod(DateTime instant) {
    final hour = instant.toLocal().hour;
    if (hour < 12) return 0;
    if (hour < 18) return 1;
    return 2;
  }

  static bool needsHeaderUpdate(DateTime previous, DateTime current) =>
      !sameLocalDay(previous, current) ||
      greetingPeriod(previous) != greetingPeriod(current);

  /// One-minute foreground updates; five minutes with performance savings.
  /// The interval is used only while Inicio is visible and the app foregrounded.
  static Duration stepRefreshInterval({required bool savings}) =>
      savings ? const Duration(minutes: 5) : const Duration(minutes: 1);

  /// Hidden retained tabs and backgrounded apps never poll the step sensor.
  static bool canPoll({
    required bool visible,
    required bool appResumed,
  }) => visible && appResumed;
}
