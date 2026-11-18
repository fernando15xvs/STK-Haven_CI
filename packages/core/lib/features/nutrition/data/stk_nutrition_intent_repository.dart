import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A descriptive selection, not an energy plan, adult grant or training goal.
/// Lives in the existing backup-aware metadata box; no implicit writes on read.
class StkNutritionIntentRepository {
  StkNutritionIntentRepository(this._metadata, {required String? ownerId})
      : _scope = ownerId == null ? 'guest' : 'account:${Uri.encodeComponent(ownerId)}' {
    if (ownerId != null && ownerId.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Account id is empty');
    }
  }

  static const int formatVersion = 1;
  static const String keyPrefix = 'stk_nutrition_intent_v1:';
  final Box<dynamic> _metadata;
  final String _scope;

  String get storageKey => '$keyPrefix$_scope';

  StkNutritionIntent? read() {
    final raw = _metadata.get(storageKey);
    if (raw is! Map ||
        raw['version'] != formatVersion ||
        raw['scope'] != _scope) {
      return null;
    }
    final name = raw['intent'];
    if (name is! String) return null;
    for (final intent in StkNutritionIntent.values) {
      if (intent.name == name) return intent;
    }
    return null;
  }

  /// Never changes an existing adult calorie plan, water, steps or measures.
  Future<void> save(StkNutritionIntent intent) => _metadata.put(storageKey, {
        'version': formatVersion,
        'scope': _scope,
        'intent': intent.name,
      });

  Future<void> clear() => _metadata.delete(storageKey);
}
