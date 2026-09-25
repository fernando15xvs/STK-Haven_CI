import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/nutrition/data/nutrition_guidance_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  return NutritionGuidanceService(Supabase.instance.client);
});

final nutritionGuidanceProvider =
    NotifierProvider<NutritionGuidanceNotifier, NutritionGuidanceState>(
  NutritionGuidanceNotifier.new,
);

class NutritionGuidanceNotifier extends Notifier<NutritionGuidanceState> {
  late final NutritionGuidanceService _service;

  @override
  NutritionGuidanceState build() {
    _service = ref.watch(nutritionGuidanceServiceProvider);
    return const NutritionGuidanceState();
  }

  Future<void> refresh() async {
    if (!ref.read(appIdentityProvider).signedIn || state.busy) return;

    state = state.copyWith(
      operation: NutritionGuidanceOperation.loading,
      clearMessage: true,
      isError: false,
    );

    try {
      final summaries = await _service.listGuidance();
      state = state.copyWith(
        summaries: List.unmodifiable(summaries),
        operation: NutritionGuidanceOperation.idle,
        isError: false,
      );
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
    } catch (_) {
      _fail('No se pudo cargar la orientación alimentaria.');
    }
  }

  Future<NutritionGuidancePlan?> open(
    String planId, {
    int? version,
  }) async {
    if (!ref.read(appIdentityProvider).signedIn || state.busy) return null;

    state = state.copyWith(
      operation: NutritionGuidanceOperation.opening,
      clearMessage: true,
      isError: false,
    );

    try {
      final plan = await _service.getGuidance(planId, version: version);
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
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
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

      state = state.copyWith(
        operation: NutritionGuidanceOperation.idle,
        message: planId == null
            ? 'Orientación alimentaria creada.'
            : 'Nueva versión guardada.',
        isError: false,
      );
      await refresh();
      return id;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      _fail('No se pudo guardar la orientación alimentaria.');
      return null;
    }
  }

  Future<bool> archive(String planId) async {
    if (!ref.read(appIdentityProvider).signedIn || state.busy) return false;

    state = state.copyWith(
      operation: NutritionGuidanceOperation.archiving,
      clearMessage: true,
      isError: false,
    );

    try {
      await _service.archiveGuidance(planId);
      state = state.copyWith(
        operation: NutritionGuidanceOperation.idle,
        message: 'Orientación archivada.',
        isError: false,
      );
      await refresh();
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo archivar la orientación alimentaria.');
      return false;
    }
  }

  void clearForClient(String clientUserId) {
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
    );
  }

  void _fail(String message) {
    state = state.copyWith(
      operation: NutritionGuidanceOperation.idle,
      message: message,
      isError: true,
    );
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
