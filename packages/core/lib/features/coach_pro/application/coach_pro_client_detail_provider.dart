import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach_pro/domain/coach_pro_task_summary.dart';
import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/features/coach_pro/data/coach_pro_client_detail_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum CoachProClientSection { summary, checkins, programs, tasks, workouts, progress, nutrition }

typedef CoachProClientDetailQuery = ({String relationshipId, CoachProClientSection section, int offset});

class CoachProClientDetail {
  final CoachProClientSummary summary;
  final CoachProCheckinPage? checkins;
  final CoachProSectionPage<CoachProgramAssignmentSummary>? programs;
  final CoachProSectionPage<CoachProTaskSummary>? tasks;
  final CoachProSectionPage<CoachSharedWorkoutSummary>? workouts;
  final CoachClientProgress? progress;
  final CoachProSectionPage<NutritionGuidanceSummary>? nutrition;
  const CoachProClientDetail(this.summary, {this.checkins, this.programs, this.tasks, this.workouts, this.progress, this.nutrition});
  bool get canViewNutrition => canView(CoachPermission.viewNutrition);
  bool get canViewProgress => canView(CoachPermission.viewProgress);
  bool get canViewWorkouts => canView(CoachPermission.viewWorkouts);
  bool canView(CoachPermission permission) =>
      summary.relationshipStatus == CoachRelationshipStatus.active &&
      summary.permissions.contains(permission);
  bool get canViewPrograms => canView(CoachPermission.assignPrograms);
  bool get canViewTasks => canView(CoachPermission.assignTasks);
  bool get canViewCheckins =>
      summary.relationshipStatus == CoachRelationshipStatus.active &&
      summary.permissions.contains(CoachPermission.viewCheckins);
}

final coachProClientDetailServiceProvider = Provider<CoachProClientDetailService>(
  (ref) => CoachProClientDetailService(Supabase.instance.client),
);

/// One relationship and one selected section/page; never a persisted client cache.
final coachProClientDetailProvider = FutureProvider.autoDispose
    .family<CoachProClientDetail?, CoachProClientDetailQuery>((ref, query) async {
  final identity = ref.watch(appIdentityProvider.select(
    (value) => (value.signedIn, value.userId),
  ));
  if (!identity.$1 || identity.$2 == null) return null;
  final service = ref.watch(coachProClientDetailServiceProvider);
  final summary = await service.getSummary(query.relationshipId);
  if (!ref.mounted || summary == null) return null;
  final detail = CoachProClientDetail(summary);
  // A fixed summary + one selected page; no eager sibling sections or N+1.
  switch (query.section) {
    case CoachProClientSection.summary:
      return detail;
    case CoachProClientSection.nutrition:
      if (!detail.canViewNutrition) return detail;
      return CoachProClientDetail(summary, nutrition:
        await service.listNutrition(query.relationshipId, summary.clientUserId, offset: query.offset));
    case CoachProClientSection.progress:
      if (!detail.canViewProgress) return detail;
      return CoachProClientDetail(summary, progress:
        await service.getProgress(query.relationshipId, summary.clientUserId));
    case CoachProClientSection.workouts:
      if (!detail.canViewWorkouts) return detail;
      return CoachProClientDetail(summary, workouts:
        await service.listWorkouts(query.relationshipId, summary.clientUserId, offset: query.offset));
    case CoachProClientSection.checkins:
      if (!detail.canViewCheckins) return detail;
      return CoachProClientDetail(summary, checkins:
        await service.listCheckins(query.relationshipId, offset: query.offset));
    case CoachProClientSection.programs:
      if (!detail.canViewPrograms) return detail;
      return CoachProClientDetail(summary, programs:
        await service.listPrograms(query.relationshipId, offset: query.offset));
    case CoachProClientSection.tasks:
      if (!detail.canViewTasks) return detail;
      return CoachProClientDetail(summary, tasks:
        await service.listTasks(query.relationshipId, offset: query.offset));
  }
});
