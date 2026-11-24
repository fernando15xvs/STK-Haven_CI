import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/platform/storage/mobile_core_preferences.dart';

/// Tests use the same on-device preference adapter as Mobile bootstrap.
/// Individual test cases can still provide SharedPreferences mock values.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  installMobileCorePreferences();
  await testMain();
}
