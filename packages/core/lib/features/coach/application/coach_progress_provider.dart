import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/coach/application/coach_progress_snapshot_builder.dart';
import 'package:core/features/coach/application/coach_exercise_progress_snapshot_builder.dart';
import 'package:core/features/coach/data/coach_progress_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase/supabase.dart';

enum CoachProgressOperation {
  idle,
  syncingOwn,
  loadingClient,
}

class CoachProgressState {
  final Map<String, CoachClientProgress> byClientId;
  final CoachProgressOperation operation;
  final String? message;
  final bool isError;

  const CoachProgressState({
    this.byClientId = const <String, CoachClientProgress>{},
    this.operation = CoachProgressOperation.idle,
    this.message,
    this.isError = false,
  });

  bool get busy => operation != CoachProgressOperation.idle;

  CoachProgressState copyWith({
    Map<String, CoachClientProgress>? byClientId,
    CoachProgressOperation? operation,
    String? message,
    bool clearMessage = false,
    bool? isError,
  }) {
    return CoachProgressState(
      byClientId: byClientId ?? this.byClientId,
      operation: operation ?? this.operation,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

final coachProgressServiceProvider = Provider<CoachProgressService>((ref) {
  return CoachProgressService(CoreSupabaseClient.client);
});

final coachProgressProvider =
    NotifierProvider<CoachProgressNotifier, CoachProgressState>(
  CoachProgressNotifier.new,
);

class CoachProgressNotifier extends Notifier<CoachProgressState> {
  late CoachProgressService _service;
  int _generation = 0;
  bool _current(int generation) => ref.mounted && generation == _generation;

  @override
  CoachProgressState build() {
    ref.watch(appIdentityProvider.select((value) => (value.signedIn, value.userId)));
    _generation++;
    ref.onDispose(() => _generation++);
    _service = ref.watch(coachProgressServiceProvider);
    return const CoachProgressState();
  }

  Future<bool> syncOwnProgress(
    Iterable<WorkoutSession> history, {
    bool silent = false,
  }) async {
    final identity = ref.read(appIdentityProvider);
    if (!identity.signedIn) return false;
    if (state.busy) return false;
    final generation = ++_generation;

    state = state.copyWith(
      operation: CoachProgressOperation.syncingOwn,
      clearMessage: true,
      isError: false,
    );

    try {
      final snapshot = CoachProgressSnapshotBuilder.fromHistory(history);
      final exerciseProgress =
          CoachExerciseProgressSnapshotBuilder.fromHistory(history);
      await _service.syncOwnProgress(
        snapshot,
        exerciseProgress: exerciseProgress,
      );
      if (!_current(generation)) return false;
      state = state.copyWith(
        operation: CoachProgressOperation.idle,
        message: silent ? null : 'Progreso compartido actualizado.',
        clearMessage: silent,
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      if (!_current(generation)) return false;
      state = state.copyWith(
        operation: CoachProgressOperation.idle,
        message: silent ? null : _databaseMessage(error),
        clearMessage: silent,
        isError: !silent,
      );
      return false;
    } catch (_) {
      if (!_current(generation)) return false;
      state = state.copyWith(
        operation: CoachProgressOperation.idle,
        message: silent ? null : 'No se pudo actualizar el progreso compartido.',
        clearMessage: silent,
        isError: !silent,
      );
      return false;
    }
  }

  Future<CoachClientProgress?> loadClientProgress(String clientUserId) async {
    if (clientUserId.trim().isEmpty) return null;
    if (!ref.read(appIdentityProvider).signedIn) return null;
    if (state.busy) return null;
    final generation = ++_generation;
    final remaining = Map<String, CoachClientProgress>.from(state.byClientId)
      ..remove(clientUserId);
    state = state.copyWith(
      byClientId: Map.unmodifiable(remaining),
      operation: CoachProgressOperation.loadingClient,
      clearMessage: true,
      isError: false,
    );

    try {
      final progress = await _service.getClientProgress(clientUserId);
      if (!_current(generation)) return null;
      if (progress.clientUserId != null && progress.clientUserId != clientUserId) {
        throw const FormatException('Client progress identity mismatch');
      }
      final next = Map<String, CoachClientProgress>.from(state.byClientId)
        ..[clientUserId] = progress;
      state = state.copyWith(
        byClientId: Map.unmodifiable(next),
        operation: CoachProgressOperation.idle,
        isError: false,
      );
      return progress;
    } on PostgrestException catch (error) {
      if (!_current(generation)) return null;
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      if (!_current(generation)) return null;
      _fail('No se pudo cargar el progreso compartido.');
      return null;
    }
  }

  void clearClient(String clientUserId) {
    // Revocation must also discard any in-flight protected response.
    final cancelRead = state.operation == CoachProgressOperation.loadingClient;
    if (cancelRead) _generation++;
    final next = Map<String, CoachClientProgress>.from(state.byClientId)
      ..remove(clientUserId);
    state = state.copyWith(
      byClientId: Map.unmodifiable(next),
      operation: cancelRead ? CoachProgressOperation.idle : state.operation,
    );
  }

  void _fail(String message) {
    state = state.copyWith(
      operation: CoachProgressOperation.idle,
      message: message,
      isError: true,
    );
  }

  String _databaseMessage(PostgrestException error) {
    final raw = error.message.toLowerCase();
    if (raw.contains('progress permission required')) {
      return 'El cliente no concedió permiso para ver su progreso.';
    }
    if (raw.contains('permanent authenticated account required')) {
      return 'Se necesita una cuenta permanente.';
    }
    return 'Progreso compartido aún no está disponible en el backend activo.';
  }
}
