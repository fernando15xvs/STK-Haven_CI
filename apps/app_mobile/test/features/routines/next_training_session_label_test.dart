import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/routines/application/next_training_session_label.dart';

void main() {
  final today = DateTime(2026, 11, 21, 16, 30);

  test('future projected session is not called today on an eligible day', () {
    // Regression: an eligible current weekday does not mean that the next
    // projected date is today (e.g., today's set was already completed).
    final label = NextTrainingSessionLabel.forSchedule(
      scheduledDate: DateTime(2026, 11, 23),
      isFlexible: false,
      now: today,
    );
    expect(label, startsWith('Próximo día: '));
    expect(label, isNot(contains('para hoy')));
  });

  test('projected session today has a truthful label', () {
    expect(
      NextTrainingSessionLabel.forSchedule(
        scheduledDate: DateTime(2026, 11, 21, 8),
        isFlexible: false,
        now: today,
      ),
      'Sesión programada para hoy',
    );
  });

  test('flexible scheduling never asserts a mandatory date', () {
    expect(
      NextTrainingSessionLabel.forSchedule(
        scheduledDate: DateTime(2026, 11, 23),
        isFlexible: true,
        now: today,
      ),
      'Rotación flexible · sin día obligatorio',
    );
  });

  test('missing projection date does not invent a scheduled day', () {
    expect(
      NextTrainingSessionLabel.forSchedule(
        scheduledDate: null,
        isFlexible: false,
        now: today,
      ),
      'Próxima sesión · fecha por definir',
    );
  });

  test('date-only equivalence does not depend on exact wall time', () {
    expect(
      NextTrainingSessionLabel.forSchedule(
        scheduledDate: DateTime(2026, 11, 21, 23, 59),
        isFlexible: false,
        now: today,
      ),
      'Sesión programada para hoy',
    );
  });
}
