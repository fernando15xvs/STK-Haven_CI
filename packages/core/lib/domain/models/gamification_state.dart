class Achievement {
  final String id;
  final String title;
  final String description;
  final DateTime? unlockedAt;
  final double progress;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.unlockedAt,
    this.progress = 0.0,
  });

  bool get isUnlocked => unlockedAt != null;

  Achievement copyWith({
    String? title,
    String? description,
    DateTime? unlockedAt,
    double? progress,
  }) {
    return Achievement(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'progress': progress,
    };
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GamificationState {
  final int xp;
  final int level;
  final double totalVolumeLifted;
  final int workoutStreak;
  final List<Achievement> achievements;
  final List<String> processedWorkoutIds;

  const GamificationState({
    this.xp = 0,
    this.level = 1,
    this.totalVolumeLifted = 0.0,
    this.workoutStreak = 0,
    this.achievements = const [],
    this.processedWorkoutIds = const [],
  });

  bool hasProcessedWorkout(String workoutId) =>
      processedWorkoutIds.contains(workoutId);

  GamificationState copyWith({
    int? xp,
    int? level,
    double? totalVolumeLifted,
    int? workoutStreak,
    List<Achievement>? achievements,
    List<String>? processedWorkoutIds,
  }) {
    return GamificationState(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      totalVolumeLifted: totalVolumeLifted ?? this.totalVolumeLifted,
      workoutStreak: workoutStreak ?? this.workoutStreak,
      achievements: achievements ?? this.achievements,
      processedWorkoutIds: processedWorkoutIds ?? this.processedWorkoutIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'xp': xp,
      'level': level,
      'totalVolumeLifted': totalVolumeLifted,
      'workoutStreak': workoutStreak,
      'achievements': achievements.map((a) => a.toJson()).toList(),
      'processedWorkoutIds': processedWorkoutIds,
    };
  }

  factory GamificationState.fromJson(Map<String, dynamic> json) {
    return GamificationState(
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      totalVolumeLifted:
          (json['totalVolumeLifted'] as num?)?.toDouble() ?? 0.0,
      workoutStreak: json['workoutStreak'] as int? ?? 0,
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((e) => Achievement.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      processedWorkoutIds: (json['processedWorkoutIds'] as List<dynamic>?)
              ?.map((id) => id.toString())
              .toList() ??
          [],
    );
  }
}
