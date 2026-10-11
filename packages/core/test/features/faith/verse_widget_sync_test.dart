import 'package:core/features/faith/services/verse_widget_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stk_haven/verse_widget');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('publishes the canonical verse and local date to the platform', () async {
    await VerseWidgetSync.publish(
      text: '  Paz para hoy  ',
      reference: 'Juan 14:27',
      date: DateTime(2026, 10, 11),
    );
    expect(calls, hasLength(1));
    expect(calls.single.method, 'publish');
    expect(calls.single.arguments, {
      'text': 'Paz para hoy',
      'reference': 'Juan 14:27',
      'date': '2026-10-11',
    });
  });

  test('does not expose blank verses and clears cached verse on opt out', () async {
    await VerseWidgetSync.publish(
      text: '   ', reference: 'Test 1:1', date: DateTime(2026),
    );
    expect(calls, isEmpty);
    await VerseWidgetSync.clear();
    expect(calls.single.method, 'clear');
  });

  test('caps widget snapshot fields to safe lengths', () async {
    await VerseWidgetSync.publish(
      text: 'a' * 1500, reference: 'b' * 150,
      date: DateTime(2026, 5, 4),
    );
    final args = Map<String, String>.from(calls.single.arguments as Map);
    expect(args['text']!.length, 1200);
    expect(args['reference']!.length, 120);
  });
}
