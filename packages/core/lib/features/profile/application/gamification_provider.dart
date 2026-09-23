import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/gamification_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/profile/data/gamification_repository.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  final box = Hive.box(HiveBoxes.gamification);
  return GamificationRepository(box);
});

class GamificationNotifier extends Notifier<GamificationState> {
  late final GamificationRepository _repository;

  @override
  GamificationState build() {
    _repository = ref.watch(gamificationRepositoryProvider);
    return _repository.getGamificationState();
  }

  Future<bool> addWorkoutSession(WorkoutSession session) async {
    // Finishing a workout can be retried after an app/process failure. Never
    // award XP or volume twice for the same persisted workout session.
    if (state.hasProcessedWorkout(session.id)) {
      return false;
    }

    int completedSets = 0;
    double volume = 0.0;

    for (final exercise in session.exercises) {
      for (final set in exercise.sets) {
        if (set.completed) {
          completedSets++;
          volume += set.performedVolume;
        }
      }
    }

    final durationMin = session.durationSeconds ~/ 60;
    final earnedXp =
        (completedSets * 25) + (durationMin * 5) + (volume / 200).floor();
    final newXp = state.xp + earnedXp;
    final newLevel = sqrt(newXp / 150).floor() + 1;
    final newTotalVolume = state.totalVolumeLifted + volume;

    state = state.copyWith(
      xp: newXp,
      level: newLevel,
      totalVolumeLifted: newTotalVolume,
      processedWorkoutIds: [
        ...state.processedWorkoutIds,
        session.id,
      ],
    );

    _evaluateAchievements(newTotalVolume);
    await _repository.saveGamificationState(state);
    return true;
  }

  void _evaluateAchievements(double totalVolume) {
    final updatedAchievements = <Achievement>[];
    bool stateChanged = false;

    for (final achievement in state.achievements) {
      if (achievement.isUnlocked) {
        updatedAchievements.add(achievement);
        continue;
      }

      double progress = achievement.progress;
      bool unlocked = false;

      switch (achievement.id) {
        case 'first_workout':
          unlocked = true;
          progress = 1.0;
          break;
        case 'volume_1000':
          progress = (totalVolume / 1000).clamp(0.0, 1.0);
          if (progress >= 1.0) unlocked = true;
          break;
        case 'streak_3':
          // Pending: streak is calculated separately from workout dates.
          break;
      }

      if (unlocked || progress != achievement.progress) {
        stateChanged = true;
        updatedAchievements.add(
          achievement.copyWith(
            progress: progress,
            unlockedAt: unlocked ? DateTime.now() : null,
          ),
        );
      } else {
        updatedAchievements.add(achievement);
      }
    }

    if (stateChanged) {
      state = state.copyWith(achievements: updatedAchievements);
    }
  }

  Future<void> checkFirstPr() async {
    final updatedAchievements = <Achievement>[];
    bool stateChanged = false;

    for (final achievement in state.achievements) {
      if (achievement.isUnlocked) {
        updatedAchievements.add(achievement);
        continue;
      }
      if (achievement.id == 'first_pr') {
        updatedAchievements.add(
          achievement.copyWith(
            progress: 1.0,
            unlockedAt: DateTime.now(),
          ),
        );
        stateChanged = true;
      } else {
        updatedAchievements.add(achievement);
      }
    }

    if (stateChanged) {
      state = state.copyWith(achievements: updatedAchievements);
      await _repository.saveGamificationState(state);
    }
  }
}

final gamificationProvider =
    NotifierProvider<GamificationNotifier, GamificationState>(
  GamificationNotifier.new,
);
