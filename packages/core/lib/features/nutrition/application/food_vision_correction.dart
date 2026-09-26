import 'package:core/domain/models/nutrition_intelligence.dart';

class FoodVisionCorrectionItem {
  final String name;
  final String portionDescription;

  const FoodVisionCorrectionItem({
    required this.name,
    required this.portionDescription,
  });

  FoodVisionCorrectionItem copyWith({
    String? name,
    String? portionDescription,
  }) {
    return FoodVisionCorrectionItem(
      name: name ?? this.name,
      portionDescription: portionDescription ?? this.portionDescription,
    );
  }
}

class FoodVisionCorrectionDraft {
  final String dishName;
  final List<FoodVisionCorrectionItem> items;
  final String extraContext;

  const FoodVisionCorrectionDraft({
    required this.dishName,
    required this.items,
    this.extraContext = '',
  });

  factory FoodVisionCorrectionDraft.fromEstimate(
    FoodVisionEstimate estimate, {
    String extraContext = '',
  }) {
    return FoodVisionCorrectionDraft(
      dishName: estimate.dishName,
      items: estimate.items
          .map(
            (item) => FoodVisionCorrectionItem(
              name: item.name,
              portionDescription: item.portionDescription,
            ),
          )
          .toList(growable: false),
      extraContext: extraContext,
    );
  }

  String toReanalysisContext() {
    final buffer = StringBuffer();
    final normalizedDish = dishName.trim();
    if (normalizedDish.isNotEmpty) {
      buffer.writeln('Nombre corregido del plato: $normalizedDish.');
    }

    if (items.isNotEmpty) {
      buffer.writeln('Ingredientes/porciones corregidos por el usuario:');
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final name = item.name.trim();
        final portion = item.portionDescription.trim();
        if (name.isEmpty && portion.isEmpty) continue;
        buffer.write('${i + 1}. ${name.isEmpty ? 'Ingrediente' : name}');
        if (portion.isNotEmpty) buffer.write(' — $portion');
        buffer.writeln('.');
      }
    }

    final context = extraContext.trim();
    if (context.isNotEmpty) {
      buffer.writeln('Contexto adicional del usuario: $context.');
    }

    return buffer.toString().trim();
  }
}
