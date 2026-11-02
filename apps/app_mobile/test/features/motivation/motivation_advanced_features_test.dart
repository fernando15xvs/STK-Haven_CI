import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';
import 'package:gym_tracker/features/motivation/application/motivation_sleep_timer.dart';

void main() {
  test('legacy imported media defaults to not favorite', () {
    final track = MotivationTrack.fromJson({
      'id': 'old',
      'title': 'Archivo existente',
      'fileName': 'old.mp4',
      'mode': 'hype',
      'importedAt': '2026-10-30T00:00:00.000Z',
    });
    expect(track.favorite, isFalse);
    expect(track.copyWith(favorite: true).favorite, isTrue);
    expect(
      MotivationTrack.fromJson(track.copyWith(favorite: true).toJson())
          .favorite,
      isTrue,
    );
  });

  test('reordering down uses Flutter insert-index semantics', () {
    expect(MotivationLibrary.moveIds(['a', 'b', 'c'], 0, 3),
        ['b', 'c', 'a']);
    expect(MotivationLibrary.moveIds(['a', 'b', 'c'], 2, 0),
        ['c', 'a', 'b']);
    expect(MotivationLibrary.moveIds(['a', 'b'], 1, 1),
        ['a', 'b']);
    expect(
      () => MotivationLibrary.moveIds(['a', 'b'], 2, 0),
      throwsRangeError,
    );
  });

  test('sleep timer expiry is one-shot, cancellable and uses wall time', () {
    var now = DateTime.utc(2026, 11, 1, 20);
    var calls = 0;
    final timer = MotivationSleepTimer(
      clock: () => now,
      onExpired: () => calls++,
    );
    timer.start(const Duration(minutes: 5));
    expect(timer.active, isTrue);
    now = now.add(const Duration(minutes: 4));
    timer.checkDeadline();
    expect(calls, 0);
    expect(timer.remaining, const Duration(minutes: 1));
    now = now.add(const Duration(minutes: 2));
    timer.checkDeadline();
    timer.checkDeadline();
    expect(calls, 1);
    expect(timer.active, isFalse);
    timer.start(const Duration(minutes: 15));
    timer.cancel();
    now = now.add(const Duration(minutes: 20));
    timer.checkDeadline();
    expect(calls, 1);
    timer.dispose();
  });
}
