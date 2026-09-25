import 'dart:convert';
import 'dart:typed_data';

import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodVisionService {
  static const int maxImageBytes = 4 * 1024 * 1024;
  static const Set<String> supportedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  final SupabaseClient client;

  const FoodVisionService(this.client);

  Future<FoodVisionEstimate> analyze({
    required Uint8List imageBytes,
    required String mimeType,
    required bool adultNumericNutrition,
    String? dishHint,
  }) async {
    if (imageBytes.isEmpty || imageBytes.length > maxImageBytes) {
      throw const FoodVisionException(
        'La imagen debe pesar entre 1 byte y 4 MB.',
      );
    }

    final normalizedMime = mimeType.trim().toLowerCase();
    if (!supportedMimeTypes.contains(normalizedMime)) {
      throw const FoodVisionException(
        'Usa una foto JPG, PNG o WebP.',
      );
    }

    final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'food-vision-ai',
        body: <String, dynamic>{
          'imageBase64': base64Encode(imageBytes),
          'mimeType': normalizedMime,
          'adultNumericNutrition': adultNumericNutrition,
          if (dishHint != null && dishHint.trim().isNotEmpty)
            'dishHint': dishHint.trim(),
        },
      );
    } on FunctionException catch (error) {
      throw FoodVisionException(
        _messageFromPayload(error.details) ??
            error.reasonPhrase ??
            'No se pudo analizar el plato en este momento.',
      );
    }

    if (response.status < 200 || response.status >= 300) {
      throw FoodVisionException(
        _messageFromPayload(response.data) ??
            'No se pudo analizar el plato en este momento.',
      );
    }

    if (response.data is! Map) {
      throw const FoodVisionException(
        'La respuesta del análisis no tiene un formato válido.',
      );
    }

    final payload = Map<String, dynamic>.from(response.data as Map);
    final rawEstimate = payload['estimate'];
    if (rawEstimate is! Map) {
      throw const FoodVisionException(
        'El análisis no devolvió una estimación válida.',
      );
    }

    return FoodVisionEstimate.fromJson(
      Map<String, dynamic>.from(rawEstimate),
    );
  }

  String? _messageFromPayload(dynamic payload) {
    if (payload is Map) {
      final message = payload['error'] ?? payload['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return null;
  }
}

class FoodVisionException implements Exception {
  final String message;

  const FoodVisionException(this.message);

  @override
  String toString() => message;
}
