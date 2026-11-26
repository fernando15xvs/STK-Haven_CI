import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/nutrition/data/nutrition_guidance_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase/supabase.dart';

enum NutritionGuidanceOperation {
  idle,
  loading,
  saving,
  opening,
  archiving,
}

class NutritionGuidanceState {
  final List<NutritionGuidanceSummary> summaries;
  final Map<String, NutritionGuidancePlan> openedPlans;
  final NutritionGuidanceOperation operation;
  final String? message;
  final bool isError;

  const NutritionGuidanceState({
    this.summaries = const <NutritionGuidanceSummary>[],
    this.openedPlans = const <String, NutritionGuidancePlan>{},
    this.operation = NutritionGuidanceOperation.idle,
    this.message,
    this.isError = false,
  });

  bool get busy => operation != NutritionGuidanceOperation.idle;

  NutritionGuidanceState copyWith({
    List<NutritionGuidanceSummary>? summaries,
    Map<String, NutritionGuidancePlan>? openedPlans,
    NutritionGuidanceOperation? operation,
    String? message,
    bool clearMessage = false,
    bool? isError,
  }) {
    return NutritionGuidanceState(
      summaries: summaries ?? this.summaries,
      openedPlans: openedPlans ?? this.openedPlans,
      operation: operation ?? this.operation,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

final nutritionGuidanceServiceProvider =
    Provider<NutritionGuidanceService>((ref) {
  return NutritionGuidanceService(CoreSupabaseClient.client);
});

final nutritionGuidanceProvider =
    NotifierProvider<NutritionGuidanceNotifier, NutritionGuidanceState>(
  NutritionGuidanceNotifier.new,
);

class NutritionGuidanceNotifier extends Notifier<NutritionGuidanceState> {
  late NutritionGuidanceService _service;
  int _epoch = 0;
  bool _current(int epoch) => ref.mounted && epoch == _epoch;

  @override
  NutritionGuidanceState build() {
    ref.watch(appIdentityProvider.select((value) => (value.signedIn, value.userId)));
    _epoch++;
    ref.onDispose(() => _epoch++);
    _service = ref.watch(nutritionGuidanceServiceProvider);
    return const NutritionGuidanceState();
  }

  Future<void> refresh() async {
    final epoch = _epoch;
    if (!ref.read(appIdentityProvider).signedIn || state.busy) return;

    state = state.copyWith(
      operation: NutritionGuidanceOperation.loading,
      summaries: const [], openedPlans: const {},
      clearMessage: true,
      isError: false,
    );

    try {
      final summaries = await _service.listGuidance();
      if (!_current(epoch)) return;
      state = state.copyWith(
        summaries: List.unmodifiable(summaries),
        operation: NutritionGuidanceOperation.idle,
        isError: false,
      );
    } on PostgrestException catch (error) {
      if (!_current(epoch)) return;
      _fail(_databaseMessage(error));
    } catch (_) {
      if (!_current(epoch)) return;
      _fail('No se pudo cargar la orientación alimentaria.');
    }
  }

  Future<NutritionGuidancePlan?> open(
    String planId, {
    int? version,
  }) async {
    final epoch = _epoch;
    if (!ref.read(appIdentityProvider).signedIn || state.busy) return null;

    state = state.copyWith(
      operation: NutritionGuidanceOperation.opening,
      openedPlans: const {},
      clearMessage: true,
      isError: false,
    );

    try {
      final plan = await _service.getGuidance(planId, version: version);
      if (!_current(epoch)) return null;
      final key = _cacheKey(planId, plan.version);
      final next = Map<String, NutritionGuidancePlan>.from(state.openedPlans)
        ..[key] = plan;
      state = state.copyWith(
        openedPlans: Map.unmodifiable(next),
        operation: NutritionGuidanceOperation.idle,
        isError: false,
      );
      return plan;
    } on PostgrestException catch (error) {
      if (!_current(epoch)) return null;
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      if (!_current(epoch)) return null;
      _fail('No se pudo abrir esta orientación alimentaria.');
      return null;
    }
  }

  Future<String?> save({
    required String clientUserId,
    String? planId,
    required String title,
    String overview = '',
    String hydrationNotes = '',
    String generalNotes = '',
    List<NutritionGuidanceMeal> meals = const <NutritionGuidanceMeal>[],
  }) async {
    final epoch = _epoch;
    if (!ref.read(appIdentityProvider).signedIn || state.busy) return null;

    state = state.copyWith(
      operation: NutritionGuidanceOperation.saving,
      clearMessage: true,
      isError: false,
    );

    try {
      final payload = <String, dynamic>{
        'title': title.trim(),
        'overview': overview.trim(),
        'hydration_notes': hydrationNotes.trim(),
        'general_notes': generalNotes.trim(),
        'scope_notice': NutritionGuidancePlan.defaultScopeNotice,
        'meals': [
          for (final meal in meals) meal.toPayload(),
        ],
      };

      final id = await _service.saveGuidance(
        clientUserId: clientUserId,
        planId: planId,
        payload: payload,
      );
      if (!_current(epoch)) return null;

      state = state.copyWith(
        operation: NutritionGuidanceOperation.idle,
        message: planId == null
            ? 'Orientación alimentaria creada.'
            : 'Nueva versión guardada.',
        isError: false,
      );
      await refresh();
      if (!_current(epoch)) return null;
      return id;
    } on PostgrestException catch (error) {
      if (!_current(epoch)) return null;
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      if (!_current(epoch)) return null;
      _fail('No se pudo guardar la orientación alimentaria.');
      return null;
    }
  }

  Future<bool> archive(String planId) async {
    final epoch = _epoch;
    if (!ref.read(appIdentityProvider).signedIn || state.busy) return false;

    state = state.copyWith(
      operation: NutritionGuidanceOperation.archiving,
      clearMessage: true,
      isError: false,
    );

    try {
      await _service.archiveGuidance(planId);
      if (!_current(epoch)) return false;
      state = state.copyWith(
        operation: NutritionGuidanceOperation.idle,
        message: 'Orientación archivada.',
        isError: false,
      );
      await refresh();
      if (!_current(epoch)) return false;
      return true;
    } on PostgrestException catch (error) {
      if (!_current(epoch)) return false;
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      if (!_current(epoch)) return false;
      _fail('No se pudo archivar la orientación alimentaria.');
      return false;
    }
  }

  void clearForClient(String clientUserId) {
    _epoch++;
    final summaries = state.summaries
        .where((item) => item.clientUserId != clientUserId)
        .toList(growable: false);
    final opened = <String, NutritionGuidancePlan>{};
    for (final entry in state.openedPlans.entries) {
      if (entry.value.clientUserId != clientUserId) {
        opened[entry.key] = entry.value;
      }
    }
    state = state.copyWith(
      summaries: List.unmodifiable(summaries),
      openedPlans: Map.unmodifiable(opened),
      operation: NutritionGuidanceOperation.idle,
    );
  }

  void _fail(String message) {
    state = NutritionGuidanceState(message: message, isError: true);
  }

  String _databaseMessage(PostgrestException error) {
    final raw = error.message.toLowerCase();
    if (raw.contains('nutrition permission required')) {
      return 'El cliente no concedió acceso a orientación alimentaria.';
    }
    if (raw.contains('permanent authenticated account required')) {
      return 'Se necesita una cuenta permanente.';
    }
    if (raw.contains('active nutrition plan not found')) {
      return 'La orientación activa ya no está disponible.';
    }
    return 'La orientación alimentaria aún no está disponible en el backend activo.';
  }

  String _cacheKey(String planId, int version) => '$planId::$version';
}

typedef NutritionGuidanceDetailQuery = ({String userId, String planId, int version});
/// Sensitive detail is refetched and scoped to the viewing identity, not a
/// retained snapshot passed from a previous route.
final nutritionGuidanceDetailProvider = FutureProvider.autoDispose.family<NutritionGuidancePlan?, NutritionGuidanceDetailQuery>((ref,query) async {
  final actor = ref.watch(appIdentityProvider.select((value)=>(value.signedIn,value.userId)));
  if (!actor.$1 || actor.$2 != query.userId) return null;
  final value = await ref.watch(nutritionGuidanceServiceProvider).getGuidance(query.planId,version:query.version);
  if (value.id != query.planId || value.version != query.version) throw const FormatException('Guidance identity mismatch');
  return value;
});
