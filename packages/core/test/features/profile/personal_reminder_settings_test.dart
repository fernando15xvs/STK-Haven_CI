import 'package:core/features/profile/domain/personal_reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default is OFF, device-private and hides notification content', () {
    const settings = PersonalReminderSettings();
    expect(settings.enabled, isFalse);
    expect(settings.intervalMinutes, 60);
    expect(settings.showMessageInNotification, isFalse);
    expect(settings.notificationBody,
        PersonalReminderSettings.safeNotificationBody);
  });

  test('30 and 60 minute schedules are the only valid intervals', () {
    for (final interval in [30, 60]) {
      final data = PersonalReminderSettings(
        message: 'Voy paso a paso.',
        intervalMinutes: interval,
        enabled: true,
      );
      expect(data.isValid, isTrue);
      expect(PersonalReminderSettings.fromJson(data.toJson()).isValid, isTrue);
    }
    for (final interval in [0, 15, 29, 45, 61, 3600]) {
      final invalid = PersonalReminderSettings(
        message: 'Hoy sigo adelante.',
        intervalMinutes: interval, enabled: true,
      );
      expect(invalid.isValid, isFalse);
      expect(PersonalReminderSettings.fromJson(invalid.toJson()).enabled,
        isFalse);
    }
  });

  test('message is required to activate; bounded and control-safe', () {
    expect(PersonalReminderSettings.validateMessage('  '), isNotNull);
    expect(PersonalReminderSettings.validateMessage('x'.padRight(281, 'x')), isNotNull);
    expect(PersonalReminderSettings.validateMessage('Hola\u0000'), isNotNull);
    expect(PersonalReminderSettings.validateMessage(
      'Cada día es una nueva oportunidad.'), isNull);
    expect(const PersonalReminderSettings(message: '', enabled: true).isValid,
      isFalse);
    expect(const PersonalReminderSettings(message: '', enabled: false).isValid,
      isTrue);
  });

  test('private content is shown only after separate opt-in', () {
    const hidden = PersonalReminderSettings(
      message: 'Mi frase privada', enabled: true);
    const visible = PersonalReminderSettings(
      message: 'Mi frase privada', enabled: true,
      showMessageInNotification: true);
    expect(hidden.notificationBody, isNot(contains('privada')));
    expect(visible.notificationBody, 'Mi frase privada');
    expect(hidden.copyWith(enabled: false).enabled, isFalse);
  });

  test('corrupted/legacy JSON fails closed without exposing text', () {
    for (final raw in [
      null,
      12,
      <String, Object?>{},
      {'enabled': true, 'message': 'test', 'intervalMinutes': 12,
       'showMessageInNotification': false},
      {'enabled': 'true', 'message': 'test', 'intervalMinutes': 30,
       'showMessageInNotification': false},
      {'enabled': true, 'message': '', 'intervalMinutes': 30,
       'showMessageInNotification': true},
    ]) {
      final settings = PersonalReminderSettings.fromJson(raw);
      expect(settings.enabled, isFalse);
      expect(settings.showMessageInNotification, isFalse);
    }
  });
}
