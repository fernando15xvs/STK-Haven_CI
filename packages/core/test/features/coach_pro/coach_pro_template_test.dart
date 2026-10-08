import 'package:core/features/coach_pro/domain/coach_pro_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> item() => {
        'id': 'a0000000-0000-0000-0000-000000000001',
        'title': 'Fuerza A',
        'duration_weeks': 8,
        'routine_count': 3,
        'created_at': '2026-10-08T17:00:00Z',
      };

  test('parses one bounded page of metadata, without raw program data', () {
    final page = CoachProTemplatePage.fromJson({
      'total_count': 1,
      'items': [item()],
    });
    expect(page.totalCount, 1);
    expect(page.items.single.title, 'Fuerza A');
    expect(page.items.single.durationWeeks, 8);
    expect(page.items.single.routineCount, 3);
    expect(() => page.items.add(page.items.single), throwsUnsupportedError);
  });

  test('rejects unbounded counts, incorrect fields and opaque payload', () {
    expect(
      () => CoachProTemplatePage.fromJson({'total_count': -1, 'items': []}),
      throwsFormatException,
    );
    expect(
      () => CoachProTemplatePage.fromJson({
        'total_count': 1,
        'items': [{...item(), 'routine_count': null}]
      }),
      throwsFormatException,
    );
    expect(
      () => CoachProTemplatePage.fromJson({
        'total_count': 1,
        'items': [item(), item()]
      }),
      throwsFormatException,
    );
    expect(
      () => CoachProTemplatePage.fromJson({
        'total_count': 101,
        'items': []
      }),
      throwsFormatException,
    );
  });

  test('does not invent timestamps for malformed responses', () {
    expect(
      () => CoachProTemplateSummary.fromJson({
        ...item(), 'created_at': 'not-a-date'
      }),
      throwsFormatException,
    );
    expect(
      () => CoachProTemplateSummary.fromJson({
        ...item(), 'title': ''
      }),
      throwsFormatException,
    );
  });
}
