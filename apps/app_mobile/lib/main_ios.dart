import 'platform/ios/ios_platform_services.dart';
import 'shared/bootstrap/mobile_app_bootstrap.dart';

Future<void> main() {
  return bootstrapMobileApp(
    initializePlatformServices: initializeIosPlatformServices,
  );
}
