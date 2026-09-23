import 'package:hive/hive.dart';

class ExercisePersonalSettings {
  final int warmupSets;
  final int approachSets;
  final String technicalNotes;

  const ExercisePersonalSettings({
    this.warmupSets = 0,
    this.approachSets = 0,
    this.technicalNotes = '',
  });

  ExercisePersonalSettings copyWith({
    int? warmupSets,
    int? approachSets,
    String? technicalNotes,
  }) {
    return ExercisePersonalSettings(
      warmupSets: warmupSets ?? this.warmupSets,
      approachSets: approachSets ?? this.approachSets,
      technicalNotes: technicalNotes ?? this.technicalNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'warmupSets': warmupSets,
        'approachSets': approachSets,
        'technicalNotes': technicalNotes,
      };

  factory ExercisePersonalSettings.fromJson(Map<dynamic, dynamic> json) {
    int readSetCount(dynamic value) {
      final parsed = value is int ? value : int.tryParse('$value') ?? 0;
      return parsed.clamp(0, 5);
    }

    return ExercisePersonalSettings(
      warmupSets: readSetCount(json['warmupSets']),
      approachSets: readSetCount(json['approachSets']),
      technicalNotes: (json['technicalNotes'] ?? '').toString().trim(),
    );
  }
}

class ExercisePersonalSettingsRepository {
  static const storageKey = 'exercise_personal_settings_v1';
  final Box<dynamic> _metadataBox;

  ExercisePersonalSettingsRepository(this._metadataBox);

  Map<String, ExercisePersonalSettings> getAll() {
    final raw = _metadataBox.get(storageKey);
    if (raw is! Map) return const {};

    final result = <String, ExercisePersonalSettings>{};
    for (final entry in raw.entries) {
      final id = entry.key.toString().trim();
      if (id.isEmpty || entry.value is! Map) continue;
      result[id] = ExercisePersonalSettings.fromJson(
        Map<dynamic, dynamic>.from(entry.value as Map),
      );
    }
    return Map.unmodifiable(result);
  }

  ExercisePersonalSettings getFor(String exerciseId) {
    final id = exerciseId.trim();
    if (id.isEmpty) return const ExercisePersonalSettings();
    return getAll()[id] ?? const ExercisePersonalSettings();
  }

  Future<void> save(
    String exerciseId,
    ExercisePersonalSettings settings,
  ) async {
    final id = exerciseId.trim();
    if (id.isEmpty) return;

    final normalized = ExercisePersonalSettings(
      warmupSets: settings.warmupSets.clamp(0, 5),
      approachSets: settings.approachSets.clamp(0, 5),
      technicalNotes: settings.technicalNotes.trim(),
    );

    final all = getAll().map(
      (key, value) => MapEntry<String, dynamic>(key, value.toJson()),
    );
    all[id] = normalized.toJson();
    await _metadataBox.put(storageKey, all);
  }

  Future<void> remove(String exerciseId) async {
    final id = exerciseId.trim();
    if (id.isEmpty) return;

    final all = getAll().map(
      (key, value) => MapEntry<String, dynamic>(key, value.toJson()),
    );
    if (all.remove(id) == null) return;
    await _metadataBox.put(storageKey, all);
  }
}
