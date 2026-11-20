import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud restore guards active workouts before and after network wait', () {
    final source = File(
      'lib/features/sync/application/cloud_sync_provider.dart',
    ).readAsStringSync();
    final method = source.split('Future<bool> restoreFromCloud() async {').last
        .split('void _invalidateRestoredState()').first;
    expect(RegExp('activeWorkoutProvider').allMatches(method), hasLength(3));
    final downloading = method.indexOf('CloudSyncOperation.downloading');
    final restoreCall = method.indexOf('await _backupService.restoreBackup(');
    expect(method.indexOf('activeWorkoutProvider'), lessThan(downloading));
    expect(method.indexOf('activeWorkoutProvider', downloading),
        lessThan(restoreCall));
    expect(method.lastIndexOf('activeWorkoutProvider'),
        greaterThan(restoreCall));
  });
  test('metadata refresh cannot release an in-flight cloud operation', () {
    final source = File(
      'lib/features/sync/application/cloud_sync_provider.dart',
    ).readAsStringSync();
    final refresh = source
        .split('Future<void> refreshRemoteMetadata() async {').last
        .split('Future<bool> uploadCurrentDevice() async {').first;
    expect(refresh, contains('if (state.busy) return;'));
    expect(refresh, contains('_sameCloudSession(identity.userId!, token)'));
    expect(refresh, contains('|| state.busy) return;'));
    expect(refresh, isNot(contains('operation: CloudSyncOperation.idle')));
  });

  test('cloud backup binds uploads and restores to the original token', () {
    final source = File(
      'lib/features/sync/application/cloud_sync_provider.dart',
    ).readAsStringSync();
    final upload = source
        .split('Future<bool> uploadCurrentDevice() async {').last
        .split('Future<bool> restoreFromCloud() async {').first;
    final restore = source
        .split('Future<bool> restoreFromCloud() async {').last
        .split('void _invalidateRestoredState()').first;
    expect(source, contains('previous?.userId != next.userId'));
    expect(source, contains('clearRemoteUpdatedAt: true'));
    expect(source, contains('_client.auth.currentUser?.id == userId'));
    expect(source, contains('_client.auth.currentSession?.accessToken == token'));
    expect(upload, contains('final token = _client.auth.currentSession?.accessToken;'));
    expect(RegExp('_sameCloudSession\\(userId, token\\)').allMatches(upload),
        hasLength(3));
    expect(restore, contains('_sameCloudSession(userId, token)'));
    expect(restore, contains('allowCommit: () =>'));
    expect(restore, contains('ref.read(activeWorkoutProvider).session == null'));
  });

  test('native rest notification initialization retries after plugin failure',
      () {
    final notifications = File(
      'lib/core/services/workout_notification_service.dart',
    ).readAsStringSync();
    expect(notifications, contains('_initialize().onError((error, stack)'));
    expect(notifications, contains('_initialization = null;'));
    expect(notifications, contains('Error.throwWithStackTrace('));
    expect(notifications, contains("error ?? StateError('No se pudo inicializar las notificaciones.')"));
    expect(notifications, contains('audioAttributesUsage: AudioAttributesUsage.notificationEvent'));
  });

}
