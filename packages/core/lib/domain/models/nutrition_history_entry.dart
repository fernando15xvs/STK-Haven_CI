import 'package:core/domain/models/nutrition_intelligence.dart';

class NutritionHistoryEntry {
  final String id;
  final DateTime analyzedAt;
  final String dishHint;
  final FoodVisionEstimate estimate;
  /// Optional local favorite only. No photo or daily count is stored.
  final bool isFavorite;

  const NutritionHistoryEntry({
    required this.id,
    required this.analyzedAt,
    required this.dishHint,
    required this.estimate,
    this.isFavorite = false,
  });

  NutritionHistoryEntry copyWith({bool? isFavorite}) =>
      NutritionHistoryEntry(
        id:id,analyzedAt:analyzedAt,dishHint:dishHint,
        estimate:estimate,isFavorite:isFavorite??this.isFavorite,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'analyzedAt': analyzedAt.toIso8601String(),
        'dishHint': dishHint,
        'estimate': estimate.toJson(),
        'isFavorite': isFavorite,
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
      isFavorite: json['isFavorite'] == true,
      estimate: FoodVisionEstimate.fromJson(
        Map<String, dynamic>.from(rawEstimate),
      ),
    );
  }
}
