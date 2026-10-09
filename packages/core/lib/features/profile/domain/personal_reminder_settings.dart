/// Private motivational reminder stored only in this device's dedicated Hive box.
/// It is not part of STK Haven's manual or cloud-backup payload.
class PersonalReminderSettings {
  static const int maxMessageLength = 280;
  static const String safeNotificationBody =
      'Tienes un mensaje personal. Abre STK Haven cuando quieras.';

  final String message;
  final int intervalMinutes;
  final bool enabled;
  final bool showMessageInNotification;

  const PersonalReminderSettings({
    this.message = '',
    this.intervalMinutes = 60,
    this.enabled = false,
    this.showMessageInNotification = false,
  });

  static String? validateMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Escribe el mensaje que quieras recordar.';
    if (trimmed.runes.length > maxMessageLength) {
      return 'Usa como máximo $maxMessageLength caracteres.';
    }
    if (trimmed.contains(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'))) {
      return 'El mensaje contiene caracteres no permitidos.';
    }
    return null;
  }

  bool get isValid =>
      const [30, 60].contains(intervalMinutes) &&
      (!enabled || validateMessage(message) == null);

  /// Reject unknown/unsafe persisted configuration: fail closed.
  factory PersonalReminderSettings.fromJson(Object? raw) {
    if (raw is! Map) return const PersonalReminderSettings();
    final message = raw['message'];
    final interval = raw['intervalMinutes'];
    final enabled = raw['enabled'];
    final showMessage = raw['showMessageInNotification'];
    if (message is! String ||
        message.runes.length > maxMessageLength ||
        !const [30, 60].contains(interval) ||
        enabled is! bool ||
        showMessage is! bool) {
      return const PersonalReminderSettings();
    }
    final candidate = PersonalReminderSettings(
      message: message,
      intervalMinutes: interval as int,
      enabled: enabled,
      showMessageInNotification: showMessage,
    );
    return candidate.isValid ? candidate : const PersonalReminderSettings();
  }

  Map<String, Object> toJson() => {
    'message': message,
    'intervalMinutes': intervalMinutes,
    'enabled': enabled,
    'showMessageInNotification': showMessageInNotification,
  };

  PersonalReminderSettings copyWith({bool? enabled}) => PersonalReminderSettings(
    message: message,
    intervalMinutes: intervalMinutes,
    enabled: enabled ?? this.enabled,
    showMessageInNotification: showMessageInNotification,
  );

  /// The full text is not shown on the lock screen without explicit consent.
  String get notificationBody => showMessageInNotification
      ? message.trim().replaceAll(RegExp(r'\s+'), ' ')
      : safeNotificationBody;
}
