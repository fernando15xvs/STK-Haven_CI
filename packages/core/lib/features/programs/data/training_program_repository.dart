import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TrainingProgramRepository {
  TrainingProgramRepository(this._box, {Box? metadataBox})
      : _metadataBox = metadataBox ?? Hive.box(HiveBoxes.metadata);

  /// BackupService already serializes the metadata box. Keeping the canonical
  /// program payload here makes Programs 2.0 backward-compatible without
  /// coupling BackupService to the optimized program box.
  static const String backupMetadataKey = 'training_programs_v2';

  final Box _box;
  final Box _metadataBox;

  List<TrainingProgram> getAll() {
    // The metadata shadow is authoritative because it is the representation
    // that participates in backup/restore. The dedicated box is only an
    // optimized mirror and must never override freshly restored metadata.
    final source = _shadowValues();
    final programs = <TrainingProgram>[];
    for (final value in source) {
      if (value is! Map) continue;
      try {
        programs.add(
          TrainingProgram.fromJson(Map<String, dynamic>.from(value)),
        );
      } catch (_) {
        // Ignore one corrupt program without hiding the rest.
      }
    }
    programs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return programs;
  }

  Iterable<dynamic> _shadowValues() {
    final shadow = _metadataBox.get(backupMetadataKey);
    if (shadow is List) return shadow;
    return const [];
  }

  TrainingProgram? getById(String id) {
    for (final program in getAll()) {
      if (program.id == id) return program;
    }
    return null;
  }

  TrainingProgram? getActive() {
    final active = getAll().where((program) => program.isActive).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return active.first;
  }

  Future<void> save(TrainingProgram program) async {
    await _synchronizeBoxFromShadow();
    await _box.put(program.id, program.toJson());
    await _writeShadow();
  }

  Future<void> delete(String id) async {
    await _synchronizeBoxFromShadow();
    await _box.delete(id);
    await _writeShadow();
  }

  Future<void> activate(String id, {DateTime? startedAt}) async {
    await _synchronizeBoxFromShadow();
    final all = _programsFromBox();
    for (final program in all) {
      final shouldBeActive = program.id == id;
      final updated = program.copyWith(
        isActive: shouldBeActive,
        startedAt: shouldBeActive && startedAt != null
            ? startedAt
            : program.startedAt,
      );
      await _box.put(updated.id, updated.toJson());
    }
    await _writeShadow();
  }

  Future<void> clear() async {
    await _box.clear();
    await _metadataBox.delete(backupMetadataKey);
  }

  /// Rebuilds the optimized mirror from the restored backup representation.
  /// Calling this after a restore is optional for correctness because reads use
  /// the shadow, but it is useful before any subsequent write.
  Future<void> hydrateFromBackupMetadata() => _synchronizeBoxFromShadow();

  Future<void> _synchronizeBoxFromShadow() async {
    final shadow = _shadowValues().toList(growable: false);
    await _box.clear();
    for (final raw in shadow) {
      if (raw is! Map) continue;
      try {
        final program = TrainingProgram.fromJson(
          Map<String, dynamic>.from(raw),
        );
        await _box.put(program.id, program.toJson());
      } catch (_) {
        // Ignore malformed backup entries individually.
      }
    }
  }

  List<TrainingProgram> _programsFromBox() {
    final programs = <TrainingProgram>[];
    for (final value in _box.values) {
      if (value is! Map) continue;
      try {
        programs.add(
          TrainingProgram.fromJson(Map<String, dynamic>.from(value)),
        );
      } catch (_) {}
    }
    return programs;
  }

  Future<void> _writeShadow() async {
    final payload = <Map<String, dynamic>>[];
    for (final value in _box.values) {
      if (value is Map) payload.add(Map<String, dynamic>.from(value));
    }
    await _metadataBox.put(backupMetadataKey, payload);
  }

  static TrainingProgramRepository fromHive() {
    return TrainingProgramRepository(
      Hive.box(HiveBoxes.trainingPrograms),
      metadataBox: Hive.box(HiveBoxes.metadata),
    );
  }
}
