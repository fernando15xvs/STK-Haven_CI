import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/exercises/data/exercise_personal_settings_repository.dart';

final exercisePersonalSettingsRepositoryProvider =
    Provider<ExercisePersonalSettingsRepository>((ref) {
  final box = Hive.box(HiveBoxes.metadata);
  return ExercisePersonalSettingsRepository(box);
});

final exercisePersonalSettingsProvider = NotifierProvider<
    ExercisePersonalSettingsNotifier,
    Map<String, ExercisePersonalSettings>>(
  ExercisePersonalSettingsNotifier.new,
);

class ExercisePersonalSettingsNotifier
    extends Notifier<Map<String, ExercisePersonalSettings>> {
  @override
  Map<String, ExercisePersonalSettings> build() {
    return ref.read(exercisePersonalSettingsRepositoryProvider).getAll();
  }

  ExercisePersonalSettings settingsFor(String exerciseId) {
    return state[exerciseId.trim()] ?? const ExercisePersonalSettings();
  }

  Future<void> save({
    required String exerciseId,
    required int warmupSets,
    required int approachSets,
    required String technicalNotes,
  }) async {
    final id = exerciseId.trim();
    if (id.isEmpty) return;

    final settings = ExercisePersonalSettings(
      warmupSets: warmupSets.clamp(0, 5),
      approachSets: approachSets.clamp(0, 5),
      technicalNotes: technicalNotes.trim(),
    );
    await ref
        .read(exercisePersonalSettingsRepositoryProvider)
        .save(id, settings);
    state = Map.unmodifiable({...state, id: settings});
  }

  Future<void> remove(String exerciseId) async {
    final id = exerciseId.trim();
    if (id.isEmpty) return;
    await ref.read(exercisePersonalSettingsRepositoryProvider).remove(id);
    final next = {...state}..remove(id);
    state = Map.unmodifiable(next);
  }

  void refresh() {
    state = ref.read(exercisePersonalSettingsRepositoryProvider).getAll();
  }
}
