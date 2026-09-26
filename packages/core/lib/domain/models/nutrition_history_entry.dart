import 'package:core/domain/models/nutrition_intelligence.dart';

class NutritionHistoryEntry {
  final String id;
  final DateTime analyzedAt;
  final String dishHint;
  final FoodVisionEstimate estimate;

  const NutritionHistoryEntry({
    required this.id,
    required this.analyzedAt,
    required this.dishHint,
    required this.estimate,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'analyzedAt': analyzedAt.toIso8601String(),
        'dishHint': dishHint,
        'estimate': estimate.toJson(),
      };

  factory NutritionHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawEstimate = json['estimate'];
    if (rawEstimate is! Map) {
      throw const FormatException('nutrition history estimate missing');
    }
    return NutritionHistoryEntry(
      id: json['id']?.toString() ?? '',
      analyzedAt: DateTime.parse(json['analyzedAt']?.toString() ?? ''),
      dishHint: json['dishHint']?.toString() ?? '',
      estimate: FoodVisionEstimate.fromJson(
        Map<String, dynamic>.from(rawEstimate),
      ),
    );
  }
}
