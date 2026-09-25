enum NutritionGuidanceStatus {
  active,
  archived,
}

class NutritionGuidanceItem {
  final String id;
  final int position;
  final String foodExample;
  final String servingNote;

  const NutritionGuidanceItem({
    this.id = '',
    required this.position,
    required this.foodExample,
    this.servingNote = '',
  });

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'food_example': foodExample.trim(),
        'serving_note': servingNote.trim(),
      };

  factory NutritionGuidanceItem.fromJson(Map<String, dynamic> json) {
    return NutritionGuidanceItem(
      id: '${json['id'] ?? ''}',
      position: (json['position'] as num?)?.toInt() ?? 0,
      foodExample: '${json['food_example'] ?? ''}',
      servingNote: '${json['serving_note'] ?? ''}',
    );
  }
}

class NutritionGuidanceMeal {
  final String id;
  final int position;
  final String name;
  final String timingLabel;
  final String notes;
  final List<NutritionGuidanceItem> items;

  const NutritionGuidanceMeal({
    this.id = '',
    required this.position,
    required this.name,
    this.timingLabel = '',
    this.notes = '',
    this.items = const <NutritionGuidanceItem>[],
  });

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'name': name.trim(),
        'timing_label': timingLabel.trim(),
        'notes': notes.trim(),
        'items': [
          for (final item in items) item.toPayload(),
        ],
      };

  factory NutritionGuidanceMeal.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return NutritionGuidanceMeal(
      id: '${json['id'] ?? ''}',
      position: (json['position'] as num?)?.toInt() ?? 0,
      name: '${json['name'] ?? ''}',
      timingLabel: '${json['timing_label'] ?? ''}',
      notes: '${json['notes'] ?? ''}',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => NutritionGuidanceItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <NutritionGuidanceItem>[],
    );
  }
}

class NutritionGuidanceSummary {
  final String id;
  final String relationshipId;
  final String coachUserId;
  final String clientUserId;
  final NutritionGuidanceStatus status;
  final int currentVersion;
  final String title;
  final DateTime updatedAt;

  const NutritionGuidanceSummary({
    required this.id,
    required this.relationshipId,
    required this.coachUserId,
    required this.clientUserId,
    required this.status,
    required this.currentVersion,
    required this.title,
    required this.updatedAt,
  });

  bool isCoach(String? userId) => userId != null && coachUserId == userId;

  bool isClient(String? userId) => userId != null && clientUserId == userId;

  factory NutritionGuidanceSummary.fromJson(Map<String, dynamic> json) {
    return NutritionGuidanceSummary(
      id: '${json['id'] ?? ''}',
      relationshipId: '${json['relationship_id'] ?? ''}',
      coachUserId: '${json['coach_user_id'] ?? ''}',
      clientUserId: '${json['client_user_id'] ?? ''}',
      status: _enumByName(
            NutritionGuidanceStatus.values,
            json['status']?.toString(),
          ) ??
          NutritionGuidanceStatus.archived,
      currentVersion: (json['current_version'] as num?)?.toInt() ?? 1,
      title: '${json['title'] ?? ''}',
      updatedAt:
          DateTime.tryParse('${json['updated_at']}') ?? DateTime.now(),
    );
  }
}

class NutritionGuidancePlan {
  static const String defaultScopeNotice =
      'Orientación alimentaria general. No prescribe calorías, macros, '
      'pérdida de peso ni dietas terapéuticas y no sustituye atención '
      'médica o nutricional profesional.';

  final String id;
  final String relationshipId;
  final String coachUserId;
  final String clientUserId;
  final NutritionGuidanceStatus status;
  final int currentVersion;
  final int version;
  final String title;
  final String overview;
  final String hydrationNotes;
  final String generalNotes;
  final String scopeNotice;
  final DateTime createdAt;
  final List<NutritionGuidanceMeal> meals;

  const NutritionGuidancePlan({
    required this.id,
    required this.relationshipId,
    required this.coachUserId,
    required this.clientUserId,
    required this.status,
    required this.currentVersion,
    required this.version,
    required this.title,
    this.overview = '',
    this.hydrationNotes = '',
    this.generalNotes = '',
    this.scopeNotice = defaultScopeNotice,
    required this.createdAt,
    this.meals = const <NutritionGuidanceMeal>[],
  });

  Map<String, dynamic> toEditorPayload() => <String, dynamic>{
        'title': title.trim(),
        'overview': overview.trim(),
        'hydration_notes': hydrationNotes.trim(),
        'general_notes': generalNotes.trim(),
        'scope_notice': scopeNotice.trim().isEmpty
            ? defaultScopeNotice
            : scopeNotice.trim(),
        'meals': [
          for (final meal in meals) meal.toPayload(),
        ],
      };

  factory NutritionGuidancePlan.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'];
    return NutritionGuidancePlan(
      id: '${json['id'] ?? ''}',
      relationshipId: '${json['relationship_id'] ?? ''}',
      coachUserId: '${json['coach_user_id'] ?? ''}',
      clientUserId: '${json['client_user_id'] ?? ''}',
      status: _enumByName(
            NutritionGuidanceStatus.values,
            json['status']?.toString(),
          ) ??
          NutritionGuidanceStatus.archived,
      currentVersion: (json['current_version'] as num?)?.toInt() ?? 1,
      version: (json['version'] as num?)?.toInt() ?? 1,
      title: '${json['title'] ?? ''}',
      overview: '${json['overview'] ?? ''}',
      hydrationNotes: '${json['hydration_notes'] ?? ''}',
      generalNotes: '${json['general_notes'] ?? ''}',
      scopeNotice: '${json['scope_notice'] ?? defaultScopeNotice}',
      createdAt:
          DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      meals: rawMeals is List
          ? rawMeals
              .whereType<Map>()
              .map(
                (meal) => NutritionGuidanceMeal.fromJson(
                  Map<String, dynamic>.from(meal),
                ),
              )
              .toList(growable: false)
          : const <NutritionGuidanceMeal>[],
    );
  }
}

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
