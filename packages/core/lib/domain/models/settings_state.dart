import 'package:core/domain/models/active_program_state.dart';

enum WeightUnit { kg, lb }

enum PreferredWorkoutSide { automatic, left, right }

enum PerformanceMode { automatic, quality, savings }

extension WeightUnitExtension on WeightUnit {
  String get label {
    switch (this) {
      case WeightUnit.kg:
        return 'kg';
      case WeightUnit.lb:
        return 'lb';
    }
  }
}

extension PreferredWorkoutSideX on PreferredWorkoutSide {
  String get label => switch (this) {
        PreferredWorkoutSide.automatic => 'Automático',
        PreferredWorkoutSide.left => 'Izquierda',
        PreferredWorkoutSide.right => 'Derecha',
      };
}

extension PerformanceModeX on PerformanceMode {
  String get label => switch (this) {
        PerformanceMode.automatic => 'Automático',
        PerformanceMode.quality => 'Calidad',
        PerformanceMode.savings => 'Ahorro',
      };
}

class SettingsState {
  final bool isRirEnabled;
  final bool autoRestEnabled;
  final double defaultIncrement;
  final WeightUnit weightUnit;
  final bool vibrationEnabled;
  final bool timerSoundEnabled;
  final bool hasCompletedOnboarding;
  final ActiveProgramState? activeProgram;
  final bool showDailyVerse;
  final bool dailyVerseNotifications;
  final bool workoutRemindersEnabled;
  final int workoutReminderHour;
  final int workoutReminderMinute;
  final bool cloudSyncEnabled;
  final bool reduceMotion;
  final int unilateralSideRestSeconds;
  final bool unilateralSameWeightByDefault;
  final PreferredWorkoutSide preferredUnilateralStartSide;
  final bool prefillExerciseMemoryByDefault;
  final PerformanceMode performanceMode;

  const SettingsState({
    this.isRirEnabled = true,
    this.autoRestEnabled = true,
    this.defaultIncrement = 2.5,
    this.weightUnit = WeightUnit.kg,
    this.vibrationEnabled = true,
    this.timerSoundEnabled = true,
    this.hasCompletedOnboarding = false,
    this.activeProgram,
    this.showDailyVerse = true,
    this.dailyVerseNotifications = true,
    this.workoutRemindersEnabled = false,
    this.workoutReminderHour = 18,
    this.workoutReminderMinute = 0,
    this.cloudSyncEnabled = false,
    this.reduceMotion = false,
    this.unilateralSideRestSeconds = 60,
    this.unilateralSameWeightByDefault = true,
    this.preferredUnilateralStartSide = PreferredWorkoutSide.automatic,
    this.prefillExerciseMemoryByDefault = false,
    this.performanceMode = PerformanceMode.automatic,
  });

