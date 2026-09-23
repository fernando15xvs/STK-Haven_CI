import 'package:core/features/recovery/application/recovery_history.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecoveryCheckIn checkIn({
    required int day,
    required int energy,
    required int sleep,
    required int stress,
    required int soreness,
    int updatedHour = 8,
  }) {
    return RecoveryCheckIn(
      date: DateTime(2026, 9, day),
      energy: energy,
      sleep: sleep,
      stress: stress,
      soreness: soreness,
      updatedAt: DateTime(2026, 9, day, updatedHour),
    );
  }

  group('RecoveryHistorySnapshot', () {
    test('sorts newest first and respects the requested limit', () {
      final snapshot = RecoveryHistorySnapshot.fromEntries(
        [
          checkIn(
            day: 1,
            energy: 5,
            sleep: 5,
            stress: 1,
            soreness: 1,
          ),
          checkIn(
            day: 3,
            energy: 4,
            sleep: 4,
            stress: 2,
            soreness: 2,
          ),
          checkIn(
            day: 2,
            energy: 3,
            sleep: 3,
            stress: 3,
            soreness: 3,
          ),
        ],
        limit: 2,
      );

      expect(snapshot.entries.map((entry) => entry.date.day), [3, 2]);
      expect(snapshot.chronological.map((entry) => entry.date.day), [2, 3]);
    });

    test('calculates average, best score and status distribution', () {
      final snapshot = RecoveryHistorySnapshot.fromEntries([
        checkIn(
          day: 1,
          energy: 5,
          sleep: 5,
          stress: 1,
          soreness: 1,
        ),
        checkIn(
          day: 2,
          energy: 4,
          sleep: 4,
          stress: 3,
          soreness: 3,
        ),
        checkIn(
          day: 3,
          energy: 2,
          sleep: 2,
          stress: 5,
          soreness: 5,
        ),
      ]);

      expect(snapshot.completedDays, 3);
      expect(snapshot.averageScore, 67);
      expect(snapshot.bestScore, 100);
      expect(snapshot.countFor(RecoveryStatus.ready), 1);
      expect(snapshot.countFor(RecoveryStatus.moderate), 1);
      expect(snapshot.countFor(RecoveryStatus.low), 1);
    });

    test('keeps only the most recently updated entry for the same day', () {
      final snapshot = RecoveryHistorySnapshot.fromEntries([
        checkIn(
          day: 1,
          energy: 2,
          sleep: 2,
          stress: 4,
          soreness: 4,
        ),
        checkIn(
          day: 1,
          energy: 5,
          sleep: 5,
          stress: 1,
          soreness: 1,
          updatedHour: 18,
        ),
      ]);

      expect(snapshot.completedDays, 1);
      expect(snapshot.entries.single.score, 100);
    });

    test('returns an empty snapshot for an empty or invalid period', () {
      final empty = RecoveryHistorySnapshot.fromEntries(const []);
      final invalid = RecoveryHistorySnapshot.fromEntries(
        [
          checkIn(
            day: 1,
            energy: 5,
            sleep: 5,
            stress: 1,
            soreness: 1,
          ),
        ],
        limit: 0,
      );

      expect(empty.isEmpty, true);
      expect(empty.averageScore, 0);
      expect(empty.bestScore, 0);
      expect(invalid.isEmpty, true);
    });
  });
}
