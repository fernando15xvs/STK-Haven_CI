// Default local entrypoint for the current Android-first development workflow.
//
// Production/validation builds use explicit targets:
//   Android -> lib/main_android.dart
//   iOS     -> lib/main_ios.dart
//
// Keeping this file as a thin Android alias preserves `flutter run` on the
// Windows/Android development setup without importing the iOS startup layer.
import 'main_android.dart' as android_app;

export 'shared/app/stk_haven_app.dart' show MyApp;

Future<void> main() => android_app.main();