  SettingsState copyWith({
    bool? isRirEnabled,
    bool? autoRestEnabled,
    double? defaultIncrement,
    WeightUnit? weightUnit,
    bool? vibrationEnabled,
    bool? timerSoundEnabled,
    bool? hasCompletedOnboarding,
    ActiveProgramState? activeProgram,
    bool clearActiveProgram = false,
    bool? showDailyVerse,
    bool? dailyVerseNotifications,
    bool? workoutRemindersEnabled,
    int? workoutReminderHour,
    int? workoutReminderMinute,
    bool? cloudSyncEnabled,
    bool? reduceMotion,
    int? unilateralSideRestSeconds,
    bool? unilateralSameWeightByDefault,
    PreferredWorkoutSide? preferredUnilateralStartSide,
    bool? prefillExerciseMemoryByDefault,
    PerformanceMode? performanceMode,
  }) {
    return SettingsState(
      isRirEnabled: isRirEnabled ?? this.isRirEnabled,
      autoRestEnabled: autoRestEnabled ?? this.autoRestEnabled,
      defaultIncrement: defaultIncrement ?? this.defaultIncrement,
      weightUnit: weightUnit ?? this.weightUnit,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      timerSoundEnabled: timerSoundEnabled ?? this.timerSoundEnabled,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      activeProgram:
          clearActiveProgram ? null : (activeProgram ?? this.activeProgram),
      showDailyVerse: showDailyVerse ?? this.showDailyVerse,
      dailyVerseNotifications:
          dailyVerseNotifications ?? this.dailyVerseNotifications,
      workoutRemindersEnabled:
          workoutRemindersEnabled ?? this.workoutRemindersEnabled,
      workoutReminderHour: workoutReminderHour ?? this.workoutReminderHour,
      workoutReminderMinute:
          workoutReminderMinute ?? this.workoutReminderMinute,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      unilateralSideRestSeconds:
          unilateralSideRestSeconds ?? this.unilateralSideRestSeconds,
      unilateralSameWeightByDefault:
          unilateralSameWeightByDefault ?? this.unilateralSameWeightByDefault,
      preferredUnilateralStartSide:
          preferredUnilateralStartSide ?? this.preferredUnilateralStartSide,
      prefillExerciseMemoryByDefault:
          prefillExerciseMemoryByDefault ?? this.prefillExerciseMemoryByDefault,
      performanceMode: performanceMode ?? this.performanceMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isRirEnabled': isRirEnabled,
      'autoRestEnabled': autoRestEnabled,
      'defaultIncrement': defaultIncrement,
      'weightUnit': weightUnit.name,
      'vibrationEnabled': vibrationEnabled,
      'timerSoundEnabled': timerSoundEnabled,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'activeProgram': activeProgram?.toJson(),
      'showDailyVerse': showDailyVerse,
      'dailyVerseNotifications': dailyVerseNotifications,
      'workoutRemindersEnabled': workoutRemindersEnabled,
      'workoutReminderHour': workoutReminderHour,
      'workoutReminderMinute': workoutReminderMinute,
      'cloudSyncEnabled': cloudSyncEnabled,
      'reduceMotion': reduceMotion,
      'unilateralSideRestSeconds': unilateralSideRestSeconds,
      'unilateralSameWeightByDefault': unilateralSameWeightByDefault,
      'preferredUnilateralStartSide': preferredUnilateralStartSide.name,
      'prefillExerciseMemoryByDefault': prefillExerciseMemoryByDefault,
      'performanceMode': performanceMode.name,
    };
  }

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    final hour = (json['workoutReminderHour'] as num?)?.toInt() ?? 18;
    final minute = (json['workoutReminderMinute'] as num?)?.toInt() ?? 0;
    final sideRest =
        (json['unilateralSideRestSeconds'] as num?)?.toInt() ?? 60;
    return SettingsState(
      isRirEnabled: json['isRirEnabled'] as bool? ?? true,
      autoRestEnabled: json['autoRestEnabled'] as bool? ?? true,
      defaultIncrement: (json['defaultIncrement'] as num?)?.toDouble() ?? 2.5,
      weightUnit: WeightUnit.values.firstWhere(
        (e) => e.name == json['weightUnit'],
        orElse: () => WeightUnit.kg,
      ),
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      timerSoundEnabled: json['timerSoundEnabled'] as bool? ?? true,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
      activeProgram: json['activeProgram'] != null
          ? ActiveProgramState.fromJson(
              Map<String, dynamic>.from(json['activeProgram']),
            )
          : null,
      showDailyVerse: json['showDailyVerse'] as bool? ?? true,
      dailyVerseNotifications:
          json['dailyVerseNotifications'] as bool? ?? true,
      workoutRemindersEnabled:
          json['workoutRemindersEnabled'] as bool? ?? false,
      workoutReminderHour: hour.clamp(0, 23).toInt(),
      workoutReminderMinute: minute.clamp(0, 59).toInt(),
      cloudSyncEnabled: json['cloudSyncEnabled'] as bool? ?? false,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      unilateralSideRestSeconds: sideRest.clamp(0, 600).toInt(),
      unilateralSameWeightByDefault:
          json['unilateralSameWeightByDefault'] as bool? ?? true,
      preferredUnilateralStartSide: PreferredWorkoutSide.values.firstWhere(
        (value) => value.name == json['preferredUnilateralStartSide'],
        orElse: () => PreferredWorkoutSide.automatic,
      ),
      prefillExerciseMemoryByDefault:
          json['prefillExerciseMemoryByDefault'] as bool? ?? false,
      performanceMode: PerformanceMode.values.firstWhere(
        (value) => value.name == json['performanceMode'],
        orElse: () => PerformanceMode.automatic,
      ),
    );
  }
}
