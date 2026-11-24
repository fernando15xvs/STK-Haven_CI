import 'dart:io';

import 'package:test/test.dart';

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

    // The canonical repository keeps a CI workflow TEMPLATE, while the
    // public CI mirror executes .github/workflows/flutter_ci.yml. Checking
    // the template for a UI step name incorrectly fails when the live
    // workflow is intentionally ahead. Check the actual shared init script.
    final mirrorScript = File('../../ci/public/maven_central_mirror.gradle')
        .readAsStringSync();
    expect(mirrorScript, contains('preferMirror(project.buildscript.repositories)'));
    expect(mirrorScript, contains('preferMirror(project.repositories)'));
    expect(mirrorScript, contains('settings.pluginManagement.repositories'));
    expect(mirrorScript, contains('maven-central.storage-download.googleapis.com'));
    expect(mirrorScript, contains('repo.maven.apache.org/maven2/'));
  });
}
