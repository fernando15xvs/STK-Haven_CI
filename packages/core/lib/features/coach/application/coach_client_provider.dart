import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/coach/application/coach_progress_provider.dart';
import 'package:core/features/coach/application/coach_task_provider.dart';
import 'package:core/features/coach/application/coach_checkin_provider.dart';
import 'package:core/features/coach/application/coach_program_assignment_provider.dart';
import 'package:core/features/coach_pro/application/coach_pro_client_detail_provider.dart';
import 'package:core/features/coach/application/coach_measurement_provider.dart';
import 'package:core/features/nutrition/application/nutrition_guidance_provider.dart';
import 'package:core/features/coach/data/coach_client_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase/supabase.dart';

enum CoachClientOperation {
  idle,
  loading,
  creatingInvitation,
  previewingInvitation,
  acceptingInvitation,
  updatingPermissions,
  revoking,
}

class CoachClientState {
  final List<CoachClientRelationship> relationships;
  final CoachClientOperation operation;
  final String? invitationCode;
  final CoachInvitationPreview? invitationPreview;
  final String? message;
  final bool isError;

  const CoachClientState({
    this.relationships = const <CoachClientRelationship>[],
    this.operation = CoachClientOperation.idle,
    this.invitationCode,
    this.invitationPreview,
    this.message,
    this.isError = false,
  });

  bool get busy => operation != CoachClientOperation.idle;

