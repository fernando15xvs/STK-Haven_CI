import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../support/nutrition_page_source.dart';

void main() {
  test('Food Vision only summarizes confirmed portions for authorized adults', () {
    final source=readNutritionPageSource(File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    final mutation=source.substring(source.indexOf('Future<void> _setMealConsumption('),
      source.indexOf('Future<void> _setHistoryFavorite('));
    expect(source,contains('if(widget.mobileCompactLayout && _hasAdultNumericAccess)'));
    expect(source,contains('FoodVisionDailySummary.forDay(_history,DateTime.now()'));
    expect(source,contains('adultAuthorized:_hasAdultNumericAccess'));
    expect(source,contains('No se calcula un saldo de calorías'));
    expect(mutation,contains('showDialog<double>'));
    expect(mutation,contains('if(portion==null)return;'));
    expect(mutation,contains('hasVerifiedAccess()'));
    expect(mutation,contains('_sameMutationSession(token)'));
    expect(mutation.indexOf('hasVerifiedAccess()'),
      lessThan(mutation.indexOf('_historyRepository.setConsumption(')));
    expect(mutation,contains('entry.consumedAt??DateTime.now()'));
    expect(source,contains('Editar porción consumida'));
    expect(source,contains('Quitar registro de consumo'));
  });

  test('correction rejects stale account or photo before reanalysis', () {
    final source=readNutritionPageSource(File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    final correction=source.substring(source.indexOf('Future<void> _editStructuredCorrection('),
      source.indexOf('Future<void> _pickAndAnalyze('));
    expect(correction,contains('_sameMutationSession(sessionAtStart)'));
    expect(correction,contains('epochAtStart!=_analysisEpoch'));
    expect(correction,contains('!identical(photo,_photo)'));
  });
}
