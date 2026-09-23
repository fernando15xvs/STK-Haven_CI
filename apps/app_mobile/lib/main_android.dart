import 'platform/android/android_platform_services.dart';
import 'shared/bootstrap/mobile_app_bootstrap.dart';

Future<void> main() {
  return bootstrapMobileApp(
    initializePlatformServices: initializeAndroidPlatformServices,
  );
}