  CoachClientState copyWith({
    List<CoachClientRelationship>? relationships,
    CoachClientOperation? operation,
    String? invitationCode,
    bool clearInvitationCode = false,
    CoachInvitationPreview? invitationPreview,
    bool clearInvitationPreview = false,
    String? message,
    bool clearMessage = false,
    bool? isError,
  }) {
    return CoachClientState(
      relationships: relationships ?? this.relationships,
      operation: operation ?? this.operation,
      invitationCode: clearInvitationCode
          ? null
          : (invitationCode ?? this.invitationCode),
      invitationPreview: clearInvitationPreview
          ? null
          : (invitationPreview ?? this.invitationPreview),
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

final coachClientServiceProvider = Provider<CoachClientService>((ref) {
  return CoachClientService(CoreSupabaseClient.client);
});

final coachClientProvider =
    NotifierProvider<CoachClientNotifier, CoachClientState>(
  CoachClientNotifier.new,
);

class CoachClientNotifier extends Notifier<CoachClientState> {
  late CoachClientService _service;
  int _generation = 0;
  bool _current(int generation) => ref.mounted && generation == _generation;

  @override
  CoachClientState build() {
    ref.watch(appIdentityProvider.select((value) => (value.signedIn, value.userId)));
    _generation++;
    ref.onDispose(() => _generation++);
    _service = ref.watch(coachClientServiceProvider);
    return const CoachClientState();
  }

  Future<bool> refreshRelationships() async {
    final identity = ref.read(appIdentityProvider);
    if (!identity.signedIn) {
      state = const CoachClientState(
        message: 'Inicia sesión para usar funciones compartidas.',
      );
      return false;
    }
    if (state.busy) return false;

    final previous = state.relationships;
    final generation = ++_generation;
    state = state.copyWith(
      operation: CoachClientOperation.loading,
      relationships: const [],
      clearMessage: true,
      isError: false,
    );

    try {
      final relationships = await _service.getRelationships();
      if (!_current(generation)) return false;
      if (_permissionsChanged(previous, relationships)) _invalidateShared();
      state = state.copyWith(
        relationships: relationships,
        operation: CoachClientOperation.idle,
        isError: false,
      );
      return true;
    } on PostgrestException {
      if (!_current(generation)) return false;
      _invalidateShared();
      _fail(
        'Coach/Client todavía no está disponible en el backend activo.',
      );
      return false;
    } catch (_) {
      if (!_current(generation)) return false;
      _invalidateShared();
      _fail('No se pudieron cargar las relaciones de entrenador.');
      return false;
    }
  }

  Future<String?> createInvitation({
    Set<CoachPermission> permissions = const {
      CoachPermission.viewWorkouts,
      CoachPermission.viewProgress,
      CoachPermission.assignPrograms,
      CoachPermission.comment,
    },
    int expiresInHours = 168,
  }) async {
    if (state.busy) return null;
    final preparingGeneration = _generation;
    final ready = await _prepareCoachAccount();
    if (!ready || !_current(preparingGeneration) || state.busy) return null;

    final generation = ++_generation;
    state = state.copyWith(
      operation: CoachClientOperation.creatingInvitation,
      clearInvitationCode: true,
      clearMessage: true,
      isError: false,
    );

    try {
      final code = await _service.createInvitation(
        permissions: permissions,
        expiresInHours: expiresInHours,
      );
      if (!_current(generation)) return null;
      state = state.copyWith(
        operation: CoachClientOperation.idle,
        invitationCode: code,
        message:
            'Invitación creada. El código solo se muestra en este dispositivo.',
        isError: false,
      );
      return code;
    } on PostgrestException catch (error) {
      if (!_current(generation)) return null;
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      if (!_current(generation)) return null;
      _fail('No se pudo crear la invitación.');
      return null;
    }
  }

  Future<CoachInvitationPreview?> previewInvitation(String code) async {
    if (state.busy || code.trim().isEmpty) return null;
    if (!_requirePermanentAccount()) return null;

    final generation = ++_generation;
    state = state.copyWith(
      operation: CoachClientOperation.previewingInvitation,
      clearInvitationPreview: true,
      clearMessage: true,
      isError: false,
    );

    try {
      final preview = await _service.previewInvitation(code);
      if (!_current(generation)) return null;
      if (preview == null) {
        _fail('La invitación no existe, expiró o ya fue utilizada.');
        return null;
      }
      state = state.copyWith(
        operation: CoachClientOperation.idle,
        invitationPreview: preview,
        isError: false,
      );
      return preview;
    } on PostgrestException catch (error) {
      if (!_current(generation)) return null;
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      if (!_current(generation)) return null;
      _fail('No se pudo revisar la invitación.');
      return null;
    }
  }

  Future<bool> acceptInvitation(String code) async {
    if (state.busy || code.trim().isEmpty) return false;
    if (!_requirePermanentAccount()) return false;

    final generation = ++_generation;
    state = state.copyWith(
      operation: CoachClientOperation.acceptingInvitation,
      clearMessage: true,
      isError: false,
    );

    try {
      await _service.acceptInvitation(code);
      if (!_current(generation)) return false;
      _invalidateShared();
      final relationships = await _service.getRelationships();
      if (!_current(generation)) return false;
      state = state.copyWith(
        relationships: relationships,
        operation: CoachClientOperation.idle,
        clearInvitationPreview: true,
        message: 'Entrenador vinculado.',
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      if (!_current(generation)) return false;
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      if (!_current(generation)) return false;
      _fail('No se pudo aceptar la invitación.');
      return false;
    }
  }

  Future<bool> setPermissions({
    required String relationshipId,
    required Set<CoachPermission> permissions,
  }) async {
    if (state.busy || !_requirePermanentAccount()) return false;
    final generation = ++_generation;
    state = state.copyWith(
      operation: CoachClientOperation.updatingPermissions,
      clearMessage: true,
      isError: false,
    );

    try {
      await _service.setPermissions(
        relationshipId: relationshipId,
        permissions: permissions,
      );
      if (!_current(generation)) return false;
      final previous = _relationshipById(relationshipId);
      if (previous != null) {
        ref
            .read(coachProgressProvider.notifier)
            .clearClient(previous.clientUserId);
        ref
            .read(coachTaskProvider.notifier)
            .clearClient(previous.clientUserId);
        ref
            .read(nutritionGuidanceProvider.notifier)
            .clearForClient(previous.clientUserId);
      }
      _invalidateShared();
      final relationships = await _service.getRelationships();
      if (!_current(generation)) return false;
      state = state.copyWith(
        relationships: relationships,
        operation: CoachClientOperation.idle,
        message: 'Permisos actualizados.',
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      if (!_current(generation)) return false;
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      if (!_current(generation)) return false;
      _fail('No se pudieron actualizar los permisos.');
      return false;
    }
  }

  Future<bool> revokeRelationship(String relationshipId) async {
    if (state.busy || !_requirePermanentAccount()) return false;
    final generation = ++_generation;
    state = state.copyWith(
      operation: CoachClientOperation.revoking,
      clearMessage: true,
      isError: false,
    );

    try {
      final previous = _relationshipById(relationshipId);
      await _service.revokeRelationship(relationshipId);
      if (!_current(generation)) return false;
      if (previous != null) {
        ref
            .read(coachProgressProvider.notifier)
            .clearClient(previous.clientUserId);
        ref
            .read(coachTaskProvider.notifier)
            .clearClient(previous.clientUserId);
        ref
            .read(nutritionGuidanceProvider.notifier)
            .clearForClient(previous.clientUserId);
      }
      _invalidateShared();
      final relationships = await _service.getRelationships();
      if (!_current(generation)) return false;
      state = state.copyWith(
        relationships: relationships,
        operation: CoachClientOperation.idle,
        message: 'Acceso revocado.',
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      if (!_current(generation)) return false;
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      if (!_current(generation)) return false;
      _fail('No se pudo revocar la relación.');
      return false;
    }
  }

  bool _permissionsChanged(List<CoachClientRelationship> before, List<CoachClientRelationship> after) {
    if (before.length != after.length) return true;
    for (final old in before) {
      final match = after.where((item) => item.id == old.id);
      if (match.length != 1 || match.single.status != old.status ||
          match.single.permissions.length != old.permissions.length ||
          !match.single.permissions.containsAll(old.permissions)) return true;
    }
    return false;
  }
  void _invalidateShared() {
    ref.invalidate(coachProgressProvider);
    ref.invalidate(coachTaskProvider);
    ref.invalidate(coachCheckinProvider);
    ref.invalidate(coachProgramAssignmentsProvider);
    ref.invalidate(nutritionGuidanceProvider);
    ref.invalidate(nutritionGuidanceDetailProvider);
    ref.invalidate(coachProClientDetailProvider);
    ref.invalidate(coachMeasurementProvider);
  }

  CoachClientRelationship? _relationshipById(String id) {
    for (final relationship in state.relationships) {
      if (relationship.id == id) return relationship;
    }
    return null;
  }

  Future<bool> _prepareCoachAccount() async {
    final identity = ref.read(appIdentityProvider);
    if (!identity.signedIn) {
      _fail('Inicia sesión con una cuenta permanente para usar modo entrenador.');
      return false;
    }

    final profile = ref.read(userExperienceProfileProvider).value;
    final capabilities =
        profile?.capabilities ?? const <UserCapability>{UserCapability.athlete};
    if (!capabilities.contains(UserCapability.coach)) {
      _fail('Activa el modo Entrenador en Personalización primero.');
      return false;
    }

    final generation = _generation;
    final synced = await ref
        .read(appIdentityProvider.notifier)
        .syncOwnProfile(capabilities: capabilities);
    if (!_current(generation)) return false;
    if (!synced) {
      _fail(
        ref.read(appIdentityProvider).message ??
            'No se pudo sincronizar el perfil de entrenador.',
      );
      return false;
    }
    return true;
  }

  bool _requirePermanentAccount() {
    if (ref.read(appIdentityProvider).signedIn) return true;
    _fail('Inicia sesión con una cuenta permanente.');
    return false;
  }

  void _fail(String message) {
    state = state.copyWith(
      operation: CoachClientOperation.idle,
      message: message,
      isError: true,
    );
  }

  String _databaseMessage(PostgrestException error) {
    final raw = error.message.toLowerCase();
    if (raw.contains('coach pro entitlement required')) {
      return 'Coach Pro necesita una autorización de desarrollo vigente.';
    }
    if (raw.contains('client limit') || raw.contains('client capacity')) {
      return 'Se alcanzó el límite de clientes del plan.';
    }
    if (raw.contains('coach capability required')) {
      return 'La cuenta todavía no tiene capacidad de entrenador sincronizada.';
    }
    if (raw.contains('invalid or expired')) {
      return 'La invitación no existe, expiró o ya fue utilizada.';
    }
    if (raw.contains('permanent authenticated account required')) {
      return 'Se necesita una cuenta permanente.';
    }
    return 'La función Coach/Client no está disponible todavía en el backend activo.';
  }
}
