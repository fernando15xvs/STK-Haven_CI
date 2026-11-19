import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final corePath =
      '../../packages/core/lib/features/nutrition/presentation/pages/'
      'nutrition_intelligence_page.dart';
  final mobilePath = 'lib/features/nutrition/presentation/pages/'
      'nutrition_intelligence_page_mobile.dart';
  String core() => File(corePath).readAsStringSync();
  String mobile() => File(mobilePath).readAsStringSync();

  test('food-first overview is exclusively opted in by the mobile route', () {
    final page = core();
    final wrapper = mobile();
    expect(wrapper, contains('mobileCompactLayout: true'));
    expect(page, contains('this.mobileCompactLayout = false'));
    final mobileStart = page.indexOf('if (widget.mobileCompactLayout) {',
        page.indexOf('Widget build(BuildContext context) {'));
    final legacyStart = page.indexOf(
      "appBar: AppBar(title: const Text('Nutrición Inteligente'))",
      mobileStart,
    );
    expect(mobileStart, greaterThanOrEqualTo(0));
    expect(legacyStart, greaterThan(mobileStart));
    final mobileOverview = page.substring(mobileStart, legacyStart);
    final food = mobileOverview.indexOf('_buildFoodVision(colors)');
    final goal = mobileOverview.indexOf('StkMobileNutritionGoalSelector(');
    final plan = mobileOverview.indexOf('_buildMobileAdultPlan(colors)');
    final history = mobileOverview.indexOf('_buildMobileHistorySummary(colors)');
    expect(food, greaterThanOrEqualTo(0));
    expect(food, lessThan(goal));
    expect(goal, lessThan(plan));
    expect(plan, lessThan(history));
    expect(mobileOverview, contains("'nutrition_mobile_overview'"));
    expect(mobileOverview, contains('canPop: !_showMobileHistory'));
    expect(mobileOverview, contains('onPopInvokedWithResult:'));
    expect(mobileOverview, contains('nutrition_mobile_history_appbar'));
    expect(mobileOverview, contains('StkMobileNutritionAccessPanel('));
    expect(mobileOverview, isNot(contains('_HeroCard(colors: colors)')));
    expect(mobileOverview, isNot(contains('_buildWellnessSummary(colors)')));
    expect(mobileOverview, isNot(contains('StkAgeAwareNutritionGoals(')));

    final legacy = page.substring(legacyStart);
    expect(legacy, contains('_HeroCard(colors: colors)'));
    expect(legacy, contains('_buildWellnessSummary(colors)'));
    expect(legacy, contains('StkAgeAwareNutritionGoals('));
    expect(legacy, contains('_buildHistory(colors)'));
  });

  test('a selected photo is NOT uploaded before a separate mobile action',
      () {
    final page = core();
    final picker = page.substring(
      page.indexOf('Future<void> _pickAndAnalyze('),
      page.indexOf('Future<void> _analyzePhoto(', 
          page.indexOf('Future<void> _pickAndAnalyze(')),
    );
    expect(picker, contains('await widget.photoPicker(source)'));
    expect(picker, contains('FoodVisionService.maxImageBytes'));
    expect(picker, contains('if (!widget.mobileCompactLayout) '
        'await _analyzePhoto(photo);'));
    expect(page, contains("ValueKey('nutrition_mobile_take_photo')"));
    expect(page, contains("ValueKey('nutrition_mobile_choose_photo')"));
    expect(page, contains("ValueKey('nutrition_mobile_analyze_photo')"));
    expect(page, contains("ValueKey('nutrition_mobile_discard_photo')"));
    expect(page, contains("ValueKey('nutrition_mobile_photo_details')"));
    expect(page, contains("Text('Añadir detalles (opcional)')"));
    expect(page, contains('_dishHintFromHistory'));
    expect(page, contains('if (!_dishHintFromHistory) _dishHintController.clear()'));
    // The picker must reject stale completions after discarding, logging out
    // or opening a newer image; keep account isolation in the same guard.
    expect(picker, contains('if (!mounted || photo == null ||'));
    expect(picker, contains('!_sameMutationSession(pickSessionAtStart)'));
    expect(picker, contains('pickEpoch != _analysisEpoch'));
    expect(picker, contains('FoodVisionMobileImageGuard.errorFor(photo.bytes, photo.mimeType)'));
    expect(page, contains("label: const Text('Descartar')"));
    // The consent gate must be triggered on the analysis action, before
    // sending any bytes to the external AI provider.
    final analyze = page.substring(
      page.indexOf('Future<void> _analyzePhoto('),
      page.indexOf('class _FoodVisionCorrectionDialog'),
    );
    final consent = analyze.indexOf('final allowed = await checkConsent()');
    final remote = analyze.indexOf('FoodVisionService(');
    expect(consent, greaterThanOrEqualTo(0));
    expect(remote, greaterThan(consent));
    expect(analyze, contains('if (!allowed)'));
    expect(mobile(), contains('requestPhotoAnalysisConsent: _requestPhotoConsent'));
  });

  test('history stays per-owner, local and voluntarily saved', () {
    final page = core();
    final mobileStart = page.indexOf('if (widget.mobileCompactLayout) {',
        page.indexOf('Widget build(BuildContext context) {'));
    final overview = page.substring(mobileStart, page.indexOf(
      "appBar: AppBar(title: const Text('Nutrición Inteligente'))", mobileStart,
    ));
    expect(overview, contains("title: Text(_showMobileHistory ? 'Mis análisis'"));
    expect(overview, contains('_buildHistory(colors)'));
    expect(overview, contains('_buildMobileHistorySummary(colors)'));
    expect(page, contains('if (widget.mobileCompactLayout) return content;'));
    expect(page, contains('NutritionHistoryRepository('));
    expect(page, contains('ownerId:ownerId'));
    expect(page, contains('_historyRepository.save('));
    expect(page, contains('_historyRepository.delete(id)'));
    expect(page, contains('_historyRepository.clear()'));
    expect(page, contains('_historyRepository.importLegacyEntries()'));
    expect(page, contains("const Text('Guardar resultado local')"));
    expect(page, contains('await _historyRepository.setFavorite('));
    expect(page, contains('if (widget.mobileCompactLayout) _showMobileHistory = false;'));
  });

  test('numeric safeguards and wellness data remain intact', () {
    final page = core();
    expect(page, contains('nutritionAccessStateProvider('));
    expect(page, contains('if(estimate.numericNutritionAvailable)'));
    expect(page, contains('final stillVerified=await NutritionAdultAccessService('));
    expect(page, contains('hasVerifiedAccess()'));
    expect(page, contains('if(!stillVerified || !_hasAdultNumericAccess)'));
    expect(page, contains('epoch!=_analysisEpoch'));
    expect(page, contains('_sameMutationSession(sessionAtStart)'));
    expect(page, contains('NutritionMutationSessionPolicy.isCurrent('));
    expect(page, contains('Future<void> _reviewWaterTarget() async'));
    expect(page, contains('Future<void> _reviewStepTarget() async'));
    expect(page, contains('Future<void> _saveEnergyPlan() async'));
    expect(page, contains('Future<void> _confirmClearHistory() async'));
  });
}
