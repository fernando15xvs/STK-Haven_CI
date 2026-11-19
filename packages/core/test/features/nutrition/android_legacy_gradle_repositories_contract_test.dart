import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Android plugin classpaths have Maven Central', () {
    final root = File('../../apps/app_mobile/android/build.gradle.kts')
        .readAsStringSync();

    // video_thumbnail still configures its own buildscript classpath with
    // JCenter. The app's ordinary repositories and pluginManagement are not
    // enough to resolve that legacy AGP 4.1 dependency graph.
    expect(
      RegExp(
        r'allprojects\s*\{\s*buildscript\s*\{\s*repositories\s*\{'
        r'\s*google\(\)\s*mavenCentral\(\)',
      ).hasMatch(root),
      isTrue,
      reason: 'Configure buildscript Maven Central before legacy Flutter plugins',
    );

    // The CI mirror workaround for Maven 429 stays separate from app code.
    final ci = File('../../ci/public/flutter_ci.yml').readAsStringSync();
    expect(ci, contains('Route Maven Central dependencies through Google mirror'));
    expect(ci, contains('ci/public/maven_central_mirror.gradle'));
  });
}
