/// Private local motivational entries. Never stored in cloud backup.
class PersonalReminderMessage {
  static const int maxTitleLength = 80;
  static const int maxMessageLength = 3000;

  final String title;
  final String message;

  const PersonalReminderMessage({required this.title, required this.message});

  static String? validateTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Escribe un título.';
    if (trimmed.runes.length > maxTitleLength) {
      return 'El título permite máximo 80 caracteres.';
    }
    if (_hasControlChars(trimmed)) return 'El título contiene caracteres inválidos.';
    return null;
  }

  static String? validateMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Escribe tu mensaje.';
    if (trimmed.runes.length > maxMessageLength) {
      return 'El mensaje permite máximo 3.000 caracteres.';
    }
    if (_hasControlChars(trimmed)) return 'El mensaje contiene caracteres inválidos.';
    return null;
  }

  static bool _hasControlChars(String text) =>
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(text);

  bool get isValid => validateTitle(title) == null &&
      validateMessage(message) == null;

  Map<String, String> toJson() =>
      {'title': title.trim(), 'message': message.trim()};

  static PersonalReminderMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = raw['title'];
    final message = raw['message'];
    if (title is! String || message is! String) return null;
    final value = PersonalReminderMessage(title: title, message: message);
    return value.isValid ? value : null;
  }
}

class PersonalReminderSettings {
  static const int maxMessages = 24;
  static const int maxMessageLength = PersonalReminderMessage.maxMessageLength;
  static const String safeNotificationTitle = 'STK Haven · Para ti';
  static const String safeNotificationBody =
      'Tienes un mensaje personal. Abre STK Haven cuando quieras.';

  final List<PersonalReminderMessage> messages;
  final int intervalMinutes;
  final bool enabled;
  final bool showMessageInNotification;

  PersonalReminderSettings({
    List<PersonalReminderMessage> messages = const [],
    this.intervalMinutes = 60,
    this.enabled = false,
    this.showMessageInNotification = false,
  }) : messages = List.unmodifiable(messages);

  bool get isValid =>
      const [30, 60].contains(intervalMinutes) &&
      messages.length <= maxMessages &&
      messages.every((m) => m.isValid) &&
      (!enabled || messages.isNotEmpty);

  /// Invalid persisted data always disables delivery and hides previews.
  factory PersonalReminderSettings.fromJson(Object? raw) {
    if (raw is! Map) return PersonalReminderSettings();
    final interval = raw['intervalMinutes'];
    final enabled = raw['enabled'];
    final showMessage = raw['showMessageInNotification'];
    if (interval is! int || !const [30, 60].contains(interval) ||
        enabled is! bool || showMessage is! bool) {
      return PersonalReminderSettings();
    }

    final messagesRaw = raw['messages'];
    final List<PersonalReminderMessage> messages = [];
    if (messagesRaw is List) {
      if (messagesRaw.length > maxMessages) return PersonalReminderSettings();
      for (final entry in messagesRaw) {
        final card = PersonalReminderMessage.fromJson(entry);
        if (card == null) return PersonalReminderSettings();
        messages.add(card);
      }
    } else if (raw['message'] is String) {
      // Migrate original single-message configuration, including opt-in state.
      final oldMessage = raw['message'] as String;
      if (oldMessage.trim().isNotEmpty) {
        final card = PersonalReminderMessage(
          title: 'Mi primer mensaje', message: oldMessage,
        );
        if (!card.isValid) return PersonalReminderSettings();
        messages.add(card);
      }
    } else {
      return PersonalReminderSettings();
    }
    final candidate = PersonalReminderSettings(
      messages: messages,
      intervalMinutes: interval,
      enabled: enabled,
      showMessageInNotification: showMessage,
    );
    return candidate.isValid ? candidate : PersonalReminderSettings();
  }

  Map<String, Object> toJson() => {
    'messages': messages.map((m) => m.toJson()).toList(growable: false),
    'intervalMinutes': intervalMinutes,
    'enabled': enabled,
    'showMessageInNotification': showMessageInNotification,
  };

  PersonalReminderSettings copyWith({
    List<PersonalReminderMessage>? messages,
    int? intervalMinutes,
    bool? enabled,
    bool? showMessageInNotification,
  }) => PersonalReminderSettings(
    messages: messages ?? this.messages,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    enabled: enabled ?? this.enabled,
    showMessageInNotification: showMessageInNotification ??
        this.showMessageInNotification,
  );

  PersonalReminderMessage messageAt(int sequence) =>
      messages[sequence % messages.length];

  String notificationTitleFor(PersonalReminderMessage item) =>
      showMessageInNotification ? item.title.trim() : safeNotificationTitle;

  /// Full 3,000-character message remains available in the in-app library.
  String notificationBodyFor(PersonalReminderMessage item) {
    if (!showMessageInNotification) return safeNotificationBody;
    final normalized = item.message.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.runes.length <= 120) return normalized;
    return String.fromCharCodes(normalized.runes.take(117)) + '…';
  }
}
