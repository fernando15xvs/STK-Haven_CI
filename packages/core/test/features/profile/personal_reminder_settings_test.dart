import 'package:core/features/profile/domain/personal_reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = PersonalReminderMessage(
    title: 'Mis razones',
    message: 'Decido cuidarme hoy.',
  );
  const b = PersonalReminderMessage(
    title: 'Una pausa',
    message: 'Puedo esperar diez minutos.',
  );
  const c = PersonalReminderMessage(
    title: 'Mañana',
    message: 'Lo que hago hoy cambia mi mañana.',
  );

  test('off by default and generic lock-screen content', () {
    final defaultValue = PersonalReminderSettings();
    expect(defaultValue.enabled, false);
    expect(defaultValue.messages, isEmpty);
    expect(defaultValue.showMessageInNotification, false);
    final saved = PersonalReminderSettings(messages: [a], enabled: true);
    expect(saved.isValid, true);
    expect(saved.notificationTitleFor(a),
      PersonalReminderSettings.safeNotificationTitle);
    expect(saved.notificationBodyFor(a),
      PersonalReminderSettings.safeNotificationBody);
  });

  test('30 and 60 minutes and strict round robin order', () {
    for (final interval in [30, 60]) {
      final settings = PersonalReminderSettings(
        messages: [a, b, c], intervalMinutes: interval, enabled: true);
      expect(settings.isValid, true);
      expect([for (var i = 0; i < 7; i++) settings.messageAt(i).title],
        ['Mis razones', 'Una pausa', 'Mañana', 'Mis razones',
         'Una pausa', 'Mañana', 'Mis razones']);
      final decoded = PersonalReminderSettings.fromJson(settings.toJson());
      expect(decoded.isValid, true);
      expect(decoded.messages.length, 3);
      expect(decoded.messages[1].message, b.message);
    }
    for (final interval in [0, 15, 45, 61]) {
      final invalid = PersonalReminderSettings(
        messages: [a], intervalMinutes: interval, enabled: true);
      expect(invalid.isValid, false);
      expect(PersonalReminderSettings.fromJson(invalid.toJson()).enabled, false);
    }
  });

  test('each title has 80 chars, each body has 3000 chars', () {
    final maxBody = 'x'.padRight(3000, 'x');
    final maxTitle = 'T'.padRight(80, 'T');
    expect(PersonalReminderMessage.validateTitle(maxTitle), isNull);
    expect(PersonalReminderMessage.validateMessage(maxBody), isNull);
    expect(PersonalReminderMessage.validateTitle(
      maxTitle + 'Z'), isNotNull);
    expect(PersonalReminderMessage.validateMessage(
      maxBody + 'Z'), isNotNull);
    expect(PersonalReminderMessage.validateTitle(' '), isNotNull);
    expect(PersonalReminderMessage.validateMessage('  '), isNotNull);
    expect(PersonalReminderMessage.validateMessage('Hola\u0000'), isNotNull);
    expect(PersonalReminderMessage(title: maxTitle, message: maxBody).isValid,
      true);
  });

  test('one opt-in controls both personal title and short excerpt', () {
    final hidden = PersonalReminderSettings(
      messages: [a, b], enabled: true);
    final visible = hidden.copyWith(showMessageInNotification: true);
    expect(hidden.notificationTitleFor(a), isNot(contains('razones')));
    expect(hidden.notificationBodyFor(b), isNot(contains('esperar')));
    expect(visible.notificationTitleFor(a), a.title);
    expect(visible.notificationBodyFor(b), b.message);
    final long = PersonalReminderMessage(
      title: 'Título privado',
      message: 'A'.padRight(3000, 'A'),
    );
    final short = visible.notificationBodyFor(long);
    expect(short.runes.length, lessThanOrEqualTo(120));
    expect(short.endsWith('…'), true);
    expect(visible.copyWith(enabled: false).enabled, false);
  });

  test('legacy single message migrates without deleting its text', () {
    final restored = PersonalReminderSettings.fromJson({
      'message': 'Una promesa que quiero conservar.',
      'intervalMinutes': 30,
      'enabled': true,
      'showMessageInNotification': false,
    });
    expect(restored.enabled, true);
    expect(restored.messages.length, 1);
    expect(restored.messages.single.title, 'Mi primer mensaje');
    expect(restored.messages.single.message,
      'Una promesa que quiero conservar.');
    expect(restored.notificationTitleFor(restored.messages.single),
      PersonalReminderSettings.safeNotificationTitle);
  });

  test('bad persisted data fails closed', () {
    for (final raw in [
      null, 13, <String, Object?>{},
      {'enabled': true, 'intervalMinutes': 30,
       'showMessageInNotification': false, 'messages': []},
      {'enabled': true, 'intervalMinutes': 45,
       'showMessageInNotification': false, 'messages': [a.toJson()]},
      {'enabled': 'yes', 'intervalMinutes': 60,
       'showMessageInNotification': true, 'messages': [a.toJson()]},
      {'enabled': true, 'intervalMinutes': 60,
       'showMessageInNotification': true, 'messages': [12]},
      {'enabled': true, 'intervalMinutes': 60,
       'showMessageInNotification': true,
       'messages': List.filled(25, a.toJson())},
    ]) {
      final result = PersonalReminderSettings.fromJson(raw);
      expect(result.enabled, false);
      expect(result.showMessageInNotification, false);
    }
  });

  test('saved library is immutable and edits do not mutate original', () {
    final settings = PersonalReminderSettings(messages: [a, b]);
    expect(() => settings.messages.add(c), throwsUnsupportedError);
    final changed = settings.copyWith(messages: [b, a, c]);
    expect(changed.messages.first.title, 'Una pausa');
    expect(settings.messages.first.title, 'Mis razones');
  });
}
