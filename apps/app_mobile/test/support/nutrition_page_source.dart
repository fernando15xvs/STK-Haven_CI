import 'dart:io';

/// Reassemble the presentation methods from their actual part files for
/// existing source-level contracts. No source is duplicated in the tests.
String readNutritionPageSource(File page) {
  var source = page.readAsStringSync();
  const parts = {
    '_buildEnergyPlanner': 'nutrition_energy_presentation.dart',
    '_buildFoodVision': 'nutrition_food_presentation.dart',
    '_buildHistory': 'nutrition_history_presentation.dart',
  };
  for (final entry in parts.entries) {
    final part = File('${page.parent.path}/${entry.value}').readAsStringSync();
    final declaration = '  Widget ${entry.key}(ColorScheme colors);';
    final begin = part.indexOf('  Widget ${entry.key}(');
    final end = part.lastIndexOf('\n}');
    if (!source.contains(declaration) || begin < 0 || end <= begin) {
      throw StateError('Nutrition presentation source layout changed: ${entry.key}');
    }
    source = source.replaceFirst(declaration, part.substring(begin, end));
  }
  return source;
}
