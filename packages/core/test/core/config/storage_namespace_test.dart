import 'package:core/core/config/storage_namespace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty namespace preserves stable storage names', () {
    expect(
      StorageNamespace.scope('historyBox_v2', namespace: ''),
      'historyBox_v2',
    );
  });

  test('preview namespace isolates Hive box names', () {
    expect(
      StorageNamespace.scope(
        'historyBox_v2',
        namespace: 'roadmap3_preview',
      ),
      'roadmap3_preview__historyBox_v2',
    );
  });

  test('namespace is normalized before being applied', () {
    expect(
      StorageNamespace.scope(
        'metadataBox',
        namespace: ' Roadmap 3 Preview! ',
      ),
      'roadmap_3_preview__metadataBox',
    );
  });
}
