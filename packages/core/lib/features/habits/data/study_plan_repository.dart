import 'package:core/domain/models/study_plan.dart';
import 'package:hive/hive.dart';

class StudyPlanRepository {
  static const String enrollmentPrefix = 'study_plan::';

  final Box<dynamic> _box;

  StudyPlanRepository(this._box);

  List<StudyPlanEnrollment> getEnrollments() {
    final result = <StudyPlanEnrollment>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(enrollmentPrefix)) continue;
      final raw = _box.get(key);
      if (raw is! Map) continue;
      try {
        final item = StudyPlanEnrollment.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (item.id.isEmpty || item.planId.isEmpty) continue;
        result.add(item);
      } catch (_) {
        // Ignore malformed local entries.
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<void> save(StudyPlanEnrollment enrollment) {
    return _box.put(
      '$enrollmentPrefix${enrollment.id}',
      enrollment.toJson(),
    );
  }
}
