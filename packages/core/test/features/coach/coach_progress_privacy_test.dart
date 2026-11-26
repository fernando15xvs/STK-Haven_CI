import 'dart:async';
import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/coach_exercise_progress.dart';
import 'package:core/features/coach/application/coach_progress_provider.dart';
import 'package:core/features/coach/data/coach_progress_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

class _Identity extends AppIdentityNotifier {
  @override
  AppIdentityState build() => const AppIdentityState(
    sessionKind: AppSessionKind.permanent, userId: 'coach-a');
  void change(String? id) => state = AppIdentityState(
    sessionKind: id == null ? AppSessionKind.none : AppSessionKind.permanent,
    userId: id);
}
class _Service implements CoachProgressService {
  final requests = <Completer<CoachClientProgress>>[];
  @override
  Never get client => throw UnimplementedError();
  @override
  Future<void> syncOwnProgress(CoachClientProgress progress, {
    List<CoachExerciseProgressSummary> exerciseProgress = const [],
  }) async {}
  @override
  Future<CoachClientProgress> getClientProgress(String clientUserId) {
    final request = Completer<CoachClientProgress>();
    requests.add(request);
    return request.future;
  }
}
CoachClientProgress _progress(String id) => CoachClientProgress(
  clientUserId: id, workouts7d: 1, workouts30d: 1,
  trainingMinutes7d: 20, completedWorkingSets7d: 3, volume7d: 20,
  generatedAt: DateTime.utc(2026, 11, 26));

void main() {
  late ProviderContainer container;
  late _Service service;
  setUp(() {
    service = _Service();
    container = ProviderContainer(overrides: [
      appIdentityProvider.overrideWith(_Identity.new),
      coachProgressServiceProvider.overrideWithValue(service),
    ]);
    container.listen(coachProgressProvider, (_, _) {});
  });
  tearDown(() => container.dispose());
  test('refresh denial removes previously shared information', () async {
    final notifier = container.read(coachProgressProvider.notifier);
    final first = notifier.loadClientProgress('client');
    service.requests.last.complete(_progress('client'));
    await first;
    expect(container.read(coachProgressProvider).byClientId, contains('client'));
    final retry = notifier.loadClientProgress('client');
    expect(container.read(coachProgressProvider).byClientId, isEmpty);
    service.requests.last.completeError(StateError('denied'));
    expect(await retry, isNull);
    expect(container.read(coachProgressProvider).byClientId, isEmpty);
    expect(container.read(coachProgressProvider).isError, isTrue);
  });
  test('account switch discards an outstanding response', () async {
    final notifier = container.read(coachProgressProvider.notifier);
    final old = notifier.loadClientProgress('client');
    container.read(appIdentityProvider.notifier);
    (container.read(appIdentityProvider.notifier) as _Identity).change('coach-b');
    container.read(coachProgressProvider);
    service.requests.last.complete(_progress('client'));
    expect(await old, isNull);
    expect(container.read(coachProgressProvider).byClientId, isEmpty);
  });
  test('revocation prevents a late response restoring data', () async {
    final notifier = container.read(coachProgressProvider.notifier);
    final old = notifier.loadClientProgress('client');
    notifier.clearClient('client');
    service.requests.last.complete(_progress('client'));
    expect(await old, isNull);
    expect(container.read(coachProgressProvider).byClientId, isEmpty);
  });
  test('mismatched client payload fails closed', () async {
    final request = container.read(coachProgressProvider.notifier).loadClientProgress('client');
    service.requests.last.complete(_progress('other'));
    expect(await request, isNull);
    expect(container.read(coachProgressProvider).byClientId, isEmpty);
  });
}
