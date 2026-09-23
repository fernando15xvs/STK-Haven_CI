import 'package:flutter/foundation.dart';

/// Central source of truth for features that vary by platform.
///
/// UI and services should query these capabilities instead of scattering
/// platform checks throughout the application.
class PlatformCapabilities {
  const PlatformCapabilities._({
    required this.isWeb,
    required this.isAndroid,
    required this.isIOS,
    required this.supportsBackgroundTasks,
    required this.supportsExactAlarms,
    required this.supportsLocalNotifications,
    required this.supportsNativeFileSystem,
    required this.supportsNativeFileSharing,
    required this.supportsSqlite,
  });

  final bool isWeb;
  final bool isAndroid;
  final bool isIOS;
  final bool supportsBackgroundTasks;
  final bool supportsExactAlarms;
  final bool supportsLocalNotifications;
  final bool supportsNativeFileSystem;
  final bool supportsNativeFileSharing;
  final bool supportsSqlite;

  static PlatformCapabilities get current {
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return PlatformCapabilities._(
      isWeb: kIsWeb,
      isAndroid: android,
      isIOS: ios,
      supportsBackgroundTasks: android || ios,
      supportsExactAlarms: android,
      supportsLocalNotifications: android || ios,
      supportsNativeFileSystem: android || ios,
      supportsNativeFileSharing: android || ios,
      supportsSqlite: android || ios,
    );
  }
}
