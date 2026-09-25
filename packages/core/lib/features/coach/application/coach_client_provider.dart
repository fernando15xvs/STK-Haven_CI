import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/coach/application/coach_progress_provider.dart';
import 'package:core/features/coach/application/coach_task_provider.dart';
import 'package:core/features/nutrition/application/nutrition_guidance_provider.dart';
import 'package:core/features/coach/data/coach_client_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  return CoachClientService(Supabase.instance.client);
});

final coachClientProvider =
    NotifierProvider<CoachClientNotifier, CoachClientState>(
  CoachClientNotifier.new,
);

class CoachClientNotifier extends Notifier<CoachClientState> {
  late final CoachClientService _service;

  @override
  CoachClientState build() {
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

    state = state.copyWith(
      operation: CoachClientOperation.loading,
      clearMessage: true,
      isError: false,
    );

    try {
      final relationships = await _service.getRelationships();
      state = state.copyWith(
        relationships: relationships,
        operation: CoachClientOperation.idle,
        isError: false,
      );
      return true;
    } on PostgrestException {
      _fail(
        'Coach/Client todavía no está disponible en el backend activo.',
      );
      return false;
    } catch (_) {
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
    final ready = await _prepareCoachAccount();
    if (!ready) return null;

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
      state = state.copyWith(
        operation: CoachClientOperation.idle,
        invitationCode: code,
        message:
            'Invitación creada. El código solo se muestra en este dispositivo.',
        isError: false,
      );
      return code;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      _fail('No se pudo crear la invitación.');
      return null;
    }
  }

  Future<CoachInvitationPreview?> previewInvitation(String code) async {
    if (state.busy || code.trim().isEmpty) return null;
    if (!_requirePermanentAccount()) return null;

    state = state.copyWith(
      operation: CoachClientOperation.previewingInvitation,
      clearInvitationPreview: true,
      clearMessage: true,
      isError: false,
    );

    try {
      final preview = await _service.previewInvitation(code);
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
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      _fail('No se pudo revisar la invitación.');
      return null;
    }
  }

  Future<bool> acceptInvitation(String code) async {
    if (state.busy || code.trim().isEmpty) return false;
    if (!_requirePermanentAccount()) return false;

    state = state.copyWith(
      operation: CoachClientOperation.acceptingInvitation,
      clearMessage: true,
      isError: false,
    );

    try {
      await _service.acceptInvitation(code);
      final relationships = await _service.getRelationships();
      state = state.copyWith(
        relationships: relationships,
        operation: CoachClientOperation.idle,
        clearInvitationPreview: true,
        message: 'Entrenador vinculado.',
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo aceptar la invitación.');
      return false;
    }
  }

  Future<bool> setPermissions({
    required String relationshipId,
    required Set<CoachPermission> permissions,
  }) async {
    if (state.busy || !_requirePermanentAccount()) return false;
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
      final relationships = await _service.getRelationships();
      state = state.copyWith(
        relationships: relationships,
        operation: CoachClientOperation.idle,
        message: 'Permisos actualizados.',
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudieron actualizar los permisos.');
      return false;
    }
  }

  Future<bool> revokeRelationship(String relationshipId) async {
    if (state.busy || !_requirePermanentAccount()) return false;
    state = state.copyWith(
      operation: CoachClientOperation.revoking,
      clearMessage: true,
      isError: false,
    );

    try {
      final previous = _relationshipById(relationshipId);
      await _service.revokeRelationship(relationshipId);
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
      final relationships = await _service.getRelationships();
      state = state.copyWith(
        relationships: relationships,
        operation: CoachClientOperation.idle,
        message: 'Acceso revocado.',
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo revocar la relación.');
      return false;
    }
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

    final synced = await ref
        .read(appIdentityProvider.notifier)
        .syncOwnProfile(capabilities: capabilities);
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
