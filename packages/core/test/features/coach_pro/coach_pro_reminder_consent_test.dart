import 'package:core/features/coach_pro/domain/coach_pro_reminder_consent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> row({
    bool enabled = false,
    List<int> weekdays = const [1, 4],
    int? revision = 2,
  }) => {
    'enabled': enabled,
    'hour_local': 19,
    'weekdays': weekdays,
    'cadence_revision': revision,
  };

  test('disabled reminder is not implied by accepted cadence', () {
    final consent = CoachProReminderConsent.fromJson(row());
    expect(consent.enabled, false);
    expect(consent.weekdays, {1, 4});
    expect(consent.hourLocal, 19);
    expect(() => consent.weekdays.add(6), throwsUnsupportedError);
  });

  test('explicit opt-in requires an accepted cadence revision', () {
    final consent = CoachProReminderConsent.fromJson(row(enabled: true));
    expect(consent.enabled, true);
    expect(consent.cadenceRevision, 2);
    expect(
      () => CoachProReminderConsent.fromJson(
        row(enabled: true, revision: null)),
      throwsFormatException,
    );
    expect(
      () => CoachProReminderConsent.fromJson(
        row(enabled: true, weekdays: [])),
      throwsFormatException,
    );
  });

  test('invalid or contradictory backend consent fails closed', () {
    for (final invalid in <Map<String, dynamic>>[
      {...row(), 'enabled': null},
      {...row(), 'enabled': 'yes'},
      {...row(), 'hour_local': 6},
      {...row(), 'hour_local': 23},
      {...row(), 'weekdays': [1, 1]},
      {...row(), 'weekdays': [0]},
      {...row(), 'weekdays': [8]},
      {...row(), 'weekdays': [1, 2, 3, 4]},
      {...row(), 'weekdays': ['lunes']},
      {...row(), 'cadence_revision': -1},
    ]) {
      expect(() => CoachProReminderConsent.fromJson(invalid),
        throwsFormatException);
    }
  });

  test('lock-screen message contains no personal information', () {
    expect(coachProReminderTitle, 'STK Haven');
    expect(coachProReminderBody, isNot(contains('coach')));
    expect(coachProReminderBody, isNot(contains('check-in')));
    expect(coachProReminderBody, isNot(contains('cliente')));
    expect(coachProReminderBody, isNot(contains('entrenamiento')));
    expect(coachProReminderBody, isNot(contains('Ana')));
  });
}
