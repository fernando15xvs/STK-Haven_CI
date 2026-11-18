import 'dart:typed_data';

/// An offline preflight for mobile Food Vision. Magic bytes must agree with
/// the advertised MIME type before a preview, consent or remote request.
/// The actual codec/provider may still reject malformed image data.
class FoodVisionMobileImageGuard {
  const FoodVisionMobileImageGuard._();

  static const int maxImageBytes = 4 * 1024 * 1024;

  static String? detectMimeType(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4e && bytes[3] == 0x47 &&
        bytes[4] == 0x0d && bytes[5] == 0x0a &&
        bytes[6] == 0x1a && bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  static String? errorFor(Uint8List bytes, String claimedMimeType) {
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      return 'Elige una fotografía de hasta 4 MB.';
    }
    final actual = detectMimeType(bytes);
    if (actual == null || actual != claimedMimeType.trim().toLowerCase()) {
      return 'Esta foto no es JPG, PNG o WebP compatible. '
          'Prueba con otra imagen.';
    }
    return null;
  }
}
