import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/study_plan.dart';
import 'package:core/features/habits/data/study_plan_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

final studyPlanRepositoryProvider = Provider<StudyPlanRepository>((ref) {
  return StudyPlanRepository(Hive.box<dynamic>(HiveBoxes.habitTasks));
});

final studyPlanEnrollmentsProvider = NotifierProvider<
    StudyPlanEnrollmentsNotifier,
    List<StudyPlanEnrollment>>(StudyPlanEnrollmentsNotifier.new);

class StudyPlanEnrollmentsNotifier
    extends Notifier<List<StudyPlanEnrollment>> {
  static const Uuid _uuid = Uuid();
  late final StudyPlanRepository _repository;

  @override
  List<StudyPlanEnrollment> build() {
    _repository = ref.watch(studyPlanRepositoryProvider);
    return _repository.getEnrollments();
  }

  Future<StudyPlanEnrollment> enroll(String planId) async {
    final now = DateTime.now();
    final enrollment = StudyPlanEnrollment(
      id: _uuid.v4(),
      planId: planId,
      startedAt: now,
      updatedAt: now,
    );
    await _repository.save(enrollment);
    state = _repository.getEnrollments();
    return enrollment;
  }

  Future<void> setPaused(String enrollmentId, bool paused) async {
    final current = _find(enrollmentId);
    if (current == null) return;
    await _repository.save(
      current.copyWith(
        paused: paused,
        updatedAt: DateTime.now(),
      ),
    );
    state = _repository.getEnrollments();
  }

  Future<void> completeStep(
    String enrollmentId,
    int stepIndex,
  ) async {
    if (stepIndex < 0) return;
    final current = _find(enrollmentId);
    if (current == null) return;

    final completed = Set<int>.from(current.completedStepIndices)
      ..add(stepIndex);
    await _repository.save(
      current.copyWith(
        completedStepIndices: completed,
        updatedAt: DateTime.now(),
      ),
    );
    state = _repository.getEnrollments();
  }

  StudyPlanEnrollment? _find(String id) {
    for (final item in state) {
      if (item.id == id) return item;
    }
    return null;
  }
}
