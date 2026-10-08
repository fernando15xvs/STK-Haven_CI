/// Client-owned opt-in only. A coach's accepted cadence is not notification consent.
class CoachProReminderConsent {
  final bool enabled;
  final int hourLocal;
  final Set<int> weekdays;
  final int? cadenceRevision;

  const CoachProReminderConsent({
    required this.enabled,
    required this.hourLocal,
    required this.weekdays,
    required this.cadenceRevision,
  });

  factory CoachProReminderConsent.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final hour = json['hour_local'];
    final days = json['weekdays'];
    final revision = json['cadence_revision'];
    if (enabled is! bool || hour is! int || hour < 7 || hour > 22 ||
        days is! List || days.length > 3 ||
        days.any((v) => v is! int || v < 1 || v > 7) ||
        days.toSet().length != days.length ||
        (revision != null && (revision is! int || revision < 1 || revision > 10000)) ||
        (enabled && (revision == null || days.isEmpty))) {
      throw const FormatException('Invalid Coach Pro reminder consent');
    }
    return CoachProReminderConsent(
      enabled: enabled,
      hourLocal: hour,
      weekdays: Set.unmodifiable(days.cast<int>()),
      cadenceRevision: revision as int?,
    );
  }
}

/// These fixed strings are the ONLY lock-screen content for Coach Pro reminders.
/// Never include a client, coach, task title, workout, check-in score, or UUID.
const coachProReminderTitle = 'STK Haven';
const coachProReminderBody = 'Tienes un recordatorio opcional. Abre la app cuando quieras.';
