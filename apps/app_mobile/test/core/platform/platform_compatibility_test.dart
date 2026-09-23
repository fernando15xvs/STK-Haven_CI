import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'package:gym_tracker/core/platform/platform_capabilities.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('PlatformCapabilities', () {
    test('enables Android-only capabilities only on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final capabilities = PlatformCapabilities.current;

      expect(capabilities.isAndroid, isTrue);
      expect(capabilities.isIOS, isFalse);
      expect(capabilities.supportsLocalNotifications, isTrue);
      expect(capabilities.supportsBackgroundTasks, isTrue);
      expect(capabilities.supportsExactAlarms, isTrue);
      expect(capabilities.supportsSqlite, isTrue);
    });

    test('does not enable exact alarms on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final capabilities = PlatformCapabilities.current;

      expect(capabilities.isIOS, isTrue);
      expect(capabilities.isAndroid, isFalse);
      expect(capabilities.supportsLocalNotifications, isTrue);
      expect(capabilities.supportsBackgroundTasks, isTrue);
      expect(capabilities.supportsExactAlarms, isFalse);
    });
  });

  group('MobileContentFrame', () {
    testWidgets('limits wide layouts to 600 logical pixels', (tester) async {
      const contentKey = Key('content');

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 1000,
            height: 800,
            child: MobileContentFrame(
              child: ColoredBox(
                key: contentKey,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(contentKey)).width, 600);
    });

    testWidgets('uses all available width on a 320 pixel phone', (tester) async {
      const contentKey = Key('content');

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 320,
              height: 640,
              child: MobileContentFrame(
                child: ColoredBox(
                  key: contentKey,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(contentKey)).width, 320);
    });
  });
}
