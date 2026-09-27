import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact web navigation renders only the active root page', () {
    final source = File(
      'lib/core/layout/web_layout.dart',
    ).readAsStringSync();

    final compactStart =
        source.indexOf('if (compact) {');
    final desktopStart =
        source.indexOf('final content = _content(effectiveSelectedIndex);');

    expect(compactStart, greaterThanOrEqualTo(0));
    expect(desktopStart, greaterThan(compactStart));

    final compactBlock = source.substring(compactStart, desktopStart);
    expect(compactBlock, contains('_pages[effectiveSelectedIndex]'));
    expect(compactBlock, contains('RepaintBoundary'));
    expect(compactBlock, isNot(contains('_content(effectiveSelectedIndex)')));
    expect(
      RegExp(r'\bIndexedStack\s*\(').hasMatch(compactBlock),
      isFalse,
    );
  });

  test('desktop keeps lazy retained tabs', () {
    final source = File(
      'lib/core/layout/web_layout.dart',
    ).readAsStringSync();

    expect(source, contains('IndexedStack('));
    expect(source, contains('_visited.contains(index)'));
  });
}
