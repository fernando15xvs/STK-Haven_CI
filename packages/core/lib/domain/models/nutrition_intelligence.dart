import 'dart:typed_data';

enum EnergyGoal {
  maintenance,
  gradualLoss,
  gradualGain,
}

enum EnergyActivityLevel {
  sedentary,
  light,
  moderate,
  high,
  veryHigh,
}

enum EnergyEquationSex {
  female,
  male,
}

class AdultEnergyProfile {
  final int ageYears;
  final double heightCm;
  final double weightKg;
  final EnergyEquationSex equationSex;
  final EnergyActivityLevel activityLevel;
  final EnergyGoal goal;

  const AdultEnergyProfile({
    required this.ageYears,
    required this.heightCm,
    required this.weightKg,
    required this.equationSex,
    required this.activityLevel,
    required this.goal,
  });

  bool get isAdult => ageYears >= 18;
}

class EnergyEstimate {
  final int maintenanceLow;
  final int maintenanceHigh;
  final int targetLow;
  final int targetHigh;
  final int referenceBmr;
  final EnergyGoal goal;
  final String method;
  final List<String> assumptions;

  const EnergyEstimate({
    required this.maintenanceLow,
    required this.maintenanceHigh,
    required this.targetLow,
    required this.targetHigh,
    required this.referenceBmr,
    required this.goal,
    required this.method,
    required this.assumptions,
  });

  int get maintenanceMidpoint =>
      ((maintenanceLow + maintenanceHigh) / 2).round();

  int get targetMidpoint => ((targetLow + targetHigh) / 2).round();
}

enum FoodVisionConfidence {
  low,
  medium,
  high,
}

class NutritionPhoto {
  final Uint8List bytes;
  final String mimeType;
  final String name;

  const NutritionPhoto({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });
}

class FoodVisionItem {
  final String name;
  final String portionDescription;
  final int? gramsLow;
  final int? gramsHigh;
  final int? caloriesLow;
  final int? caloriesHigh;
  final double? proteinGramsLow;
  final double? proteinGramsHigh;
  final double? carbsGramsLow;
  final double? carbsGramsHigh;
  final double? fatGramsLow;
  final double? fatGramsHigh;
  final FoodVisionConfidence confidence;
  final String uncertaintyNote;

  const FoodVisionItem({
    required this.name,
    required this.portionDescription,
    this.gramsLow,
    this.gramsHigh,
    this.caloriesLow,
    this.caloriesHigh,
    this.proteinGramsLow,
    this.proteinGramsHigh,
    this.carbsGramsLow,
    this.carbsGramsHigh,
    this.fatGramsLow,
    this.fatGramsHigh,
    required this.confidence,
    this.uncertaintyNote = '',
  });

  factory FoodVisionItem.fromJson(Map<String, dynamic> json) {
    return FoodVisionItem(
      name: '${json['name'] ?? ''}',
      portionDescription: '${json['portionDescription'] ?? ''}',
      gramsLow: (json['gramsLow'] as num?)?.round(),
      gramsHigh: (json['gramsHigh'] as num?)?.round(),
      caloriesLow: (json['caloriesLow'] as num?)?.round(),
      caloriesHigh: (json['caloriesHigh'] as num?)?.round(),
      proteinGramsLow: (json['proteinGramsLow'] as num?)?.toDouble(),
      proteinGramsHigh: (json['proteinGramsHigh'] as num?)?.toDouble(),
      carbsGramsLow: (json['carbsGramsLow'] as num?)?.toDouble(),
      carbsGramsHigh: (json['carbsGramsHigh'] as num?)?.toDouble(),
      fatGramsLow: (json['fatGramsLow'] as num?)?.toDouble(),
      fatGramsHigh: (json['fatGramsHigh'] as num?)?.toDouble(),
      confidence: _enumByName(
            FoodVisionConfidence.values,
            json['confidence']?.toString(),
          ) ??
          FoodVisionConfidence.low,
      uncertaintyNote: '${json['uncertaintyNote'] ?? ''}',
    );
  }
}

class FoodVisionEstimate {
  final String dishName;
  final List<FoodVisionItem> items;
  final int? caloriesLow;
  final int? caloriesHigh;
  final double? proteinGramsLow;
  final double? proteinGramsHigh;
  final double? carbsGramsLow;
  final double? carbsGramsHigh;
  final double? fatGramsLow;
  final double? fatGramsHigh;
  final FoodVisionConfidence confidence;
  final bool numericNutritionAvailable;
  final List<String> assumptions;
  final List<String> questions;
  final String disclaimer;

  const FoodVisionEstimate({
    required this.dishName,
    required this.items,
    this.caloriesLow,
    this.caloriesHigh,
    this.proteinGramsLow,
    this.proteinGramsHigh,
    this.carbsGramsLow,
    this.carbsGramsHigh,
    this.fatGramsLow,
    this.fatGramsHigh,
    required this.confidence,
    required this.numericNutritionAvailable,
    this.assumptions = const <String>[],
    this.questions = const <String>[],
    required this.disclaimer,
  });

  factory FoodVisionEstimate.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return FoodVisionEstimate(
      dishName: '${json['dishName'] ?? ''}',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => FoodVisionItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <FoodVisionItem>[],
      caloriesLow: (json['caloriesLow'] as num?)?.round(),
      caloriesHigh: (json['caloriesHigh'] as num?)?.round(),
      proteinGramsLow: (json['proteinGramsLow'] as num?)?.toDouble(),
      proteinGramsHigh: (json['proteinGramsHigh'] as num?)?.toDouble(),
      carbsGramsLow: (json['carbsGramsLow'] as num?)?.toDouble(),
      carbsGramsHigh: (json['carbsGramsHigh'] as num?)?.toDouble(),
      fatGramsLow: (json['fatGramsLow'] as num?)?.toDouble(),
      fatGramsHigh: (json['fatGramsHigh'] as num?)?.toDouble(),
      confidence: _enumByName(
            FoodVisionConfidence.values,
            json['confidence']?.toString(),
          ) ??
          FoodVisionConfidence.low,
      numericNutritionAvailable:
          json['numericNutritionAvailable'] as bool? ?? false,
      assumptions: _stringList(json['assumptions']),
      questions: _stringList(json['questions']),
      disclaimer: '${json['disclaimer'] ?? ''}',
    );
  }
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw
      .whereType<Object>()
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
