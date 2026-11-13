import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud restore guards active workouts before and after network wait', () {
    final source = File(
      'lib/features/sync/application/cloud_sync_provider.dart',
    ).readAsStringSync();
    final method = source.split('Future<bool> restoreFromCloud() async {').last
        .split('void _invalidateRestoredState()').first;
    expect(RegExp('activeWorkoutProvider').allMatches(method), hasLength(2));
    expect(method.indexOf('activeWorkoutProvider'),
        lessThan(method.indexOf('CloudSyncOperation.downloading')));
    expect(method.lastIndexOf('activeWorkoutProvider'),
        lessThan(method.indexOf('await _backupService.restoreBackup(')));
  });
}
