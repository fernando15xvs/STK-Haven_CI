import 'package:core/domain/models/nutrition_intelligence.dart';

class NutritionHistoryEntry {
  final String id;
  final DateTime analyzedAt;
  final String dishHint;
  final FoodVisionEstimate estimate;
  /// Optional local favorite. No photo is stored.
  final bool isFavorite;
  /// Explicit consumption event, never inferred from analysis date.
  final DateTime? consumedAt;
  /// Fraction of the original analyzed plate explicitly confirmed by the user.
  /// Null means unavailable or invalid; never assume a fraction for new data.
  final double? consumedFraction;

  static bool validFraction(double? value) =>
      value != null && value.isFinite && value > 0 && value <= 1;

  const NutritionHistoryEntry({
    required this.id,
    required this.analyzedAt,
    required this.dishHint,
    required this.estimate,
    this.isFavorite = false,
    this.consumedAt,
    this.consumedFraction = 1.0,
  });

  NutritionHistoryEntry copyWith({bool? isFavorite, DateTime? consumedAt, bool clearConsumption=false, double? consumedFraction}) =>
      NutritionHistoryEntry(
        id:id,analyzedAt:analyzedAt,dishHint:dishHint,
        estimate:estimate,isFavorite:isFavorite??this.isFavorite,
        consumedAt:clearConsumption?null:consumedAt??this.consumedAt,
        consumedFraction:clearConsumption?null:consumedFraction??this.consumedFraction,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'analyzedAt': analyzedAt.toIso8601String(),
        'dishHint': dishHint,
        'estimate': estimate.toJson(),
        'isFavorite': isFavorite,
        'consumedAt': consumedAt?.toIso8601String(),
        'consumedFraction': consumedAt == null || !validFraction(consumedFraction)
            ? null : consumedFraction,
      };

  factory NutritionHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawEstimate = json['estimate'];
    if (rawEstimate is! Map) {
      throw const FormatException('nutrition history estimate missing');
    }
    final consumedAt = DateTime.tryParse(json['consumedAt']?.toString() ?? '');
    final rawFraction = json['consumedFraction'];
    // Older confirmations explicitly meant the whole analyzed portion.
    final fraction = !json.containsKey('consumedFraction') ? 1.0
        : rawFraction is num ? rawFraction.toDouble() : null;
    return NutritionHistoryEntry(
      id: json['id']?.toString() ?? '',
      analyzedAt: DateTime.parse(json['analyzedAt']?.toString() ?? ''),
      dishHint: json['dishHint']?.toString() ?? '',
      isFavorite: json['isFavorite'] == true,
      consumedAt: consumedAt,
      consumedFraction: consumedAt != null && validFraction(fraction) ? fraction : null,
      estimate: FoodVisionEstimate.fromJson(
        Map<String, dynamic>.from(rawEstimate),
      ),
    );
  }
}
