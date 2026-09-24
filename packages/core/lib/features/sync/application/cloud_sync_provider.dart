import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:core/core/services/backup_activity_service.dart';
import 'package:core/core/services/backup_service.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';

enum CloudSyncOperation { idle, signingIn, signingUp, uploading, downloading }

class CloudSyncState {
  final bool signedIn;
  final String? email;
  final DateTime? remoteUpdatedAt;
  final CloudSyncOperation operation;
  final String? message;
  final bool isError;

  const CloudSyncState({
    this.signedIn = false,
    this.email,
    this.remoteUpdatedAt,
    this.operation = CloudSyncOperation.idle,
    this.message,
    this.isError = false,
  });

  bool get busy => operation != CloudSyncOperation.idle;

  CloudSyncState copyWith({
    bool? signedIn,
    String? email,
    bool clearEmail = false,
    DateTime? remoteUpdatedAt,
    bool clearRemoteUpdatedAt = false,
    CloudSyncOperation? operation,
    String? message,
    bool clearMessage = false,
    bool? isError,
  }) {
    return CloudSyncState(
      signedIn: signedIn ?? this.signedIn,
      email: clearEmail ? null : (email ?? this.email),
      remoteUpdatedAt: clearRemoteUpdatedAt
          ? null
          : (remoteUpdatedAt ?? this.remoteUpdatedAt),
      operation: operation ?? this.operation,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

final cloudSyncProvider = NotifierProvider<CloudSyncNotifier, CloudSyncState>(
  CloudSyncNotifier.new,
);

class CloudSyncNotifier extends Notifier<CloudSyncState> {
  static const _table = 'stk_haven_cloud_backups';
  final BackupService _backupService = BackupService();

  SupabaseClient get _client => Supabase.instance.client;

  bool _hasPermanentAccount(User? user) {
    return user != null && (user.email?.trim().isNotEmpty ?? false);
  }

  @override
  CloudSyncState build() {
    final user = _client.auth.currentUser;
    Future.microtask(refreshRemoteMetadata);
    return CloudSyncState(
      signedIn: _hasPermanentAccount(user),
      email: _hasPermanentAccount(user) ? user?.email : null,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.busy) return;
    state = state.copyWith(
      operation: CloudSyncOperation.signingIn,
      clearMessage: true,
      isError: false,
    );
    try {
      if (!_hasPermanentAccount(_client.auth.currentUser) &&
          _client.auth.currentUser != null) {
        await _client.auth.signOut();
      }
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (!_hasPermanentAccount(user)) {
        throw const AuthException('No se pudo iniciar sesión.');
      }
      state = CloudSyncState(
        signedIn: true,
        email: user!.email,
        message: 'Sesión de sincronización iniciada.',
      );
      await refreshRemoteMetadata();
    } on AuthException catch (error) {
      _fail(_friendlyAuthMessage(error));
    } catch (_) {
      _fail('No se pudo iniciar sesión. Verifica tu conexión.');
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    if (state.busy) return;
    state = state.copyWith(
      operation: CloudSyncOperation.signingUp,
      clearMessage: true,
      isError: false,
    );
    try {
      if (!_hasPermanentAccount(_client.auth.currentUser) &&
          _client.auth.currentUser != null) {
        await _client.auth.signOut();
      }
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) throw const AuthException('No se pudo crear la cuenta.');
      final hasSession = response.session != null;
      state = CloudSyncState(
        signedIn: hasSession && _hasPermanentAccount(user),
        email: user.email,
        message: hasSession
            ? 'Cuenta creada. Ya puedes sincronizar.'
            : 'Cuenta creada. Confirma tu correo y luego inicia sesión.',
      );
      if (hasSession) await refreshRemoteMetadata();
    } on AuthException catch (error) {
      _fail(_friendlyAuthMessage(error));
    } catch (_) {
      _fail('No se pudo crear la cuenta. Verifica tu conexión.');
    }
  }

  Future<void> signOut() async {
    if (state.busy) return;
    await _client.auth.signOut();
    ref.read(settingsProvider.notifier).setCloudSyncEnabled(false);
    state = const CloudSyncState(message: 'Sesión cerrada.');
  }

  Future<void> refreshRemoteMetadata() async {
    final user = _client.auth.currentUser;
    if (!_hasPermanentAccount(user)) return;
    try {
      final row = await _client
          .from(_table)
          .select('updated_at')
          .eq('user_id', user!.id)
          .maybeSingle();
      final updatedRaw = row?['updated_at']?.toString();
      state = state.copyWith(
        signedIn: true,
        email: user.email,
        remoteUpdatedAt:
            updatedRaw == null ? null : DateTime.tryParse(updatedRaw)?.toLocal(),
        clearRemoteUpdatedAt: updatedRaw == null,
        operation: CloudSyncOperation.idle,
      );
    } catch (_) {
      // Metadata refresh is best-effort. Explicit upload/download surfaces errors.
    }
  }

  Future<bool> uploadCurrentDevice() async {
    final user = _client.auth.currentUser;
    if (!_hasPermanentAccount(user)) {
      _fail('Inicia sesión antes de subir una copia.');
      return false;
    }
    if (state.busy) return false;

    state = state.copyWith(
      operation: CloudSyncOperation.uploading,
      clearMessage: true,
      isError: false,
    );
    try {
      final backupString = _backupService.createBackup();
      final decoded = jsonDecode(backupString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Backup local inválido.');
      }

      final now = DateTime.now().toUtc();
      await _client.from(_table).upsert({
        'user_id': user!.id,
        'backup_payload': decoded,
        'schema_version': BackupService.currentBackupSchemaVersion,
        'updated_at': now.toIso8601String(),
      });
      ref.read(settingsProvider.notifier).setCloudSyncEnabled(true);
      state = state.copyWith(
        signedIn: true,
        email: user.email,
        remoteUpdatedAt: now.toLocal(),
        operation: CloudSyncOperation.idle,
        message: 'Copia de este dispositivo guardada en la nube.',
        isError: false,
      );
      return true;
    } catch (_) {
      _fail('No se pudo subir la copia. Verifica internet y configuración de Supabase.');
      return false;
    }
  }

  Future<bool> restoreFromCloud() async {
    final user = _client.auth.currentUser;
    if (!_hasPermanentAccount(user)) {
      _fail('Inicia sesión antes de restaurar desde la nube.');
      return false;
    }
    if (state.busy) return false;

    state = state.copyWith(
      operation: CloudSyncOperation.downloading,
      clearMessage: true,
      isError: false,
    );
    try {
      final row = await _client
          .from(_table)
          .select('backup_payload, updated_at')
          .eq('user_id', user!.id)
          .maybeSingle();
      if (row == null || row['backup_payload'] == null) {
        _fail('Todavía no existe una copia en la nube para esta cuenta.');
        return false;
      }

      final backupString = jsonEncode(row['backup_payload']);
      final validation = _backupService.validateBackup(backupString);
      if (!validation.isValid || validation.parsedData == null) {
        _fail(validation.errorMessage ?? 'La copia remota no es válida.');
        return false;
      }

      await _backupService.restoreBackup(
        validation.parsedData!,
        schemaVersion:
            validation.schemaVersion ?? BackupService.currentBackupSchemaVersion,
      );
      await TrainingProgramRepository.fromHive().hydrateFromBackupMetadata();
      await BackupActivityService.markRestored(source: 'nube');
      _invalidateRestoredState();

      final updatedRaw = row['updated_at']?.toString();
      ref.read(settingsProvider.notifier).setCloudSyncEnabled(true);
      state = state.copyWith(
        signedIn: true,
        email: user.email,
        remoteUpdatedAt:
            updatedRaw == null ? null : DateTime.tryParse(updatedRaw)?.toLocal(),
        operation: CloudSyncOperation.idle,
        message: 'Copia de la nube restaurada en este dispositivo.',
        isError: false,
      );
      return true;
    } catch (_) {
      _fail('No se pudo restaurar la copia remota. Tus datos locales no se modificaron si la restauración falló.');
      return false;
    }
  }

  void _invalidateRestoredState() {
    ref.invalidate(settingsProvider);
    ref.invalidate(userExperienceProfileProvider);
    ref.invalidate(routineListProvider);
    ref.invalidate(exerciseListProvider);
    ref.invalidate(workoutHistoryProvider);
    ref.invalidate(personalRecordRepositoryProvider);
    ref.invalidate(bodyMeasurementProvider);
    ref.invalidate(trainingProgramListProvider);
  }

  void _fail(String message) {
    state = state.copyWith(
      operation: CloudSyncOperation.idle,
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
