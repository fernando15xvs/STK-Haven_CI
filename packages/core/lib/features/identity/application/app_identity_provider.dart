import 'dart:async';

import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/identity/application/app_identity_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final appIdentityProvider =
    NotifierProvider<AppIdentityNotifier, AppIdentityState>(
  AppIdentityNotifier.new,
);

class AppIdentityNotifier extends Notifier<AppIdentityState> {
  StreamSubscription<AuthState>? _authSubscription;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  AppIdentityState build() {
    _authSubscription?.cancel();
    _authSubscription = _client.auth.onAuthStateChange.listen((event) {
      _applyUser(event.session?.user);
    });
    ref.onDispose(() => _authSubscription?.cancel());

    return _stateForUser(_client.auth.currentUser);
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (state.busy) return false;
    state = state.copyWith(
      operation: AppIdentityOperation.signingIn,
      clearMessage: true,
      isError: false,
    );

    try {
      await _clearAnonymousSessionIfNeeded();
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (!_isPermanent(user)) {
        throw const AuthException('No se pudo iniciar sesión.');
      }

      state = _stateForUser(user).copyWith(
        message: 'Sesión iniciada.',
      );
      return true;
    } on AuthException catch (error) {
      _fail(_friendlyAuthMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo iniciar sesión. Verifica tu conexión.');
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    if (state.busy) return false;
    state = state.copyWith(
      operation: AppIdentityOperation.signingUp,
      clearMessage: true,
      isError: false,
    );

    try {
      await _clearAnonymousSessionIfNeeded();
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('No se pudo crear la cuenta.');
      }

      final permanentSession =
          response.session != null && _isPermanent(user);
      state = _stateForUser(
        permanentSession ? user : null,
      ).copyWith(
        email: user.email,
        message: permanentSession
            ? 'Cuenta creada y sesión iniciada.'
            : 'Cuenta creada. Confirma tu correo y luego inicia sesión.',
      );
      return true;
    } on AuthException catch (error) {
      _fail(_friendlyAuthMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo crear la cuenta. Verifica tu conexión.');
      return false;
    }
  }

  Future<void> signOut() async {
    if (state.busy) return;
    state = state.copyWith(
      operation: AppIdentityOperation.signingOut,
      clearMessage: true,
      isError: false,
    );
    try {
      await _client.auth.signOut();
      state = const AppIdentityState(
        message: 'Sesión cerrada.',
      );
    } catch (_) {
      _fail('No se pudo cerrar la sesión.');
    }
  }

  Future<bool> syncOwnProfile({
    String? displayName,
    required Set<UserCapability> capabilities,
  }) async {
    final user = _client.auth.currentUser;
    if (!_isPermanent(user)) {
      _fail('Se necesita una cuenta permanente.');
      return false;
    }
    if (state.busy) return false;

    state = state.copyWith(
      operation: AppIdentityOperation.syncingProfile,
      clearMessage: true,
      isError: false,
    );

    try {
      await _client.rpc(
        'stk_sync_own_profile',
        params: <String, dynamic>{
          'p_display_name': displayName?.trim(),
          'p_capabilities':
              AppIdentityRules.capabilityNames(capabilities),
        },
      );
      await refreshOwnProfile();
      state = state.copyWith(
        message: 'Perfil de cuenta sincronizado.',
        isError: false,
      );
      return true;
    } on PostgrestException {
      _fail(
        'El perfil cloud todavía no está disponible. '
        'La migración de Roadmap 3 debe estar aplicada primero.',
      );
      return false;
    } catch (_) {
      _fail('No se pudo sincronizar el perfil de cuenta.');
      return false;
    }
  }

  Future<bool> refreshOwnProfile() async {
    final user = _client.auth.currentUser;
    if (!_isPermanent(user)) return false;

    state = state.copyWith(
      operation: AppIdentityOperation.refreshingProfile,
      clearMessage: true,
      isError: false,
    );

    try {
      final profile = await _client
          .from('stk_user_profiles')
          .select('display_name')
          .eq('user_id', user!.id)
          .maybeSingle();
      final rows = await _client
          .from('stk_user_capabilities')
          .select('capability')
          .eq('user_id', user.id);

      state = state.copyWith(
        sessionKind: AppSessionKind.permanent,
        userId: user.id,
        email: user.email,
        operation: AppIdentityOperation.idle,
        remoteProfileAvailable: profile != null,
        displayName: profile?['display_name']?.toString(),
        clearDisplayName: profile?['display_name'] == null,
        remoteCapabilities:
            AppIdentityRules.parseCapabilityRows(rows),
        isError: false,
      );
      return true;
    } on PostgrestException {
      state = state.copyWith(
        operation: AppIdentityOperation.idle,
        remoteProfileAvailable: false,
        remoteCapabilities: const <UserCapability>{},
        clearDisplayName: true,
        isError: false,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        operation: AppIdentityOperation.idle,
        isError: false,
      );
      return false;
    }
  }

  Future<void> _clearAnonymousSessionIfNeeded() async {
    final current = _client.auth.currentUser;
    if (current != null && !_isPermanent(current)) {
      await _client.auth.signOut();
    }
  }

  void _applyUser(User? user) {
    final next = _stateForUser(user);
    state = next.copyWith(
      message: state.message,
      isError: state.isError,
    );
  }

  AppIdentityState _stateForUser(User? user) {
    final kind = AppIdentityRules.classifySession(
      hasUser: user != null,
      email: user?.email,
    );
    return AppIdentityState(
      sessionKind: kind,
      userId: user?.id,
      email: kind == AppSessionKind.permanent ? user?.email : null,
    );
  }

  bool _isPermanent(User? user) {
    return AppIdentityRules.classifySession(
          hasUser: user != null,
          email: user?.email,
        ) ==
        AppSessionKind.permanent;
  }

  void _fail(String message) {
    state = state.copyWith(
      operation: AppIdentityOperation.idle,
      message: message,
      isError: true,
    );
  }

  String _friendlyAuthMessage(AuthException error) {
    final raw = error.message.toLowerCase();
    if (raw.contains('invalid login') || raw.contains('invalid credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (raw.contains('already registered') || raw.contains('already exists')) {
      return 'Ese correo ya tiene una cuenta.';
    }
    if (raw.contains('password')) {
      return 'La contraseña no cumple los requisitos de Supabase.';
    }
    return error.message;
  }
}
