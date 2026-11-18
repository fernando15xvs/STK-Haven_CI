import 'dart:typed_data';

import 'package:core/features/nutrition/application/food_vision_mobile_image_guard.dart';
import 'package:core/features/nutrition/data/food_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List bytes(List<int> data) => Uint8List.fromList(data);
  final jpg = bytes([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
  final png = bytes([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 1, 2, 3,
  ]);
  final webp = bytes([
    0x52, 0x49, 0x46, 0x46, 4, 0, 0, 0,
    0x57, 0x45, 0x42, 0x50, 0x56, 0x50,
  ]);

  test('accepts supported signatures with an accurate MIME type', () {
    expect(FoodVisionMobileImageGuard.detectMimeType(jpg), 'image/jpeg');
    expect(FoodVisionMobileImageGuard.detectMimeType(png), 'image/png');
    expect(FoodVisionMobileImageGuard.detectMimeType(webp), 'image/webp');
    expect(FoodVisionMobileImageGuard.errorFor(jpg, 'IMAGE/JPEG'), isNull);
    expect(FoodVisionMobileImageGuard.errorFor(png, 'image/png'), isNull);
    expect(FoodVisionMobileImageGuard.errorFor(webp, 'image/webp'), isNull);
  });

  test('does not mislabel iPhone HEIC or truncated/malicious file as JPEG', () {
    final heic = bytes([
      0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70,
      0x68, 0x65, 0x69, 0x63, 0, 0, 0, 0,
    ]);
    expect(FoodVisionMobileImageGuard.detectMimeType(heic), isNull);
    for (final invalid in [heic, bytes([0xff, 0xd8]), bytes([1, 2, 3])]) {
      expect(FoodVisionMobileImageGuard.errorFor(invalid, 'image/jpeg'),
          isNotNull);
    }
    expect(FoodVisionMobileImageGuard.errorFor(jpg, 'image/png'), isNotNull);
    expect(FoodVisionMobileImageGuard.errorFor(jpg, 'image/heic'), isNotNull);
  });

  test('rejects empty and oversized uploads before any network request', () {
    expect(FoodVisionMobileImageGuard.maxImageBytes,
        FoodVisionService.maxImageBytes);
    expect(FoodVisionMobileImageGuard.errorFor(bytes([]), 'image/jpeg'),
        contains('4 MB'));
    final tooLarge = Uint8List(FoodVisionMobileImageGuard.maxImageBytes + 1)
      ..setRange(0, jpg.length, jpg);
    expect(FoodVisionMobileImageGuard.errorFor(tooLarge, 'image/jpeg'),
        contains('4 MB'));
  });
}
