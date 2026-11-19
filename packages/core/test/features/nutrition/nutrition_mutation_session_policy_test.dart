import 'dart:io';

import 'package:core/features/nutrition/application/nutrition_mutation_session_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool allowed(String owner, String? token, String activeOwner,
      String? activeToken) =>
    NutritionMutationSessionPolicy.isCurrent(
      initialOwnerId: owner,
      initialAccessToken: token,
      currentOwnerId: activeOwner,
      currentAccessToken: activeToken,
    );

  test('stable authenticated session may finish a local mutation', () {
    expect(allowed('account-a', 'token-A', 'account-a', 'token-A'), isTrue);
  });

  test('re-login with identical UID rejects an old dialog action', () {
    expect(allowed('account-a', 'token-A', 'account-a', 'token-B'), isFalse);
  });

  test('token refresh invalidates in-flight local mutations', () {
    expect(allowed('account-a', 'token-A', 'account-a', 'refresh-A'), isFalse);
  });

  test('switching or signing out does not mutate the previous account', () {
    expect(allowed('account-a', 'token-A', 'account-b', 'token-B'), isFalse);
    expect(allowed('account-a', 'token-A', 'guest', null), isFalse);
    expect(allowed('guest', null, 'account-a', 'token-A'), isFalse);
  });

  test('logged-in users cannot mutate data with a missing session', () {
    expect(allowed('account-a', null, 'account-a', null), isFalse);
    expect(allowed('account-a', '', 'account-a', ''), isFalse);
    expect(allowed('account-a', 'token-A', 'account-a', null), isFalse);
  });

  test('guest local history stays available without authentication', () {
    expect(allowed('guest', null, 'guest', null), isTrue);
    expect(allowed('guest', 'unexpected', 'guest', 'unexpected'), isFalse);
  });
  test('all local nutrition history/plan dialogs reject late session changes',
      () {
    final source = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();

    String section(String start, String next) {
      final from = source.indexOf(start);
      expect(from, greaterThanOrEqualTo(0), reason: start);
      final to = source.indexOf(next, from + start.length);
      expect(to, greaterThan(from), reason: next);
      return source.substring(from, to);
    }

    final guardedSections = <(String, String)>[
      ('Future<void> _setHistoryFavorite(', 'String _historySubtitle('),
      ('Future<void> _saveCurrentEstimate(', 'Future<void> _importLegacyHistory('),
      ('Future<void> _importLegacyHistory(', 'Future<void> _deleteHistoryEntry('),
      ('Future<void> _deleteHistoryEntry(', 'Future<void> _confirmClearHistory('),
      ('Future<void> _confirmClearHistory(', 'void _calculateEnergy('),
      ('Future<void> _togglePlanPaused(', 'Future<void> _chooseReviewInterval('),
      ('Future<void> _chooseReviewInterval(', 'Future<void> _confirmRemoveEnergyPlan('),
      ('Future<void> _confirmRemoveEnergyPlan(', 'Future<void> _showAdultMacroGuide('),
      ('Future<void> _saveEnergyPlan(', 'Future<void> _editStructuredCorrection('),
      ('Future<void> _analyzePhoto(', 'class _FoodVisionCorrectionDialog'),
    ];

    for (final (start, next) in guardedSections) {
      final method = section(start, next);
      expect(method, contains('final sessionAtStart = _currentNutritionToken'),
          reason: start);
      expect(method, contains('_sameMutationSession(sessionAtStart)'),
          reason: 'Session identity guard missing: $start');
    }
    final photoPicker = section(
      'Future<void> _pickAndAnalyze(', 'Future<void> _analyzePhoto(',
    );
    expect(photoPicker, contains('final pickSessionAtStart = _currentNutritionToken'));
    expect(photoPicker, contains('_sameMutationSession(pickSessionAtStart)'));

    expect(source, contains('NutritionMutationSessionPolicy.isCurrent('));
    // No bearer token goes into a persistent model or account-specific key.
    expect(source, contains('currentAccessToken: _currentNutritionToken'));
    expect(source, isNot(contains('storeToken(')));
  });

  test('deleting history checks the original session after confirmation',
      () {
    final source = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _confirmClearHistory()');
    final end = source.indexOf('void _calculateEnergy()', start);
    final method = source.substring(start, end);
    expect(method.indexOf('_sameMutationSession(sessionAtStart)',
        method.indexOf('await showDialog<bool>')),
        lessThan(method.indexOf('await _historyRepository.clear()')));
  });

}
