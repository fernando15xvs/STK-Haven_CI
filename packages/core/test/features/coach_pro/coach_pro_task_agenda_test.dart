import 'package:core/features/coach_pro/domain/coach_pro_task_agenda.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> item({
  String? status,
  int? minutes,
  String day = '2026-10-08',
}) => {
  'task_id': 'assigned-task',
  'title': 'Revisión voluntaria',
  'task_type': 'checklist',
  'target_minutes': 10,
  'due_on': day,
  'status': status,
  'minutes_spent': minutes,
};

Map<String, dynamic> page(List<dynamic> items) => {
  'relationship_id': 'relationship-1',
  'start_on': '2026-10-08',
  'days': 14,
  'total_count': items.length,
  'items': items,
};

void main() {
  test('missing task occurrence means unrecorded, not skipped', () {
    final result = CoachProAgendaPage.fromJson(
      page([item()]), expectedRelationshipId: 'relationship-1');
    expect(result.items.single.status, CoachProAgendaStatus.unrecorded);
    expect(result.items.single.minutesSpent, isNull);
    expect(result.totalCount, 1);
    expect(() => result.items.add(result.items.single), throwsUnsupportedError);
  });

  test('explicit completion and skip remain distinct', () {
    final completed = CoachProAgendaItem.fromJson(
      item(status: 'completed', minutes: 12));
    final skipped = CoachProAgendaItem.fromJson(
      item(status: 'skipped', minutes: 0));
    expect(completed.status, CoachProAgendaStatus.completed);
    expect(completed.minutesSpent, 12);
    expect(skipped.status, CoachProAgendaStatus.skipped);
  });

  test('rejects cross-relationship, out of window, and malformed schedule', () {
    for (final raw in <Map<String, dynamic>>[
      {...page([item()]), 'relationship_id': 'other'},
      {...page([item()]), 'days': 30},
      {...page([item()]), 'total_count': 0},
      {...page([item()]), 'start_on': 'incorrect'},
      page([item(day: '2026-10-23')]),
      page([item(day: 'invalid')]),
      page([item(status: 'overdue', minutes: 0)]),
      page([item(status: null, minutes: 2)]),
      page([item(status: 'completed', minutes: null)]),
      page([item(status: 'completed', minutes: -1)]),
      page([item()..['task_id'] = '']),
      page([item()..['target_minutes'] = 1441]),
    ]) {
      expect(() => CoachProAgendaPage.fromJson(raw,
        expectedRelationshipId: 'relationship-1'), throwsFormatException);
    }
  });
}
