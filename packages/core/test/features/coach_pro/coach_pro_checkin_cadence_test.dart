import 'package:core/features/coach_pro/domain/coach_pro_checkin_cadence.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> cadence() => {
  'relationship_id': 'relationship-1',
  'weekdays': [1, 3],
  'status': 'proposed',
  'revision': 1,
  'proposed_at': '2026-10-08T12:00:00Z',
  'responded_at': null,
};

void main() {
  test('decodes scoped cadence without inventing client consent', () {
    final model = CoachProCheckinCadence.fromJson(
      cadence(), expectedRelationshipId: 'relationship-1',
    );
    expect(model.weekdays, {1, 3});
    expect(model.revision, 1);
    expect(model.status, CoachProCheckinCadenceStatus.proposed);
    expect(model.respondedAt, isNull);
    expect(() => model.weekdays.add(7), throwsUnsupportedError);
  });

  test('tracks explicit acceptance with response timestamp', () {
    final model = CoachProCheckinCadence.fromJson({
      ...cadence(),
      'status': 'accepted',
      'revision': 2,
      'responded_at': '2026-10-08T13:00:00Z',
    }, expectedRelationshipId: 'relationship-1');
    expect(model.status, CoachProCheckinCadenceStatus.accepted);
    expect(model.respondedAt, isNotNull);
  });

  test('rejects wrong relationship, duplicate or excessive days', () {
    for (final value in <Map<String, dynamic>>[
      {...cadence(), 'relationship_id': 'other'},
      {...cadence(), 'weekdays': [1, 1]},
      {...cadence(), 'weekdays': [1, 2, 3, 4]},
      {...cadence(), 'weekdays': []},
      {...cadence(), 'weekdays': [0]},
      {...cadence(), 'weekdays': [1, 8]},
      {...cadence(), 'weekdays': [1, 'two']},
      {...cadence(), 'status': 'unknown'},
      {...cadence(), 'revision': null},
      {...cadence(), 'proposed_at': 'invalid'},
      {...cadence(), 'responded_at': 'invalid'},
    ]) {
      expect(
        () => CoachProCheckinCadence.fromJson(
          value, expectedRelationshipId: 'relationship-1',
        ),
        throwsFormatException,
      );
    }
  });
}
